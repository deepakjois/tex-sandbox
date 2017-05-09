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

local lt_to_hb_dir = { TLT = "ltr", TRT = "rtl" }

local function upem_to_sp(v,metrics)
  return math.floor(v / metrics.units_per_em * metrics.size)
end

-- Convert a node list to a table for easier processing. Returns a table
-- containing entries for all nodes in the order they appear in the list. Each
-- entry contains the following fields:
--
-- * The node corresponding to the position in the table
--
-- * The character corresponding to the node
--
--   - Glyph nodes are stored as their corresponding character codepoints
--
--   - Glue nodes of subtype 13 (spaceskip) are stored as 0x20 whitespace character
--     (FIXME what about other types of space-like glue inserted when using \quad etc)
--
--    - All other nodes are stored as 0xFFFC (OBJECT REPLACEMENT CHARACTER)
--
--  * A script identifier for each node.
--
local function nodelist_to_table(head)
  -- Build text
  local nodetable = {}
  local last_font = nil
  for n in node.traverse(head) do
    local item = {}
    item.node = n
    table.insert(nodetable,n)
    if n.id == node.id("glyph") then -- regular char node
      item.char = n.char
      item.script = harfbuzz.unicode.script(item.char)
      item.font = n.font
      last_font = item.font
    elseif n.id == node.id("glue") and n.subtype == 13 then -- space skip
      item.char = 0x0020
      item.script = harfbuzz.unicode.script(item.char)
      if last_font == nil then error("cannot determine font for spaceskip") end
      item.font = last_font
    else
      item.char = 0xfffc
    end
  end

  return nodetable
end

-- FIXME use BiDi properties (via UCDN) to determine whether characters are paired
-- or not.
local paired_chars = {
  0x0028, 0x0029, /* ascii paired punctuation */
  0x003c, 0x003e,
  0x005b, 0x005d,
  0x007b, 0x007d,
  0x00ab, 0x00bb, /* guillemets */
  0x2018, 0x2019, /* general punctuation */
  0x201c, 0x201d,
  0x2039, 0x203a,
  0x3008, 0x3009, /* chinese paired punctuation */
  0x300a, 0x300b,
  0x300c, 0x300d,
  0x300e, 0x300f,
  0x3010, 0x3011,
  0x3014, 0x3015,
  0x3016, 0x3017,
  0x3018, 0x3019,
  0x301a, 0x301b
}

local function get_pair_index(char)
  local lower = 1
  local upper = #paired_chars

  while (lower <= upper) do
    local mid = math.floor((lower + upper) / 2)
    if char < paired_chars[mid] then
      upper = mid - 1
    elseif char > paired_chars[mid] then
      lower = mid + 1
    else
      return mid
    end

  return 0
end

local function is_open(pair_index)
  return bit32.band(pair_index, 1) == 1 -- odd index is open
end

-- Resolve the script for each character in the node table.
--
-- If the character script is common or inherited it takes the script of the
-- character before it except paired characters which we try to make them use
-- the same script.
local function resolve_scripts(nodetable)
  local last_script_index = 0
  local last_set_index = 0
  local last_script_value = harfbuzz.HB_SCRIPT_INVALID
  local stack = { top = 0 }

  for i,v in ipairs(nodetable) do
    if v.script == harfbuzz.HB_SCRIPT_COMMON and last_script_index ~= 0 then
      local pair_index = get_pair_index(v.char)
      if pair_index > 0 then
        if is_open(pair_index) then -- paired character (open)
          v.script = last_script_value
          last_set_index = i
          stack.top = stack.top + 1
          stack[stack.top] = { script = v.script, pair_index = pair_index}
        else -- is a close paired character
          -- find matching opening (by getting the last odd index for current
          -- even index)
          local pi = pair_index - 1
          while stack.top > 0 and stack[stack.top].pair_index != pi do
            stack.top = stack.top - 1
          end

          if stack.top > 0 then
            v.script = stack[stack.top].script
            last_script_value = v.script
            last_set_index = i
          else
            v.script = last_script_value
            last_set_index = i
          end
        end
      else
        nodetable[i].script = last_script_value
        last_set_index = i
      end
    elseif v.script == harfbuzz.HB_SCRIPT_INHERITED and last_script_index ~= 0 then
      v.script = last_script_value
      last_set_index = i
    else
      for j = last_set_index + 1, i do nodetable[j].script = v.script end
      last_script_value = v.script
      last_script_index = i
      last_set_index = i
    end
  end
