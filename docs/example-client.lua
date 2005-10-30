#!/usr/bin/lua50

-- Load the library
socket = require( "libhttpd" );

-- Make a connection to http://localhost/
sock = socket.connect( "localhost", 80 );

-- Send the request.
socket.write( sock, "GET / HTTP/1.0\n\n" );

-- Read the response and print it
repeat
    len,line = socket.read( sock )
    print( line );
until len <= 0

-- Close up
socket.close( sock );
