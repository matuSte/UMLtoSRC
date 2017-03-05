
-- imports area starts

-- local assignModule = require './extractorSequenceHelpers/assignMethodCall'
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

  -- local rootMethodNode = assignModule.constructMethodNode(introMethodNode)

  -- NOTE: introMethodNode is general node in AST, so we need find body of this method
  -- in the first place

  local classes = hypergraph:findNodesByType('Class')

  for key, class in pairs(classes) do
    print(class.id, class.data.name, class.meta.type, class.data.astNodeId)

    local classMethods = hypergraph:findEdgesBySource(class.id, 'Contains')
    for key, classMethod in pairs(classMethods) do

      -- print(key, classMethod.label, classMethod.to, classMethod.from)

      local methodNode = classMethod.to[1]
      print('\t', methodNode.id, methodNode.data.name, methodNode.meta.type, methodNode.data.astNodeId)
    end

  end


  return hypergraph
end



return {
  getSubsequentMethods = getSubsequentMethods
}

