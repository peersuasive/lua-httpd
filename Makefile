DIST_PREFIX = /tmp
VERSION     = 0.6
BASE        = lua-httpd


OUT         = libhttpd.so

$(OUT): libhttpd.c
	cc -fPIC `lua-config --include` -DRELEASE=\"$(VERSION)\" -pedantic -ansi -Wall -O2 -c -o libhttpd.o libhttpd.c
	cc -o libhttpd.so -shared libhttpd.o
	strip libhttpd.so


clean:
	-find . -name '*~' -exec rm \{\} \;
	-find . -name '.#*' -exec rm \{\} \;
	-rm -f libhttpd.so libhttpd.o
	-rm -f build-stamp
	-if [ -d debian/lua-httpd ]; then rm -rf debian/lua-httpd; fi
	-if [ -d tmp ]; then rm -rf tmp; fi
	-if [ -e debian/files ]; then rm -f debian/files; fi
	-find . -name 'access.log' -exec rm \{\} \;


diff:
	cvs diff --unified 2>/dev/null


debian: clean dist
	mkdir tmp
	mv $(BASE)-$(VERSION).tar.gz tmp/$(BASE)_$(VERSION).orig.tar.gz
	cd tmp && tar -zxvf $(BASE)_$(VERSION).orig.tar.gz
	find tmp/ -name CVS -exec rm -rf \{\} \;
	find tmp/ -name .cvsignore -exec rm -rf \{\} \;
	cd tmp/$(BASE)-$(VERSION) && debuild -sa
	mv tmp/$(BASE)_* .
	rm -rf tmp/



dist:   clean
	rm -rf $(DIST_PREFIX)/$(BASE)-$(VERSION)
	rm -f $(DIST_PREFIX)/$(BASE)-$(VERSION).tar.gz
	cp -R . $(DIST_PREFIX)/$(BASE)-$(VERSION)
	find  $(DIST_PREFIX)/$(BASE)-$(VERSION) -name "CVS" -print | xargs rm -rf
	find  $(DIST_PREFIX)/$(BASE)-$(VERSION) -name ".cvsignore" -print | xargs rm -rf
	cd $(DIST_PREFIX) && tar -cvf $(DIST_PREFIX)/$(BASE)-$(VERSION).tar $(BASE)-$(VERSION)/
	gzip $(DIST_PREFIX)/$(BASE)-$(VERSION).tar
	mv $(DIST_PREFIX)/$(BASE)-$(VERSION).tar.gz .


install: $(OUT)
	mkdir -p /usr/lib/lua/5.0
	mv $(OUT) /usr/lib/lua/5.0/
	mkdir -p /usr/share/lua50
	cp default.lua /usr/share/lua50/libhttpd.lua

test:
	lua httpd.lua


uninstall:
	rm -f /usr/lib/lua/5.0/$(OUT)
	rm -f /usr/share/lua50/libhttpd.lua

update:
	cvs -z3 update -A -d 2>/dev/null
