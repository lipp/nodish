nodish
==========

A lightweight Lua equivalent to [Node.js](http://nodejs.org). [![Build Status](https://travis-ci.org/lipp/nodish.png?branch=master)](https://travis-ci.org/lipp/nodish).

Unlike [luvit](http://github.com/luvit/luvit) or [LuaNode](http://github.com/ignacio/luanode) this project does try NOT (yet) to be a complete node.js port. Instead it tries to keep dependecies as minimal as possible to keep size small for embedded systems. To use nodish you need:

- [ljsyscall](http://github.com/justincormack/ljsyscall) to interface to the system (sockets,read,write,etc)
- [lua-ev](http://github.com/brimworks/lua-ev) as I/O loop framework


Examples
========

Echo Server
-----------

```lua
local net = require'nodish.net'
local process = require'nodish.process'

net.createServer(function(client)
	client:pipe(client)
	client:pipe(process.stdout)
  end):listen(12345)

process.loop()    
```

Echo Client
-----------

```lua
local net = require'nodish.net'
local process = require'nodish.process'

local client = net.connect(12345)
client:on('connect',function()
	process.stdin:pipe(client)
	client:pipe(process.stdout)
  end)

process.loop()
```

Installation
============

Linux (Debian based)
--------------------

```shell
sudo add-apt-repository ppa:mwild1/ppa -y
sudo apt-get update -y
sudo apt-get install luajit -y --force-yes
sudo apt-get install libev-dev
sudo apt-get install luarocks
git clone git://github.com/justincormack/ljsyscall.git
cd ljsyscall
sudo luarocks make rockspec/ljsyscall-scm-1.rockspec
cd ../
git clone http://github.com/lipp/nodish.git
cd nodish
sudo luarocks make rockspecs/nodish-scm-1.rockspec
```

OSX (with homebrew)
-------------------

```shell
brew install luajit
brew install libev
brew install luarocks
git clone git://github.com/justincormack/ljsyscall.git
cd ljsyscall
sudo luarocks make rockspec/ljsyscall-scm-1.rockspec
cd ../
git clone http://github.com/lipp/nodish.git
cd nodish
sudo luarocks make rockspecs/nodish-scm-1.rockspec
```

Status
======

| Module      | Status          | API                             |
-------------------------------------------------------------------
| net         | Almost complete | http://nodejs.org/api/net.html
| events      | Complete        | http://nodejs.org/api/events.html
| process     | Partial         | http://nodejs.org/api/process.html


