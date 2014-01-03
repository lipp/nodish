local socket = require'nodish.net.socket'
local server = require'nodish.net.server'

return {
  socket = socket,
  Socket = socket.new,
  connect = socket.connect,
  createConnection = socket.createConnection,
  createServer = server.createServer,
  isIP = socket.isIP,
  isIPv4 = socket.isIPv4,
  isIPv6 = socket.isIPv6,
}
