# Taken from: http://lua-users.org/wiki/BuildingModules
# Not very robust. Works only on Mac OS X.
CC=cc
SVN=/Users/deepak/code/personal
L=$SVN/trunk/source/libs/lua52/lua-5.2.4/src
rm -rf *.o *.la *.lo .libs/
$CC -O2 -fpic -c harfbuzz.c
$CC -O -fpic -dynamiclib -undefined dynamic_lookup -o harfbuzz.so harfbuzz.o
$SVN/trunk/build/texk/web2c/luatex -luaonly test.lua

