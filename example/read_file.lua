#!/usr/bin/env luajit
local this_dir = arg[0]:match('(.+/)[^/]+%.lua') or './'
package.path = this_dir..'../src/'..package.path

local process = require'nodish.process'
local fs = require'nodish.fs'

fs.readFile(this_dir..'../README.md',function(err,data)
    process.stdout:write(data)
  end)

process.loop()

