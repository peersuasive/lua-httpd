--  -*-mode: C++; style: K&R; c-basic-offset: 4 ; -*- */

--
--  A simple HTTP server written in Lua, using the binding primitives
-- in 'libhttpd.so'.
--
--  This server will server multiple virtual hosts.  The only requirement
-- is that each virtual host must have the documents located beneath
-- a common tree.  Note that directory indexes are not (yet) supported.
--
--  For example to serve the three virtual hosts:
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
--
--  (If you wish to allow for fully qualified hosts simply use symbolic
-- links.)
--
--  *The* *code* *is* *not* *secure*.
--
--
-- $Id: httpd.lua,v 1.7 2005-10-29 05:58:29 steve Exp $


--
-- load the socket library
--
socket = assert(loadlib("./libhttpd.so", "luaopen_libhttpd"))()

print( "Loaded the socket library, version: \n  " .. socket.version );


--
--  A table of MIME types - TODO load from /etc/mime.types
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
-- root directory path.
--
--  The root path is designed to contain sub-directories for
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
    -- If the request was for '/finish' then terminate ourselves
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
--  Attempt to serve the given path to the given client
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
    file = root .. host .. file ;


    --
    -- Open the file and return an error if it fails.
    --    
    local f = io.open(file, "rb");
    if f == nil then
        print "404";
	return( sendError( client, 404, "File not found " .. path ) );
    else
        f:close();
    end

    --
    -- Show logging information here.
    --
    print ( "Now serving " .. file );


    --
    -- Find the suffix to get the mime.type.
    --
    _, _, ext  = string.find( file, "\.([^\.]+)$" );
    if ( ext == nil ) then
       ext = "html";   -- HACK
    end
    
    --
    -- Send out the header.
    --
    socket.write( client, "HTTP/1.0 200 OK\r\n" );
    socket.write( client, "Content-type: " .. mime[ ext]  .. "\r\n" );
    socket.write( client, "Connection: close\r\n\r\n" );

    --
    -- Read the file, and then serve it.
    --
    f = io.open(file, "rb");
    local t = f:read("*all")
    socket.write(client, t, fileSize( f ) );
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
    socket.write( client, "<p>" .. urlEncode(str) .. "</p></body></html>" );
end



--
--  Utility function:  Determine the size of an open file.
--
function fileSize (file)
    local current = file:seek()      -- get current position
    local size = file:seek("end")    -- get file size
    file:seek("set", current)        -- restore position
    return size
end

--
--  Utility function:   Does the string end with the given suffix?
--
function string.ends(String,End)
      return End=='' or string.sub(String,-string.len(End))==End
end



--
-- Utility function:  URL encoding function
--
function urlEncode(str)
    if (str) then
        str = string.gsub (str, "\n", "\r\n") 
        str = string.gsub (str, "([^%w ])",
            function (c) return string.format ("%%%02X", string.byte(c)) end) 
        str = string.gsub (str, " ", "+") 
    end 
    return str 
end


--
-- Utility function:  URL decode function (Not used)
--
function urlDecode(str)
    str = string.gsub (str, "+", " ") 
    str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end) 
    str = string.gsub (str, "\r\n", "\n") 
    return str 
end




--
--  Now that we've defined all our functions start the server.
--
--
start_server( 4444, "./vhosts/" );
