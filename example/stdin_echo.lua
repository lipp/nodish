#!/usr/bin/env lua
local this_dir = arg[0]:match('(.+/)[^/]+%.lua') or './'
package.path = this_dir..'../src/'..package.path

local process = require'nodish.process'
local ev = require'ev'

process.stdin:pipe(process.stdout)
process.stdin:resume()

ev.Loop.default:loop()
