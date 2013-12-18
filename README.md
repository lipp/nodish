lua-ev-net
==========

The lua-ev equivalent to [Node.js](http://nodejs.org) [net module](http://nodejs.org/api/net.html) (for the rest of the rest). [![Build Status](https://travis-ci.org/lipp/lua-ev-net.png?branch=master)](https://travis-ci.org/lipp/lua-ev-net)

Unlike [luvit](http://github.com/luvit/luvit) or [LuaNode](http://github.com/ignacio/luanode) this project does try to be a complete node.js port. Instead it tries dependecies as minimal as possible. The deps are:

- [luasocket](http://github.com/diegonehab/luasocket)
- [lua-ev](http://github.com/brimworks/lua-ev)



Examples
========

Echo Server
-----------

```lua
local net = require'net'

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
local net = require'net'
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




