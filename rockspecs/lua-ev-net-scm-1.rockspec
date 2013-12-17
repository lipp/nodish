package = "lua-ev-net"
version = "scm-1"

source = {
  url = "git://github.com/lipp/lua-ev-net.git",
}

description = {
  summary = "The lua-ev equivalent to node.js net module",
  homepage = "http://github.com/lipp/lua-ev-net",
  license = "MIT/X11",
  detailed = ""
}

dependencies = {
  "lua >= 5.1",
  "luasocket",
  "lua-ev",
  "emitter"
}

build = {
  type = 'none',
  install = {
    lua = {
      ['net'] = 'src/net.lua',
      ['net.socket'] = 'src/net/socket.lua',
      ['net.server'] = 'src/net/server.lua',	
    }
  }
}

