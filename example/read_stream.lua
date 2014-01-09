#!/usr/bin/env luajit
local this_dir = arg[0]:match('(.+/)[^/]+%.lua') or './'
package.path = this_dir..'../src/'..package.path

local process = require'nodish.process'
local fs = require'nodish.fs'
require'nodish.js'

local readStream = fs.createReadStream(this_dir..'../README.md')
readStream:on('open',function(fd)
    console.log('open',fd)
  end)

readStream:on('data',function(data)
    console.log('data',data)
  end)

process.loop()

