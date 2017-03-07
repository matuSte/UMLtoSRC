
-- imports area starts

local assignModule = require 'luameg.extractors.extractorSequenceHelpers.assignMethodCall'
local luadb = require 'luadb.hypergraph'

-- imports area ends

local function findMethodBody(methodNode)

  local methodBody = nil

  for index, node in pairs(methodNode.data) do

    if (node.key == 'Block') then
      methodBody = node
      break
    else
      methodBody = findMethodBody(node)
      if (methodBody ~= nil) then
        break
      end
    end

  end

  return methodBody
end


local function findMethodCall(statement)
  local methodCall = nil

  for i, node in pairs(statement.data) do
    if (assignModule.isFunctionCall(node)) then
      methodCall = node
      break
    else
      methodCall = findMethodCall(node)
    end
  end

  return methodCall
end


local function findAstNode(ast, astNodeId)
  local node = ast['nodeid_references'][astNodeId]
  return node
end


-- ........................................................
local function subsequentMethodHelper(methodNode, hypergraph)

  -- STEP 1: iterate through method node data, which contains all subsequent statements

  -- STEP 2: in every iteration distinguish two cases: assign statement and just call 
  --         statement
  local methodNodeBody = findMethodBody(methodNode)

  if (methodNodeBody == nil) then
    return hypergraph
  end

  for index, line in pairs(methodNodeBody.data) do

    for key, statement in pairs(line.data) do
      if (statement.key == 'Statement') then

        local methodCallNode
        if (assignModule.isAssignStatement(statement)) then
          methodCallNode = findMethodCall(statement.data[2])
        else
          methodCallNode = findMethodCall(statement.data[1])
        end

        if (methodCallNode ~= nil) then
          local variableName, methodName = assignModule.constructMethodNode(methodCallNode)
          print( "\t\t" .. "Var: " ..variableName .. ", Method: " .. methodName)
        end
        
      end
    end

  end

  return hypergraph
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
      if (methodNode.meta.type == 'Method') then

        local astMethodNode = findAstNode(ast, methodNode.data.astNodeId)

        hypergraph = subsequentMethodHelper(astMethodNode, hypergraph)

      end
      -- print('\t', methodNode.id, methodNode.data.name, methodNode.meta.type, methodNode.data.astNodeId)
    end

  end


  return hypergraph
end



return {
  getSubsequentMethods = getSubsequentMethods
}

