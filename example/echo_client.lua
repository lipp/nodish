#!/usr/bin/env luajit
local this_dir = arg[0]:match('(.+/)[^/]+%.lua') or './'
package.path = this_dir..'../src/'..package.path

local net = require'nodish.net'
local process = require'nodish.process'

local client = net.connect(12345)

process.stdin:resume()
process.stdin:pipe(client)

process.loop()
