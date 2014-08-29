
lua-httpd
---------

This package contains a simple networking extension library for Lua 5.1 which is implemented and exported from a C shared library (.so).

It may be installed system-wide and used by your Lua scripts with ease.



Installation
------------

Compile and install the library with:

	make

	make install  (as root).

This will install the library into the directory `/usr/lib/lua/5.1` along with a helper package into `/usr/share/lua51`.



Usage
-----

Once the library has been installed you can use it from your Lua scripts easily.

Please see the documentation included in `docs/` for details.



Demonstration Code
------------------

The package comes complete with several small examples inside the API documentation which you can find beneath the `docs/` directory.

More complete sample code is included:

`httpd.lua` - A simple HTTP server written in Lua using the primitives.  This  server understands virtual hosts, and will serve using your systems  installed MIME types database.

The vhosts directory will contain a sub-directory for each virtual  host you wish to serve, for example:

		./vhosts/
		./vhosts/my-host-name/
		./vhosts/my-host-name/htdocs  - The web root
		./vhosts/my-host-name/logs    - Where logfiles are saved


`client.lua` - A very simple HTTP client written in Lua using the primitives.



License
-------

This code is distributed under the terms of the GNU General  Lesser Public License.



Steve
--
http://www.steve.org.uk/
