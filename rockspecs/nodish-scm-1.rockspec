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
}

build = {
  type = 'none',
  install = {
    lua = {
      ['nodish.events'] = 'src/nodish/events.lua',
      ['nodish.process'] = 'src/nodish/process.lua',
      ['nodish.nexttick'] = 'src/nodish/nexttick.lua',
      ['nodish.dns'] = 'src/nodish/dns.lua',
      ['nodish.buffer'] = 'src/nodish/buffer.lua',
      ['nodish.net'] = 'src/nodish/net.lua',
      ['nodish._util'] = 'src/nodish/_util.lua',
      ['nodish.stream'] = 'src/nodish/stream.lua',
      ['nodish.net.socket'] = 'src/nodish/net/socket.lua',
      ['nodish.net.server'] = 'src/nodish/net/server.lua',	
    }
  }
}

