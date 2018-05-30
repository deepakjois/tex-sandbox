-- Use LuaRocks to load packages
ufy.loader.add_lua_searchers()

tex.enableprimitives('',tex.extraprimitives())

local debug = require("ufylayout.debug")

-- Switch off some callbacks.
callback.register("hyphenate", false)
callback.register("ligaturing", false)
callback.register("kerning", false)

callback.register("pre_linebreak_filter", function(head)
  debug.log("PRE LINE BREAK")
  debug.show_nodes(head)

  return true
end)

