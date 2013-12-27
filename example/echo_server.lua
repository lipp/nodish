#!/usr/bin/env lua
local this_dir = arg[0]:match('(.+/)[^/]+%.lua') or './'
package.path = this_dir..'../src/'..package.path

local net = require'nodish.net'

local server = net.listen(12345)
server:on('connection',function(client)
    client:set_nodelay(true)
    client:on('data',function(data)
        print('<->',data)
        client:write(data)
      end)
  end)

net.loop()
