# Taken from: http://lua-users.org/wiki/BuildingModules
# Not very robust. Works only on Mac OS X.
rm -rf *.o *.la *.lo .libs/
gcc -O2 -fpic -c harfbuzz.c
gcc -O -shared -fpic -flat_namespace -undefined suppress -undefined dynamic_lookup -o harfbuzz.so harfbuzz.o

