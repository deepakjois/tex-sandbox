#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

// Reference: http://lua-users.org/wiki/BindingCodeToLua

int shape (lua_State *L) {
  return 1;
}

int name (lua_State *L) {
  lua_pushstring(L, "Deepak");
  return 1;  
}

static const struct luaL_Reg lib_table [] = {
  {"_shape", shape},
  {"_name", name},
  {NULL, NULL}
};

int luaopen_harfbuzz (lua_State *L) {
  lua_newtable(L);  
  luaL_setfuncs(L, lib_table, 0);
  return 1;
}
