#!/usr/bin/env luajit
local this_dir = arg[0]:match('(.+/)[^/]+%.lua') or './'
package.path = this_dir..'../src/'..package.path

local net = require'nodish.net'
local process = require'nodish.process'

net.createServer(function(client)
    client:pipe(client)
    client:pipe(process.stdout,false)
  end):listen(12345)

process.loop()
