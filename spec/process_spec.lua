setloop('ev')

describe('The process module',function()
    local process = require'nodish.process'
    
    it('provides new method',function()
        assert.is_function(process.new)
      end)
    
    it('provides nexttick method',function()
        assert.is_function(process.nexttick)
      end)
    
    it('the nexttick callback gets called',function(done)
        process.nexttick(async(function()
              done()
          end))
      end)
    
    it('the nexttick callback gets called from another call context',function(done)
        local s = {}
        process.nexttick(async(function()
              assert.is_true(s.dirty)
              done()
          end))
        s.dirty = true
      end)
    
  end)
