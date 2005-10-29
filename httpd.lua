--  -*-mode: C++; style: K&R; c-basic-offset: 4 ; -*- */

--
--  A simple HTTP server written in Lua, using the binding primitives
-- in 'libhttpd.so'.
--


--
-- load the socket library
--
local socket = assert(loadlib("./libhttpd.so", "luaopen_libhttpd"))()

print( "Loaded the socket library, version: \n  " .. socket.version );



--
--  Global marker for whether we should terminate.
--
running = 1;



--
--  Loop accepting and processing incoming connections.
--
function processConnection( listener ) 
    --
    --  Accept a new connection
    --
    client = socket.accept( listener );

    found   = 0;
    size    = 0;
    request = "";


    --
    --  Read in a response from the client, terminating at the first
    -- '\r\n\r\n' line - this is the end of the HTTP header request.
    --
    while( found == 0 ) do
	length, data = socket.read(client);
        if ( length < 1 ) then
	    found = 1;
        end

	size    = size + length;
	request = request .. data;

	position,len = string.find( request, '\r\n\r\n' );
	if ( position ~= nil )  then
	    found = 1;
	end
    end


    --
    --  OK We now have a complete HTTP request of 'size' bytes long
    -- stored in 'request'.
    --
    --  Merely echo it back to the client for the moment.
    --
    socket.write( client, "HTTP/1.0 200 OK\r\n" );
    socket.write( client, "Content-type: text/plain\r\n" );
    socket.write( client, "Connection: close\r\n\r\n" );
    socket.write( client, request );


    --
    -- Find the requested path.
    --
    _, _, path, major, minor  = string.find(request, "GET (.+) HTTP/(%d).(%d)");
    print( "Request for : " .. path .. " (HTTP ".. major.."/"..minor..")" );


    --
    -- For fun also find the Virtual Host.
    --
    _, _, host  = string.find(request, "Host: ([^\r\n]+)");
    if ( host ~= nil ) then
       print( " " .. host );
    end

    --
    -- If the request was for '/finish' then finish
    --
    if ( path == "/finish" ) then
        running = 0;
        print( "Terminating" );
        socket.write( client, "---\nFINISHED" );
    end


    --
    --  Close the client connection.
    --
    socket.close( client );
end



--
--  Start the server upon port 4444
--
listener = socket.bind( 4444 );
print( "\nListening upon http://localhost:4444/\n" );


--
--  Loop accepting requests.
--
while ( running == 1 ) do
    processConnection( listener );
end


--
-- Finished.
--
socket.close( listener );
