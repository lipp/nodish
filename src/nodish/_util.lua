local loop = require'ev'.Loop.default

local daemonize = function(watcher,makeDaemon)
  -- keep pending info, since watcher:stop also
  -- would call watcher:clear_pending internally
  -- with no chance of recovery
  local revents = watcher:clear_pending(loop)
  watcher:stop(loop)
  watcher:start(loop,makeDaemon)
  if revents ~= 0 then
    watcher:callback()(loop,watcher,revents)
  end
end

local ref = function(watcher)
  daemonize(watcher,false)
end

local unref = function(watcher)
  daemonize(watcher,true)
end


return {
  ref = ref,
  unref = unref,
}
