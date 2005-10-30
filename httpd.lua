--  -*-mode: C++; style: K&R; c-basic-offset: 4 ; -*- */

--
--  A simple HTTP server written in Lua, using the socket primitives
-- in 'libhttpd.so'.
--
--  This server will handle multiple virtual hosts.  The only requirement
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
--
--    ./vhosts/bob/
--    ./vhosts/bob/index.html        [etc]
--
--    ./vhosts/lappy/
--    ./vhosts/lappy/index.html      [etc]
--
--    ./vhosts/localhost/
--    ./vhosts/localhost/index.html  [etc]
--
--
--  (If you wish to allow for fully qualified hosts simply add symbolic
-- links to suit your hostnames.)
--
--
--
--  The code is NOT secure
--  ----------------------
--
--  By that I mean that I won't promise any security.  I take the obvious
-- step of filtering '/../' from incoming requests and Hostnames, but there
-- may be other weaknesses.
--
--  Error messages are escaped by default, to prevent XSS attacks.
--
--  DOS attacks are trivial.
--
--
-- Steve Kemp
-- --
-- http://www.steve.org.uk/
--
-- $Id: httpd.lua,v 1.19 2005-10-30 15:27:54 steve Exp $


--
-- load the socket library
--
socket = require( "libhttpd" );


print( "\n\nLoaded the socket library, version: \n  " .. socket.version );


--
--  A table of MIME types.  
--  These values will be loaded from /etc/mime.types if available, otherwise
-- a minimum set of defaults will be used.
--
mime = {};




--
--  Start a server upon the given port, using the given
-- root directory path.
--
--  The root path is designed to contain sub-directories for
-- each given virtual host.
--
function start_server( port, root )
    running = 1;

    --
    --  Bind a socket to the given port
    --
    local listener = socket.bind( port );

    --
    --   Print some status messages.
    -- 
    print( "\nListening upon:" );
    print( "  http://localhost:" .. port .. "/" );
    print( "\nLoading virtual hosts from beneath: " );
    print( "  "  .. root .. "\n\n");


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
    client,ip = socket.accept( listener );

    found   = 0;
    size    = 0;
    code    = 0;
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
    -- Decode the requested path.
    --
    path = urlDecode( path );


    --
    -- find the Virtual Host which we need for serving, and find the
    -- user agent and referer for logging purposes.
    --
    _, _, host    = string.find(request, "Host: ([^:\r\n]+)");
    _, _, agent   = string.find(request, "Agent: ([^\r\n]+)");
    _, _, referer = string.find(request, "Referer: ([^\r\n]+)");


    --
    -- If the request was for '/finish' then terminate ourselves
    --
    if ( path == "/finish" ) then
        running = 0;

        socket.write( client, "HTTP/1.0 200 OK\r\n" );
        socket.write( client, "Content-type: text/html\r\n" );
        socket.write( client, "Connection: close\r\n\r\n" );
        socket.write( client, "<html><head><title>Server Terminated</title></head>" );
        socket.write( client, "<body><h1>Server Terminated</h1><p>As per your request.</p></body></html>");
    else
        
        --
        -- Otherwise attempt to handle the connection.
        --
        size, code = handleRequest( root, host, path, client );
    end

    if ( agent == nil )   then agent   = "-" end;
    if ( referer == nil ) then referer = "-" end;
    if ( code == nill )   then code    = 0 ; end;

    --
    -- Log the access in something resembling the Apache common
    -- log format.
    -- 
    -- Note: The logging does not write the name of the virtual host.
    --
    logAccess( ip, path, code, size, agent, referer, major, minor );


    if ( running == 0 ) then
        print( "Terminating as per request from " .. ip );
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
    if ( string.endsWith( file, "/" ) ) then  
        file = file .. "index.html";
    end

    --
    --  File must be beneath the vhost root.
    --
    file = root .. host .. file ;

    --
    --  Attempt to sanitize the input Virtual Host + requested path.
    --
    file = string.strip( file );


    --
    -- Open the file and return an error if it fails.
    --    
    if ( fileExists( file ) == false ) then 
        size = sendError( client, 404, "File not found " .. urlEncode( path ) );
        return size, "404";
    end;


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
    socket.write( client, "Content-type: " .. mime[ ext ]  .. "\r\n" );
    socket.write( client, "Connection: close\r\n\r\n" );

    --
    -- Read the file, and then serve it.
    --
    f       = io.open( file, "rb" );
    size    = fileSize( f );
    local t = f:read("*all")
    socket.write( client, t );
    f:close();

    return size, "200" ;
end



--
--  Send the given error message to the client.
--  Return the length of data sent to the client so we know what to log.
--
function sendError( client, status, str )
    message = "HTTP/1.0 " .. status .. " OK\r\n" ;
    message = message .. "Content-type: text/html\r\n";
    message = message .. "Connection: close\r\n\r\n" ;
    message = message .. "<html><head><title>Error</title></head>" ;
    message = message .. "<body><h1>Error</h1" ;
    message = message .. "<p>" .. str .. "</p></body></html>" ;

    socket.write( client, message );
    return string.len(message) ;
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
--  Utility function:  Determine whether the given file exists.
--
function fileExists (file)
    local f = io.open(file, "rb");
    if f == nil then
        return false;
    else
        f:close();
        return true;
    end
end


--
--  Read the mime file and setup mime types
--
function loadMimeFile(file, table)
     local f = io.open( file, "r" );
     while true do
         local line = f:read()
         if line == nil then break end
         _, _, type, name = string.find( line, "^(.*)\t+([^\t]+)$" );
         if ( type ~= nil ) then
             for w in string.gfind(name, "([^%s]+)") do
                  table[w] = type;
             end
         end
     end
end


--
--  Utility function:   Does the string end with the given suffix?
--
function string.endsWith(String,End)
    return End=='' or string.sub(String,-string.len(End))==End
end


--
--  Strip path traversal requests.
--
function string.strip( str )
    return( string.gsub( str, "/../", "" ) );
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
-- Utility function:  URL decode function
--
function urlDecode(str)
    str = string.gsub (str, "+", " ") 
    str = string.gsub (str, "%%(%x%x)", function(h) return string.char(tonumber(h,16)) end) 
    str = string.gsub (str, "\r\n", "\n") 
    return str 
end


--
-- Log an access request.
--
function logAccess( ip, request, status, size, agent, referer, major, minor )
    date = os.date("%m/%b/%Y:%H:%M:%S +0000");

    --
    -- Format the logging line.
    --
    log  = string.format( '%s - - [%s] "GET %s HTTP/%s.%s" %s %s "%s" "%s"', ip, date, request, major, minor, status, size, referer, agent );

    print( log );
end




--
-----
---
--
--  This is the start of the real code.  Now that our functions have been
-- defined we actually execute from this point onwards.
--
---
----
--



--
--  Setup the MIME types our server will use for serving files.
--
if ( fileExists( "/etc/mime.types" ) ) then
    loadMimeFile( "/etc/mime.types",  mime );
else 
    --
    --  The global MIME types file does not exist.
    --  Setup minimal defaults.
    --
    print( "WARNING: /etc/mime.types could not be read." );
    print( "         Running with minimal MIME types." );

    mime[ "html" ]  = "text/html";
    mime[ "txt"  ]  = "text/plain";
    mime[ "jpg"  ]  = "image/jpeg";
    mime[ "jpeg" ]  = "image/jpeg";
    mime[ "gif"  ]  = "image/gif";
    mime[ "png"  ]  = "image/png";
end


--
--  Now start the server.
--
--
start_server( 4444, "./vhosts/" );
