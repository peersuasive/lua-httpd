/* -*-mode: C++; style: K&R; c-basic-offset: 4 ; -*- */

/**
 *  libhttpd.cpp
 *   Simple network primitives for use by the Lua 5.0 scripting engine.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
 *
 *  Steve Kemp
 *  ---
 *  http://www.steve.org.uk/
 *
 */


#include <stdio.h>
#include <stdlib.h>

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h> 
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>

#include <unistd.h>
 
#define MYNAME		"libhttpd"
#define MYVERSION	MYNAME " library for " LUA_VERSION " / Oct 2005"


#include "lua.h"
#include "lauxlib.h"



/**
 * Return an error string to the LUA script.
 * @param L The Lua intepretter object.
 * @param info An error string to return to the caller.  Pass NULL to use the return value of strerror.
 */
static int pusherror(lua_State *L, const char *info)
{
    lua_pushnil(L);

    if (info==NULL)
	lua_pushstring(L, strerror(errno));
    else
	lua_pushfstring(L, "%s: %s", info, strerror(errno));

    lua_pushnumber(L, errno);
    return 3;
}


/**
 * Bind a socket to a port, and return it.
 * @param L The lua intepreter object.
 * @return The number of results to be passed back to the calling Lua script.
 */
static int pBind(lua_State *L)
{
    int sockfd;
    struct sockaddr_in serv_addr;
    int on   = 1;
    int port = 0;

    if (lua_isnone(L, 1))
	return( pusherror(L, "bind(int) requires a port number" ) );
    else if (lua_isnumber(L, 1))
	port =lua_tonumber(L, 1);
    else
	return( pusherror(L, "bind(int) a port number" ) );

    sockfd = socket(AF_INET, SOCK_STREAM, 0);
    if (sockfd < 0) 
        return( pusherror(L, "ERROR opening socket") );


    /* Enable address reuse */
    setsockopt( sockfd, SOL_SOCKET, SO_REUSEADDR, &on, sizeof(on) );

    bzero((char *) &serv_addr, sizeof(serv_addr));

    serv_addr.sin_family = AF_INET;
    serv_addr.sin_addr.s_addr = INADDR_ANY;
    serv_addr.sin_port = htons(port);

    if (bind(sockfd, (struct sockaddr *) &serv_addr, sizeof(serv_addr)) < 0) 
	return( pusherror(L, ("ERROR on binding") ));

    listen(sockfd,5);

    /* Return socket */
    lua_pushnumber(L, sockfd);
    return( 1 );
}




/**
 * Connect a socket to a host/port, and return it.
 * @param L The lua intepreter object.
 * @return The number of results to be passed back to the calling Lua script.
 */
static int pConnect(lua_State *L)
{
    struct sockaddr_in sa;
    struct hostent *hp;
    int ret,sockfd;
    const char *host;
    int port = 0;

    if (lua_isnone(L, 1))
	return( pusherror(L, "connect(string, int) requires a hostname" ) );
    else if (lua_isstring(L, 1))
	host = lua_tostring(L, 1);
    else
	return( pusherror(L, "connect(string,int) incorrect first argument" ) );
    if (lua_isnone(L, 2))
	return( pusherror(L, "connect(string, int) requires a port number" ) );
    else if (lua_isnumber(L, 2))
	port = lua_tonumber(L, 2);
    else
	return( pusherror(L, "connect(string,int) incorrect second argument" ) );

 
    hp = gethostbyname(host);
    bcopy((char *)hp->h_addr, (char *)&sa.sin_addr, hp->h_length);
    sa.sin_family = hp->h_addrtype;
    sa.sin_port = htons(port);
    sockfd = socket(hp->h_addrtype, SOCK_STREAM, 0);
    ret = connect(sockfd, (struct sockaddr *)&sa, sizeof(sa));

    /* Return socket */
    lua_pushnumber(L, sockfd);
    return( 1 );
}



/**
 * Accept a new connection upon a socket.  Return the new client.
 * @param L The lua intepreter object.
 * @return The number of results to be passed back to the calling Lua script.
 */
