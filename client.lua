--  -*-mode: C++; style: K&R; c-basic-offset: 4 ; -*- */

--
--  A simple HTTP client written in Lua, using the socket primitives
-- in 'libhttpd.so'.
--
--
-- $Id: client.lua,v 1.6 2005-10-30 01:47:10 steve Exp $


--
-- load the socket library
--
socket = require( "libhttpd" );
print( "Loaded the socket library, version: \n  " .. socket.version );


--
--  Connect to localhost.
--
sock = socket.connect( "localhost", 80 );


--
--  Make a simple HTTP request.
--
socket.write( sock, "GET / HTTP/1.0\r\nConnection: close\r\n\r\n" );


--
-- Holders for a) a simple read request, and b) the total response.
--
line     = "";
response = "";


--
-- Loop reading until things fail.
--
repeat
   print( "Read - chunk" );
   len,line = socket.read( sock )
   response = response .. line;
until len <= 0


--
-- Finished.
--
socket.close( sock );


--
-- Output the HTTP headers + data.
--
print( response );
