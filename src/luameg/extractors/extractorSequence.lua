
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

local function insertEdgeIntoHypergraph (classMethods, methodName, hypergraph)
  for key, method in pairs(classMethods) do
    if (method.data.name == methodName) then
      local edge = luadb.edge.new()
      edge.label = "Executes"
      edge:setSource(graphSourceNode)
      edge:setTarget(method)
      edge:setAsOriented()
      hypergraph:addEdge(edge)
      break
    end
  end

  return hypergraph
end

-- ........................................................
local function subsequentMethodHelper(methodNode, hypergraph, scope, graphClassNode, graphSourceNode)

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

        -- test if line contains assign statement or not
        if (assignModule.isAssignStatement(statement)) then
          methodCallNode = findMethodCall(statement.data[2])
          variableAssignedTo = assignModule.getName(statement.data[1])
          print("\tAssign Statement, variable name is: " .. variableAssignedTo)

          if (methodCallNode ~= nil) then
            local variableCalledFrom, methodName = assignModule.constructMethodNode(methodCallNode)
            local callNodes = hypergraph:findNodeByName(methodName)

            -- TODO: handle method names that are the same as class names
            if (callNodes[1].meta.type == 'Class') and (variableCalledFrom == '') then
              scope[variableAssignedTo] = methodName
              print( "\tConstructor: " .. methodName)
            elseif (callNodes[1].meta.type == 'Method') and (variableCalledFrom == '') then
              local classMethods = hypergraph:findEdgesBySource(graphClassNode.id, 'Contains')

              hypergraph = insertEdgeIntoHypergraph(classMethods, methodName, hypergraph)

              print( "\tSelf method call: " .. methodName)
            elseif (callNodes[1].meta.type == 'Method') and (variableCalledFrom ~= '') then
              local variableType = scope[variableCalledFrom]
              if (variableType) then
                -- TODO: handle case when class name is not found
                local classNode = hypergraph:findNodeByName(variableType)[1]
                local classMethods = hypergraph:findEdgesBySource(classNode.id, 'Contains')

                hypergraph = insertEdgeIntoHypergraph(classMethods, methodName, hypergraph)
              end
              print( "\t" .. "Var: " .. variableCalledFrom .. ", Method: " .. methodName)
            end
            
          end
        -- not assign statement block
        else
          methodCallNode = findMethodCall(statement.data[1])

          if (methodCallNode ~= nil) then
            local variableCalledFrom, methodName = assignModule.constructMethodNode(methodCallNode)
            print( "\tVoid Call on method: " .. methodName)

            local callNodes = hypergraph:findNodeByName(methodName)

            if (assignModule.isSystemCall(methodName)) or (#callNodes == 0) then
              print ("\tSystem call.")
            elseif (callNodes[1].meta.type == 'Method') and (variableCalledFrom == '') then
              local classMethods = hypergraph:findEdgesBySource(graphClassNode.id, 'Contains')

              hypergraph = insertEdgeIntoHypergraph(classMethods, methodName, hypergraph)

              print( "\tSelf method call: " .. methodName)
            elseif (callNodes[1].meta.type == 'Method') and (variableCalledFrom ~= '') then
              local variableType = scope[variableCalledFrom]
              if (variableType) then
                -- TODO: handle case when class name is not found
                local classNode = hypergraph:findNodeByName(variableType)[1]
                local classMethods = hypergraph:findEdgesBySource(classNode.id, 'Contains')

                hypergraph = insertEdgeIntoHypergraph(classMethods, methodName, hypergraph)
              end
              print( "\t" .. "Var: " .. variableCalledFrom .. ", Method: " .. methodName)
            end
            
          end

          -- TODO: implement loop and condition detection

        end
      end
    end
  end

  return hypergraph
end



local function getSubsequentMethods(ast, hypergraph)

  local classes = hypergraph:findNodesByType('Class')

  for key, class in pairs(classes) do
    print("CLASS: ", class.data.name, class.meta.type, class.data.astNodeId)

    local classMethods = hypergraph:findEdgesBySource(class.id, 'Contains')
    for key, classMethod in pairs(classMethods) do

      -- print(key, classMethod.label, classMethod.to, classMethod.from)
      local methodNode = classMethod.to[1]
      if (methodNode.meta.type == 'Method') then
        print("METHOD: ", methodNode.data.name, methodNode.meta.type, methodNode.data.astNodeId)

        local astMethodNode = findAstNode(ast, methodNode.data.astNodeId)

        hypergraph = subsequentMethodHelper(astMethodNode, hypergraph, {}, class, classMethod)

      end
      -- print('\t', methodNode.id, methodNode.data.name, methodNode.meta.type, methodNode.data.astNodeId)
    end

  end


  return hypergraph
end



return {
  getSubsequentMethods = getSubsequentMethods
}

