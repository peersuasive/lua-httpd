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
--    ./vhosts/bob/htdocs/
--    ./vhosts/bob/htdocs/index.html    [etc]
--    ./vhosts/bob/logs/
--
--    ./vhosts/lappy/
--    ./vhosts/lappy/htdocs/
--    ./vhosts/lappy/htdocs/index.html  [etc]
--    ./vhosts/lappy/logs/
--
--    ./vhosts/localhost/
--    ./vhosts/localhost/htdocs/
--    ./vhosts/localhost/htdocs/index.html  [etc]
--    ./vhosts/localhost/logs/
--
--
--  (If you wish to allow for fully qualified hosts simply add symbolic
-- links to suit your hostnames.)
--
--
--  If a request arrives for a virtual host which you are not serving
-- then it will be passed to the faux server "default".  Simply create
-- a symbolic link to the server you wish to be your default host:
--
--    cd ./vhosts
--    ln -s lappy default
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
--  DOS attacks might be possible, although again the obvious cases
-- are covered.
--
--
-- Steve Kemp
-- --
-- http://www.steve.org.uk/
--
-- $Id: httpd.lua,v 1.31 2005-10-31 17:08:22 steve Exp $


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

    if ( listener == nil ) then
       error("Error in bind()");
    end

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

    found   = 0;  -- Found the end of the HTTP headers?
    chunk   = 0;  -- Count of data read from client socket
    size    = 0;  -- Total size of incoming request.
    code    = 0;  -- Status code we send to the client
    request = ""; -- Request body read from client.


    --
    --  Read in a response from the client, terminating at the first
    -- '\r\n\r\n' line - this is the end of the HTTP header request.
    --
    --  Also break out of this loop if we read ten packets of data
    -- from the client but didn't manage to find a HTTP header end.
    -- This should help protect us from DOSes.
    --
    while ( ( found == 0 ) and ( chunk < 10 ) ) do
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

        chunk = chunk + 1;
    end


    --
    --  OK We now have a complete HTTP request of 'size' bytes long
    -- stored in 'request'.
    --
    
    --
    -- Find the requested path.
    --
    _, _, method, path, major, minor  = string.find(request, "([A-Z]+) (.+) HTTP/(%d).(%d)");

    --
    -- We only handle GET requests.
    --
    if ( method ~= "GET" ) then
        error = "Method not implemented";

        if ( method == nil ) then
	    error = error .. ".";
        else
            error = error .. ": " .. urlEncode( method );
        end

        size = sendError( client, 501, error );
        socket.close( client );
        return size, "501";
    end


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
    -- If there was no "Host:" header then use "default".
    --
    if ( host == nil ) then
        host = "default";
    end


    --
    --  Is this a host that we're dealing with?
    --
    --  For this code to work we would ideally use the "os.stat" patch
    -- against Lua 5.0 which can be found at:
    --
    --     http://lua-users.org/wiki/PeterShook
    --
    --  Instead we use our own "is_dir" function inside the socket
    -- library.
    --
    info = socket.is_dir( root .. host );
    if ( not info ) then
       host = 'default';
    end

    --
    -- If the request was for '/finish' then terminate ourselves
    --
    if ( path == "/finish" ) then
        running = 0;

        socket.write( client, "HTTP/1.0 200 OK\r\n" );
        socket.write( client, "Server: lua-httpd " .. socket.version .. "\r\n" );
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
    logAccess( root, host, ip, path, code, size, agent, referer, major, minor );


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
function handleDirectory( client, path, request )
 
     a = socket.readdir( path );

    socket.write( client, "HTTP/1.0 200 OK\r\n" );
    socket.write( client, "Server: lua-httpd " .. socket.version .. "\r\n" );
    socket.write( client, "Content-type: text/html\r\n" );
    socket.write( client, "Connection: close\r\n\r\n" );

    msg = "";
    msg = msg .. "<html><head><title>Files in " .. request .. "</title></head>";
    msg = msg .. "<body><h2>Files in " .. request .. "</h2>\n";
    msg = msg .. "<ul>\n";

    for i=0,table.getn(a) do
         item = a[i];
         if ( socket.is_dir( path .. "/" .. item ) ) then
                item = item .. "/";
         end
         msg = msg .. "<li><a href=\"" .. item .. "\">" .. item .. "</a></li>\n";
    end

    msg = msg .. "</ul></body></html>\n";
    socket.write( client, msg );

    return string.len(msg) ;

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
    --  File must be beneath the vhost root.
    --
    file = root .. host .. "/htdocs" .. file ;

    --
    --  Attempt to sanitize the input Virtual Host + requested path.
    --
    file = string.strip( file );


    --
    -- Add a trailing "index.html" to paths ending in / if such
    -- a file exists.
    --
    -- Otherwise if it is a directory then serve it.
    --
    if ( string.endsWith( file, "/" ) ) then  
        tmp = file .. "index.html";
        if ( fileExists( tmp ) ) then
           file = tmp;
        else
           if ( socket.is_dir( file ) ) then
               size = handleDirectory( client, file, path ) ;
               socket.close( client );
               return size, "200";
           end
        end
    end


 

    --
    -- Open the file and return an error if it fails.
    --    
    if ( fileExists( file ) == false ) then 
        size = sendError( client, 404,"File not found " .. urlEncode( path ) );
        socket.close( client );
        return size, "404";
    end;


    --
    -- Find the suffix to get the mime.type.
    --
    _, _, ext  = string.find( file, [=[\.([^\.]+)$]=] );
    if ( ext == nil ) then
       ext = "html";   -- HACK
    end
    
    type = mime[ext];
    if ( type == nil ) then type = 'text/plain' ; end;

    --
    -- Send out the header.
    --
    socket.write( client, "HTTP/1.0 200 OK\r\n" );
    socket.write( client, "Server: lua-httpd " .. socket.version .. "\r\n" );
    socket.write( client, "Content-type: " .. type  .. "\r\n" );
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
    message = message .. "Server: lua-httpd " .. socket.version .. "\r\n";
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
function logAccess( root, host, ip, request, status, size, agent, referer, major, minor )
    date = os.date("%m/%b/%Y:%H:%M:%S +0000");

    --
    -- Format the logging line.
    --
    log  = string.format( '%s - - [%s] "GET %s HTTP/%s.%s" %s %s "%s" "%s"', ip, date, request, major, minor, status, size, referer, agent );

    logfile = root ..  host .. "/logs/access.log"

    --
    -- Open logfile for appending.
    --
    file = io.open( logfile , "a" );
    if ( file ~= nil ) then
        file:write( log .. "\n" );
        file:close();
    else
        print( "WARNING : Unable to open logfile for writing : " .. logfile );
    end

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
