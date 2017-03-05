
-- imports area starts

local assignModule = require './assignMethodCall'
local luadb = require 'luadb.hypergraph'

-- imports area ends


local function findMethod(className, methodName)

end


-- ........................................................
local function subsequentMethodHelper()

  -- STEP 1: iterate through method node data, which contains all subsequent statements

  -- STEP 2: in every iteration distinguish two cases: assign statement and just call 
  --         statement

end



local function getSubsequentMethods(ast, hypergraph)

  -- STEP 1: create method node for new data structure specific for sequence detector
  --         using method call module

  -- STEP 2: call recursive method for discovering all important children of actual / 
  --         desired method; this metode should always return an array of subsequent
  --         statement such as methods, cycles or conditionals; probably its needed to
  --         create method variable scope before calling recursion

  local rootMethodNode = assignModule.constructMethodNode(introMethodNode)

  -- NOTE: introMethodNode is general node in AST, so we need find body of this method
  -- in the first place

end



return {
  getSubsequentMethods = getSubsequentMethods
}

