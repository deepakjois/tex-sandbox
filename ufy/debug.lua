local spt = require("serpent")


local function dump_fields(n, fields)
    local dump = {}
    for _,v in ipairs(fields) do
      table.insert(dump, string.format("%s: %s", v, n[v]))
    end
    return "{" .. table.concat(dump, ",") .. "}"
end

local function dump_node(n)
  return dump_fields(n, node.fields(n.id))
end

-- Switch off some callbacks
callback.register("hyphenate", false)
callback.register("ligaturing", false)
callback.register("kerning", false)

-- Add debug statements to some callbacks
-- callback.register("post_linebreak_filter", function()
--   texio.write_nl("POST_LINEBREAK")
--   return true
-- end)
--
-- callback.register("hpack_filter", function()
--   texio.write_nl("HPACK")
--   return true
-- end)
--
-- callback.register("vpack_filter", function()
--   texio.write_nl("VPACK")
--   return true
-- end)

callback.register("buildpage_filter", function(extrainfo)
   texio.write_nl("BUILDPAGE_FILTER "..extrainfo)
end)


-- Print the contents of a nodelist.
-- Glyph nodes are printed as UTF-8 characters, while other nodes are printed
-- by calling node.type on it, along with the subtype of the node.
local function show_nodes (head, raw)
  local nodes = "\n\n<NodeList>\n"
  for item in node.traverse(head) do
    local i = item.id
    if i == node.id("glyph") then
      if raw then i = string.format('<glyph U+%04X> - %s', item.char, dump_node(item)) else i = unicode.utf8.char(item.char) end
    else
      i = string.format('<%s%s> - %s', node.type(i), ( item.subtype and ("(".. item.subtype .. ")") or ''), dump_node(item))
    end
    nodes = nodes .. i .. ',\n'
  end
  nodes = nodes .. "</NodeList>\n\n"
  print(nodes)
  return true
end

-- Register debug callback
callback.register("pre_linebreak_filter", function(head)
  texio.write_nl("PRE_LINEBREAK")
  show_nodes(head)
  return head
end)

callback.register("pre_output_filter", function(head)
   texio.write_nl("PRE OUTPUT")
   show_nodes(head)
end)



--local text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
tex.parindent = "0pt"
print(string.format("\nTRACING VAR: %d\n", tex.tracingoutput))
-- tex.sprint(text)