end

local function reverse_runs(runs, start, len)
  for i = 1, math.floor(len/2) do
    local temp = runs[start + i - 1]
    runs[start + i - 1] = runs[start + len - i]
    runs[start + len - i] = temp
  end
end

-- Apply the Unicode BiDi algorithm, segment the nodes into runs, and reorder the runs.
--
-- Returns a table containing the runs after reordering.
--
local function bidi_reordered_runs(nodetable, base_dir)
  local codepoints = {}
  for _,v in ipairs(nodetable) do
    table.insert(codepoints, v.char)
  end
  local types = bidi.codepoints_to_types(codepoints)
  local pair_types = bidi.codepoints_to_pair_types(codepoints)
  local pair_values = bidi.codepoints_to_pair_values(codepoints)

  debug.log("Paragraph Direction: %s\n", h.dir)
  local dir
  if h.dir == "TRT" then
    dir = 1
  elseif h.dir == "TLT" then
    dir = 0
  else
    -- FIXME handle this better, and don’t throw an error.
    debug.log("Paragraph direction %s unsupported. Bailing!\n", h.dir)
    error("Unsupported Paragraph Direction")
  end

  local para = bidi.Paragraph.new(types, pair_types, pair_values, dir)

  local linebreaks = { #codes + 1 }
  local levels = para:getLevels(linebreaks)

  -- FIXME handle embedded RLE, LRE, RLI, LRI and PDF characters at this point and remove them.

  if #levels = 0 then return runs end

  -- L1. Reset the embedding level of the following characters to the paragraph embedding level:
  -- …<snip>…
  --   4. Any sequence of whitespace characters …<snip>… at the end of the line.
  -- …<snip>…
  for i = #levels, 1, -1 do
    levels[i] = base_dir
  end

  local max_level = 0
  local min_odd_level = bidi.MAX_DEPTH + 2
  for i,l in ipairs(levels) do
    if l > max_level then max_level = l end
    if bit32.band(l, 1) ~= 0 and l < min_odd_level then min_odd_level = l end
  end

  local runs = {}
  local run_start = 1
  local run_index = 1
  while run_start <= #levels do
    local run_end = run_start
    while run_end <= #levels and levels[run_start] == levels[run_end] do run_end = run_end + 1 end
    local run = {}
    run.pos = run_start
    run.level = levels[run_start]
    run.len = run_end - run_start
    runs[run_index] = run
    run_index = run_index + 1
    run_start = run_end
  end

  -- L2. From the highest level found in the text to the lowest odd level on
  -- each line, including intermediate levels not actually present in the text,
  -- reverse any contiguous sequence of characters that are at that level or
  -- higher.
  for l = max_level, min_odd_level, -1 do
    local i = #runs
    while i > 0 do
      local e = i
      i = i - 1
      while i > 0 and runs[i].level >= l do i = i - 1 end
      reverse_runs(runs, i+1, e - i)
    end
  end

  return runs
end

local function shape_nodes(head, dir)
  -- Convert node list to table
  nodetable = nodelist_to_table(head)

  -- Resolve scripts
  resolve_scripts(nodetable)

  -- Reorder Runs
  local runs = bidi_reordered_runs(nodetable, dir)

  -- Break up runs further if required
  
  -- Do shaping
  -- Convert shaped nodes to node list
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
  harfbuzz.shape(hb_font,buf, { direction = lt_to_hb_dir[dir]})

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

callback.register("pre_linebreak_filter", function(head, groupcode)
  debug.log("PRE LINE BREAK. Group Code is %s", groupcode == "" and "main vertical list" or groupcode)
  -- debug.show_nodes(head)

  -- Apply Unicode BiDi algorithm on nodes
  bidi_reorder_nodes(head)

  shape_runs(head)

  return true
end)

callback.register("hpack_filter", function(head, groupcode)
  debug.log("HPACK_FILTER. Group Code is %s", groupcode == "" and "main vertical list" or groupcode)
  debug.show_nodes(head)
  return true
end)

