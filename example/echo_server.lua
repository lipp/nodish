#!/usr/bin/env lua
local this_dir = arg[0]:match('(.+/)[^/]+%.lua') or './'
package.path = this_dir..'../src/'..package.path

local net = require'nodish.net'
local process = require'nodish.process'

local server = net.listen(12345)
server:on('connection',function(client)
    client:pipe(client)
    client:pipe(process.stdout)
  end)

process.loop()
