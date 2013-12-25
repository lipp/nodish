nodish
==========

A lightweight Lua equivalent to [Node.js](http://nodejs.org) [net module](http://nodejs.org/api/net.html). [![Build Status](https://travis-ci.org/lipp/nodish.png?branch=master)](https://travis-ci.org/lipp/nodish).

Unlike [luvit](http://github.com/luvit/luvit) or [LuaNode](http://github.com/ignacio/luanode) this project does try NOT (yet) to be a complete node.js port. Instead it tries to keep dependecies as minimal as possible to keep size small for embedded systems. The minimal required modules are:

- [luasocket](http://github.com/diegonehab/luasocket)
- [lua-ev](http://github.com/brimworks/lua-ev)


Examples
========

Echo Server
-----------

```lua
local net = require'nodish.net'

net.listen(12345):on('connection',function(client)
  client:set_nodelay(true)
  client:on('data',function(data)
      client:write(data)
    end)
  end)

net.loop()    
```

Echo Client
-----------

```lua
local net = require'nodish.net'
local ev = require'ev'

local client = net.connect(12345)
client:on('connect',function()
    client:set_nodelay(true)
    client:on('data',function(data)
        print('->',data)
      end)
    local i = 0
    ev.Timer.new(function()
        i = i + 1
        print('<-',i)
        client:write(tostring(i))
      end,1,1):start(ev.Loop.default)
  end)

net.loop()
```




