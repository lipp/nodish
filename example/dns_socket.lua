#!/usr/bin/env luajit
local this_dir = arg[0]:match('(.+/)[^/]+%.lua') or './'
package.path = this_dir..'../src/'..package.path

local net = require'nodish.net'
local process = require'nodish.process'

local client = net.connect(53,'192.168.1.1')
client:on('connect',function()
    print('connected')
  end)

process.loop()
