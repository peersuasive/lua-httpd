--  -*-mode: C++; style: K&R; c-basic-offset: 4 ; -*- */

--
--  A simple HTTP server written in Lua, using the binding primitives
-- in 'libhttpd.so'.
--
--  This server will server multiple virtual hosts.  The only requirement
-- is that each virtual host must have the documents located beneath
-- a common tree.
--
--  For example to server the hosts:
--    lappy
--    bob
--    localhost
--
--  You should have a directory layout such as:
--
--    ./vhosts/
--    ./vhosts/bob/
--    ./vhosts/lappy/
--    ./vhosts/localhost/
--
--  Directory indexes are not supported.  Neither are CGI scripts or
-- logging.
--
--  *The* *code* *is* *not* *secure*.
--
--
-- $Id: httpd.lua,v 1.6 2005-10-29 05:49:38 steve Exp $


--
-- load the socket library
--
socket = assert(loadlib("./libhttpd.so", "luaopen_libhttpd"))()

print( "Loaded the socket library, version: \n  " .. socket.version );


--
--  A table of MIME types
--
mime = {};
mime[ "html" ]  = "text/html";
mime[ "txt"  ]  = "text/plain";
mime[ "jpg"  ]  = "image/jpeg";
mime[ "jpeg" ]  = "image/jpeg";
mime[ "gif"  ]  = "image/gif";
mime[ "png"  ]  = "image/png";



--
--  Start a server upon the given port, using the given
-- root path.
--
--  The root path is designed to contain subdirectories for
-- each given virtual host.
--
function start_server( port, root )
    local running = 1;

    --
    --  Bind a socket to the given port
    --
    local listener = socket.bind( port );

    --
    --   Print some status messages.
    -- 
    print( "Listening upon:" );
    print( "  http://localhost:" .. port );
    print( "Loading virtual hosts from beneath: " );
    print( "  "  .. root );

    --
    --  Loop accepting requests.
    --
    while ( running == 1 ) do
        processConnection( root, listener );
    end


    --
    -- Finished.
    --
    socket.close( listener );
end




--
--  Process a single incoming connection.
--
function processConnection( root, listener ) 
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
    
    --
    -- Find the requested path.
    --
    _, _, path, major, minor  = string.find(request, "GET (.+) HTTP/(%d).(%d)");

    --
    -- Also find the Virtual Host.
    --
    _, _, host  = string.find(request, "Host: ([^:\r\n]+)");


    --
    -- If the request was for '/finish' then finish
    --
    if ( path == "/finish" ) then
        running = 0;
        print( "Terminating" );
        socket.write( client, "---\nFINISHED" );
    else
        
        --
        -- Otherwise attempt to handle the connection.
        --
        handleRequest( root, host, path, client );
    end


    --
    --  Close the client connection.
    --
    socket.close( client );
end



--
--  Attempt to server the given path to the given client
--
function handleRequest( root, host, path, client )
    --
    -- Local file
    --
    file = path;

    --
    -- Add a trailing "index.html" to paths ending in /
    --
    if ( string.ends( file, "/" ) ) then  
        file = file .. "index.html";
    end

    --
    --  File must be beneath the vhost root.
    --
    file = root .. host .. file ; -- "/" .. file ;


    --
    -- Open the file and give an error if it fails.
    --    
    local f = io.open(file, "rb");
    if f == nil then
        print "404";
	return( sendError( client, 404, "File not found " .. path ) );
    else
        f:close();
    end

    print ( file );

    --
    -- Find the suffix to get the mime.type.
    --
    _, _, ext  = string.find( file, "\.([^\.]+)$" );
    if ( ext == nil ) then
       ext = "html";   -- HACK
    end
    
    socket.write( client, "HTTP/1.0 200 OK\r\n" );
    socket.write( client, "Content-type: " .. mime[ ext]  .. "\r\n" );
    socket.write( client, "Connection: close\r\n\r\n" );

    --
    -- Read the file.
    --
    f = io.open(file, "rb");
    local t = f:read("*all")
    socket.write(client, t, fsize( f ) );
    f:close();

end


--
--  Send the given error message to the client.
--
function sendError( client, status, str )
    socket.write( client, "HTTP/1.0 " .. status .. " OK\r\n" );
    socket.write( client, "Content-type: text/html\r\n" );
    socket.write( client, "Connection: close\r\n\r\n" );
    socket.write( client, "<html><head><title>Error</title></head>" );
    socket.write( client, "<body><h1>Error</h1" );
    socket.write( client, "<p>" .. str .. "</p></body></html>" );
end



--
--  Determine the file size.
--
function fsize (file)
    local current = file:seek()      -- get current position
    local size = file:seek("end")    -- get file size
    file:seek("set", current)        -- restore position
    return size
end

--
--  Utility function, does the string end with the given suffix?
--
function string.ends(String,End)
      return End=='' or string.sub(String,-string.len(End))==End
end


    start_server( 4444, "./vhosts/" );
