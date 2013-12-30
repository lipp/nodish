local socket = require'nodish.net.socket'
local server = require'nodish.net.server'

return {
  socket = socket,
  connect = socket.connect,
  createConnection = socket.createConnection,
  listen = server.listen,
}
