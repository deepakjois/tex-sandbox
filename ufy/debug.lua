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


callback.register("hyphenate", false)
callback.register("ligaturing", false)
callback.register("kerning", false)




callback.register("post_linebreak_filter", function(head)
  texio.write_nl("POST LINE BREAK")
  show_nodes(head)
  return true
end)

return {
  show_nodes = show_nodes
}
