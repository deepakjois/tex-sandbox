-- Use LuaRocks to load packages
ufy.loader.revert_package_searchers()

local debug = dofile("debug.lua")
local bidi = require("bidi")
local fonts = require("ufy.fonts")
local harfbuzz = require("harfbuzz")

-- Tex Setup
tex.enableprimitives('',tex.extraprimitives())
tex.outputmode = 1

-- Switch off some callbacks.
callback.register("hyphenate", false)
callback.register("ligaturing", false)
callback.register("kerning", false)

-- Callback to load fonts.
local function read_font(file, size)
  print("Loading font…", file)
  local metrics = fonts.read_font_metrics(file, size)
  metrics.harfbuzz = true -- Mark as being able to be shaped by Harfbuzz
  return metrics
end

-- Register OpenType font loader in define_font callback.
callback.register('define_font', read_font, "font loader")

-- Reorder paragraph nodes according to Unicode BiDi algorithm.
local function bidi_reorder_nodes(head)
  local h,t,nodes, codes
  nodes = {}
  codes = {}

  h = head
  assert(h.id == node.id("local_par"))

  table.insert(nodes,h)
  table.insert(codes,0xfffc)
  for n in node.traverse(h) do
    table.insert(nodes,n)
    if n.id == node.id("glyph") then -- regular char node
      table.insert(codes, n.char)
    elseif n.id == node.id("glue") and n.subtype == 13 then -- space skip
      table.insert(codes,0x0020)
    else
      -- TODO need additional checks to recursively reorder other
      -- kinds of nodes.
      table.insert(codes,0xfffc)
    end
    t = n
  end

  assert(t.id == node.id("glue") and t.subtype == 15)

  local types = bidi.codepoints_to_types(codes)
  local pair_types = bidi.codepoints_to_pair_types(codes)
  local pair_values = bidi.codepoints_to_pair_values(codes)

  texio.write_nl("term and log", string.format("Paragraph Direction: %s\n", h.dir))
  local dir
  if h.dir == "TRT" then
    dir = 1
  elseif h.dir == "TLT" then
    dir = 0
  else
    texio.write_nl("term and log", string.format("Paragraph direction %s unsupported. Bailing!\n", h.dir))
    return true
  end

  local para = bidi.Paragraph.new(types, pair_types, pair_values, dir)

  local linebreaks = { #codes + 1 }
  local reordering = para:getReordering(linebreaks)

  local reordered = {}

  for i,v in ipairs(reordering) do
    reordered[i] = nodes[v]
  end

  if dir == 0 then
    assert(h == reordered[1])
    assert(t == reordered[#reordered])
    h = reordered[1]
    for i = 2, #reordered do
      h.next = reordered[i]
      reordered[i].prev = h
      h = reordered[i]
    end
  else
    assert(h == reordered[#reordered])
    assert(t == reordered[1])
    h = reordered[#reordered]
    for i = #reordered - 1, 1, -1 do
      h.next = reordered[i]
      reordered[i].prev = h
      h = reordered[i]
    end
  end
end

local lt_to_hb_dir = { TLT = "ltr", TRT = "rtl" }

local function upem_to_sp(v,metrics)
  return math.floor(v / metrics.units_per_em * metrics.size)
end

local function shape_run(head,dir)
  local fnt = head.font
  local metrics = font.getfont(fnt)
  if not metrics.harfbuzz then return head end

  -- Build text
  local codepoints = { }
  for n in node.traverse(head) do
    if n.id == node.id("glyph") then
      table.insert(codepoints, n.char)
    elseif n.id == node.id("glue") and n.subtype == 13 then
      table.insert(codepoints, 0x20)
    else
      error(string.format("Cant shape node of type %s, subtype %s", node.type(n.id), tostring(n.subtype)))
    end
  end

  -- Shape text
  local buf = harfbuzz.Buffer.new()
  local face = harfbuzz.Face.new(metrics.filename)
  local hb_font = harfbuzz.Font.new(face)

  buf:set_cluster_level(harfbuzz.Buffer.HB_BUFFER_CLUSTER_LEVEL_CHARACTERS)
  buf:add_codepoints(codepoints)
  harfbuzz.shape(hb_font,buf, { direction = lt_to_hb_dir[dir] })

  -- Create new nodes from shaped text
  if dir == 'TRT' then buf:reverse() end
  local glyphs = buf:get_glyph_infos_and_positions()

  local newhead = nil
  local current = nil

  for _, v in ipairs(glyphs) do
    local n,k -- Node and (optional) Kerning
    local char = metrics.backmap[v.codepoint]
    if codepoints[v.cluster+1] == 0x20 then
      assert(char == 0x20 or char == 0xa0, "Expected char to be 0x20 or 0xa0")
      n = node.new("glue")
      n.subtype = 13
      n.width = metrics.parameters.space
      n.stretch = metrics.parameters.space_stretch
      n.shrink = metrics.parameters.space_shrink
      newhead = node.insert_after(newhead, current, n)
    else
      -- Create glyph node
      n = node.new("glyph")
      n.font = fnt
      n.char = char
      n.subtype = 0

      -- Set offsets from Harfbuzz data
      n.yoffset = upem_to_sp(v.y_offset, metrics)
      n.xoffset = upem_to_sp(v.x_offset, metrics)
      if dir == 'TRT' then n.xoffset = n.xoffset * -1 end

      -- Adjust kerning if Harfbuzz’s x_advance does not match glyph width
      local x_advance = upem_to_sp(v.x_advance, metrics)
      if  math.abs(x_advance - n.width) > 1 then -- needs kerning
        k = node.new("kern")
        k.kern = (x_advance - n.width)
      end

      -- Insert glyph node into new list,
      -- adjusting for direction and kerning.
      if k then
        if dir == 'TRT' then -- kerning goes before glyph
          k.next = n
          current.next = k
        else -- kerning goes after glyph
          n.next = k
          current.next = n
        end
      else -- no kerning
        newhead = node.insert_after(newhead,current,n)
      end
    end
    current = node.slide(newhead)
  end

  return newhead
end

local function shape_runs(head)
  local curr = head
  while true do
    if curr.next == nil then break end

    if curr.next.id == node.id("glyph") then
      -- Start shaping run
      local start_run = curr.next
      local fnt = start_run.font
      local end_run = start_run.next
      while true do
        if end_run == nil then
          break
        elseif end_run.id == node.id("glyph") and end_run.font == fnt then
          -- keep going
          end_run = end_run.next
         elseif end_run.id == node.id("glue") and end_run.subtype == 13 then
          -- keep going
          end_run = end_run.next
        else
          break
        end
      end

      local run = node.copy_list(start_run, end_run)
      print(string.format("\nShaping run of %d nodes\n", node.length(run)))
      local shaped = shape_run(run,head.dir)
      curr.next = shaped
      shaped = node.slide(shaped)
      shaped.next = end_run
      end_run.prev = shaped
      curr = shaped
    else
      -- Move to next node
      curr = curr.next
    end
  end
end

callback.register("pre_linebreak_filter", function(head)
  texio.write_nl("PRE LINE BREAK")
  debug.show_nodes(head)

  -- Apply Unicode BiDi algorithm on nodes
  bidi_reorder_nodes(head)

  shape_runs(head)

  return true
end)

