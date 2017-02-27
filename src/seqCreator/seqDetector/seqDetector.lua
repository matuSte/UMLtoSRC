
-- imports area starts

local assignModule = require './assignMethodCall'

-- imports area ends
-- ........................................................
function subsequentMethodHelper()

  -- STEP 1: iterate through method node data, which contains all subsequent statements

  -- STEP 2: in every iteration distinguish two cases: assign statement and just call 
  --         statement

end



function getSubsequentMethods(ast, introMethodNode, className)

  -- STEP 1: create method node for new data structure specific for sequence detector
  --         using method call module

  -- STEP 2: call recursive method for discovering all important children of actual / 
  --         desired method; this metode should always return an array of subsequent
  --         statement such as methods, cycles or conditionals; probably its needed to
  --         create method variable scope before calling recursion

end

return {
  find = find,
  getSubsequentMethods = getSubsequentMethods
}