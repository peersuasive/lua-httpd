DIST_PREFIX = /tmp
VERSION     = 0.1
BASE        = lua-httpd


all: libhttpd.c
	cc -fPIC `lua-config --include` -pedantic -Wall -O2 -c -o libhttpd.o libhttpd.c
	cc -o libhttpd.so -shared libhttpd.o
	strip libhttpd.so

clean:
	-rm *~ libhttpd.so libhttpd.o

test: all
	lua httpd.lua

dist:   clean
	rm -rf $(DIST_PREFIX)/$(BASE)-$(VERSION)
	rm -f $(DIST_PREFIX)/$(BASE)-$(VERSION).tar.gz
	cp -R . $(DIST_PREFIX)/$(BASE)-$(VERSION)
	find  $(DIST_PREFIX)/$(BASE)-$(VERSION) -name "CVS" -print | xargs rm -rf
	cd $(DIST_PREFIX) && tar -cvf $(DIST_PREFIX)/$(BASE)-$(VERSION).tar $(BASE)-$(VERSION)/
	gzip $(DIST_PREFIX)/$(BASE)-$(VERSION).tar
	mv $(DIST_PREFIX)/$(BASE)-$(VERSION).tar.gz .

