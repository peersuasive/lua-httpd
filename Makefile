DIST_PREFIX = /tmp
VERSION     = 0.3
BASE        = lua-httpd


libhttpd.so: libhttpd.c
	cc -fPIC `lua-config --include` -pedantic -Wall -O2 -c -o libhttpd.o libhttpd.c
	cc -o libhttpd.so -shared libhttpd.o
	strip libhttpd.so


clean:
	-find . -name '*~' -exec rm \{\} \;
	-rm -f libhttpd.so libhttpd.o


diff:
	cvs diff --unified 2>/dev/null


dist:   clean
	rm -rf $(DIST_PREFIX)/$(BASE)-$(VERSION)
	rm -f $(DIST_PREFIX)/$(BASE)-$(VERSION).tar.gz
	cp -R . $(DIST_PREFIX)/$(BASE)-$(VERSION)
	find  $(DIST_PREFIX)/$(BASE)-$(VERSION) -name "CVS" -print | xargs rm -rf
	cd $(DIST_PREFIX) && tar -cvf $(DIST_PREFIX)/$(BASE)-$(VERSION).tar $(BASE)-$(VERSION)/
	gzip $(DIST_PREFIX)/$(BASE)-$(VERSION).tar
	mv $(DIST_PREFIX)/$(BASE)-$(VERSION).tar.gz .


test: all
	lua httpd.lua


update:
	cvs -z3 update -A -d 2>/dev/null
