local socket = require'net.socket'
local server = require'net.server'
local ev = require'ev'

return {
  socket = socket,
  connect = socket.connect,
  create_connection = socket.create_connection,
  loop = function()
    ev.Loop.default:loop()
  end,
  unloop = function()
    ev.Loop.default:unloop()
  end,
  listen = server.listen,
}
