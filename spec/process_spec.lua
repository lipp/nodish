setloop('ev')

describe('The process module',function()
    local process = require'nodish.process'
    
    it('provides nextTick method',function()
        assert.is_function(process.nextTick)
      end)
    
    it('the nextTick callback gets called',function(done)
        process.nextTick(async(function()
              done()
          end))
      end)
    
    it('the nextTick callback gets called from another call context',function(done)
        local s = {}
        process.nextTick(async(function()
              assert.is_true(s.dirty)
              done()
          end))
        s.dirty = true
      end)
    
  end)
