tex.enableprimitives('',tex.extraprimitives())
tex.outputmode = 1
ufy.loader.revert_package_searchers()
local debug = dofile("debug.lua")
local bidi = require("bidi")

local function read_font(file, size, fontid)

  if size < 0 then
    size = size * tex.sp("10pt") / -1000
  end

  -- Load file using fontloader.open
   local f = fontloader.open (file)
   local fonttable = fontloader.to_table(f)
   fontloader.close(f)

   local metrics = {
     name = fonttable.fontname,
     fullname = fonttable.fontname,
     type = "real",
     filename = file,
     psname = fonttable.fontname,
     format = string.match(string.lower(file), "otf$") and "opentype" or string.match(string.lower(file), "ttf$") and "truetype",
     embedding = 'subset',
     size = size,
     designsize = size,
     cidinfo = fonttable.cidinfo,
     units_per_em = fonttable.units_per_em
   }

   -- Scaling for font metrics
   local mag = size / fonttable.units_per_em

   -- Find glyph for 0x20, and get width for spacing glue.
   local space_glyph = fonttable.map.map[0x20]
   local space_glyph_table = fonttable.glyphs[space_glyph]
   local space_glyph_width = space_glyph_table.width * mag

   metrics.parameters = {
     slant = 0,
     space = space_glyph_width,
     space_stretch = 1.5 * space_glyph_width,
     space_shrink = 0.5 * space_glyph_width,
     x_height = fonttable.pfminfo.os2_xheight * mag,
     quad = 1.0 * size,
     extra_space = 0
   }

   -- Save backmap in TeX font, so we can get char code from glyph index
   -- obtainded from Harfbuzz
   metrics.backmap = fonttable.map.backmap

   metrics.characters = { }
   for char, glyph in pairs(fonttable.map.map) do
     local glyph_table = fonttable.glyphs[glyph]
     metrics.characters[char] = {
       index = glyph,
       width = glyph_table.width * mag,
       name = glyph_table.name,
     }
     if glyph_table.boundingbox[4] then
       metrics.characters[char].height = glyph_table.boundingbox[4] * mag
     end
     if glyph_table.boundingbox[2] then
       metrics.characters[char].depth = -glyph_table.boundingbox[2] * mag
     end
   end

   return metrics
end

callback.register("pre_linebreak_filter", function(head)
  texio.write_nl("PRE LINE BREAK")
  debug.show_nodes(head)
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
    elseif n.id == node.id("glue") and n.subtype == 12 then -- space skip
      table.insert(codes,0x0020)
    else
      table.insert(codes,0xfffc)
    end
    t = n
  end

  assert(t.id == node.id("glue") and t.subtype == 15)

  local types = bidi.codepoints_to_types(codes)
  local pair_types = bidi.codepoints_to_pair_types(codes)
  local pair_values = bidi.codepoints_to_pair_values(codes)

  local dir = 1 -- RTL (hardcoded for now, but take from paragraph dir)

  local para = bidi.Paragraph.new(types, pair_types, pair_values, dir)

  local linebreaks = { #codes + 1 }
  local levels = para:getLevels(linebreaks)
  local reordering = para:getReordering(linebreaks)

  local reordered = {}

  for i,v in ipairs(reordering) do
    reordered[i] = nodes[v]
  end

  assert(h == reordered[#reordered])
  assert(t == reordered[1])
  h = reordered[#reordered]
  for i = #reordered - 1, 1, -1 do
    h.next = reordered[i]
    reordered[i].prev = h
    h = reordered[i]
  end

  return true
end)

-- Register OpenType font loader in define_font callback.
callback.register('define_font', read_font, "font loader")
