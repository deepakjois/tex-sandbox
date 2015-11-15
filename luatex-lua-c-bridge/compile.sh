# Taken from: http://lua-users.org/wiki/BuildingModules
# Not very robust. Works only on Mac OS X.
rm -rf *.la *.lo .libs/
LIBTOOL="glibtool --tag=CC"
$LIBTOOL --mode=compile gcc -c harfbuzz.c
$LIBTOOL --mode=link gcc -rpath `pwd` -module -avoid-version -o harfbuzz.la harfbuzz.lo
cp .libs/harfbuzz.so .

