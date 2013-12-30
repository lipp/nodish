package = "nodish"
version = "scm-1"

source = {
  url = "git://github.com/lipp/nodish.git",
}

description = {
  summary = "A lightweight Lua equivalent to Node.js",
  homepage = "http://github.com/lipp/nodish",
  license = "MIT/X11",
  detailed = ""
}

dependencies = {
  "lua >= 5.1",
  "ljsyscall",
  "lua-ev",
  "luasocket",
}

build = {
  type = 'none',
  install = {
    lua = {
      ['nodish.emitter'] = 'src/nodish/emitter.lua',
      ['nodish.process'] = 'src/nodish/process.lua',
      ['nodish.nexttick'] = 'src/nodish/nexttick.lua',
      ['nodish.net'] = 'src/nodish/net.lua',
      ['nodish.stream'] = 'src/nodish/stream.lua',
      ['nodish.net.socket'] = 'src/nodish/net/socket.lua',
      ['nodish.net.server'] = 'src/nodish/net/server.lua',	
    }
  }
}

