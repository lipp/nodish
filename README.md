nodish
==========

A lightweight Lua equivalent to [Node.js](http://nodejs.org) [net module](http://nodejs.org/api/net.html). [![Build Status](https://travis-ci.org/lipp/nodish.png?branch=master)](https://travis-ci.org/lipp/nodish).

Unlike [luvit](http://github.com/luvit/luvit) or [LuaNode](http://github.com/ignacio/luanode) this project does try to be a complete node.js port. Instead it tries dependecies as minimal as possible to keep size small for embedded systems. The minimal required deps are:

- [luasocket](http://github.com/diegonehab/luasocket)
- [lua-ev](http://github.com/brimworks/lua-ev)


Examples
========

Echo Server
-----------

```lua
local net = require'nodish.net'
local process = require'nodish.process'

net.listen(12345):on('connection',function(client)
	client:pipe(client)
	client:pipe(process.stdout)
  end)

process.loop()    
```

Echo Client
-----------

```lua
local net = require'nodish.net'
local process = require'nodish.process'

local client = net.connect(12345)
client:on('connect',function()
	process.stdin:pipe(client)
	client:pipe(process.stdout)
  end)

process.loop()
```




