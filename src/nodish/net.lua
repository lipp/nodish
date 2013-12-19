local socket = require'nodish.net.socket'
local server = require'nodish.net.server'
local ev = require'ev'

local unloop = function()
  print('quitting')
  ev.Loop.default:unloop()
end

local loop = function()
  local sigkill = 9
  local sigint = 2
  local sigquit = 3
  local sighup = 1
  for _,sig in ipairs({sigkill,sigint,sigquit,sighup}) do
    ev.Signal.new(
      unloop,
    sig):start(ev.Loop.default)
  end
  
  local sigpipe = 13
  ev.Signal.new(
    function()
      print('SIGPIPE ignored')
    end,
  sigpipe):start(ev.Loop.default)
  
  ev.Loop.default:loop()
end

return {
  socket = socket,
  connect = socket.connect,
  create_connection = socket.create_connection,
  loop = loop,
  unloop = unloop,
  listen = server.listen,
}