static int pAccept(lua_State *L)
{
    int sockfd, newsockfd;
    socklen_t clilen;
    struct sockaddr_in  cli_addr;

    if (lua_isnone(L, 1))
	return( pusherror(L, "accept(int) requires a socket." ) );
    else if (lua_isnumber(L, 1))
	sockfd =lua_tonumber(L, 1);
    else
	return( pusherror(L, "accept(int) a port number" ) );
    
    clilen = sizeof(cli_addr);
    newsockfd = accept(sockfd, (struct sockaddr *) &cli_addr, &clilen);

    if (newsockfd < 0) 
	return( pusherror(L,"ERROR on accept"));

    lua_pushnumber(L,newsockfd);
    return 1; /* we never get here */
}



/**
 * Read from a socket, return the data and the length read.
 * @param L The lua intepreter object.
 * @return The number of results to be passed back to the calling Lua script.
 */
static int pRead(lua_State *L)
{
    int sockfd;
    int n = 0;
    char buffer[1024*16];
    memset( buffer, '\0', sizeof(buffer));
    
    if (lua_isnone(L, 1))
	return( pusherror(L, "read(int)" ) );
    else if (lua_isnumber(L, 1))
	sockfd =lua_tonumber(L, 1);
    else
	return( pusherror(L, "read(int)" ) );
    
    n = read(sockfd,buffer,sizeof(buffer)-1);


    lua_pushnumber(L, n );
    lua_pushstring(L, buffer );
    
    return( 2 );
}



/**
 * Write data to a socket.
 * @param L The lua intepreter object.
 * @return The number of results to be passed back to the calling Lua script.
 */
static int pWrite(lua_State *L)
{
    int sockfd;
    const char *data = NULL;
    int length       = 0;

    /* Get the number of arguments. */
    int n = lua_gettop(L);

    if ( ( n != 2 ) && ( n != 3 ) )
	return( pusherror(L, "write(int,string,[size])" ) );

    if (lua_isnumber(L, 1))
	sockfd =lua_tonumber(L, 1);
    else
	return( pusherror(L, "write(int,string,[size])" ) );

    /*
     * Supplied the string only
     */
    if ( n == 2 )
    {
	if (lua_isstring(L, 2))
	    data = lua_tostring(L, 2);
	else
	    return( pusherror(L, "write(int,string,[size])" ) );

	length = strlen( data );
    }
    else if ( n == 3 )
    {
	if (lua_isstring(L, 2))
	    data = lua_tostring(L, 2);
	else
	    return( pusherror(L, "write(int,string,[size])" ) );

	if (lua_isnumber(L, 3))
	    length = lua_tonumber(L, 3);
	else
	    return( pusherror(L, "write(int,string,[size])" ) );
    }

    if ( write( sockfd, data, length) < 0 )
	return( pusherror(L, "Problem writing to socket" ) );

    return 0; /* we never get here */
}



/**
 * Close a socket.
 * @param L The lua intepreter object.
 * @return The number of results to be passed back to the calling Lua script.
 */
static int pClose(lua_State *L)
{
    int sockfd;

    if (lua_isnone(L, 1))
	return( pusherror(L, "close(int)" ) );
    else if (lua_isnumber(L, 1))
	sockfd =lua_tonumber(L, 1);
    else
	return( pusherror(L, "close(int)" ) );

    close( sockfd );

    return( 0 );
}



/**
 * Mappings between the LUA code and our C code.
 */
static const luaL_reg R[] =
{
    {"bind",		pBind},
    {"connect",		pConnect},
    {"accept",		pAccept},
    {"close",           pClose},
    {"read",		pRead},
    {"write",		pWrite},
    {NULL,		NULL}
};



/**
 * Bind our exported functions to the Lua intepretter, making our functions
 * available to the calling script.
 * @param L The lua intepreter object.
 * @return 1 on success, 0 on failure.
 */
LUALIB_API int luaopen_libhttpd (lua_State *L)
{
    luaL_openlib(L, MYNAME, R, 0);
    lua_pushliteral(L,"version");		/** version */
    lua_pushliteral(L,MYVERSION);
    lua_settable(L,-3);
    return 1;
}

