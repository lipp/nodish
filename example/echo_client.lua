#!/usr/bin/env lua
local this_dir = arg[0]:match('(.+/)[^/]+%.lua') or './'
package.path = this_dir..'../src/'..package.path

local net = require'nodish.net'
local process = require'nodish.process'
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
        client:write(tostring(i)..'\n')
      end,1,1):start(ev.Loop.default)
  end)

process.loop()
