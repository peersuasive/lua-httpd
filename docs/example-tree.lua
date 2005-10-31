#!/usr/bin/lua50

-- Load the library
socket = require( "libhttpd" );




function showPath( dir, level )
    --  Read directory entries.
    local  entries = socket.readdir( dir );

    -- For each entry
    for i=0,table.getn(entries) do
        -- The sub-entry
        item = entries[i];

        -- If it is a file then show it.
        if ( socket.is_file(  dir .. "/" .. item ) ) then
             -- Print filename with indentation
             ind   = level;
	     txt = "";
             while( ind > 0 ) do 
                 txt = txt .. "  " ; 
                 ind = ind - 1;
             end
             print( txt .. item );
        end
 
    end


    -- Now do the same for subdirectories
   for i=0,table.getn(entries) do
       -- The sub-entry
       item = entries[i];

       -- Make sure we have a valid directory which isn't '.', or '..'.
       if ( ( item ~= nil ) and  ( item ~= "." ) and ( item ~= ".." ) ) then
           if ( socket.is_dir( dir .. "/" .. item ) ) then
               -- Print it out.
               print ( dir .. "/" .. item .. "/" );
               -- Now recurse:
 	       showPath( dir .. "/" .. item, (level + 1) );
           end
       end
   end
end



showPath( ".", 1 );