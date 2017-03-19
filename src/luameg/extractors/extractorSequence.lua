
-- imports area starts

local assignModule = require 'luameg.extractors.extractorSequenceHelpers.assignMethodCall'
local conditionModule = require 'luameg.extractors.extractorSequenceHelpers.conditionControl'
local loopModule = require 'luameg.extractors.extractorSequenceHelpers.loopControl'
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

local function findConditionNode(statement)
  local conditionNode = nil

  for i, node in pairs(statement.data) do
    if (conditionModule.isConditionBlock(node)) then
      conditionNode = node
      break
    else
      conditionNode = findConditionNode(node)
    end
  end

  return conditionNode
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

local function insertEdgeIntoHypergraph (graphSourceNode, classMethods, methodName, hypergraph)
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

local function copyScope(scope)
  local newScope = {}

  for key, item in pairs(scope) do
    newScope[key] = item

    print("SCOPE COPY\n" .. key .. " - " .. item)
    print(newScope[key])
  end

  return newScope
end

local function setupConditionBranch(nodeName, nodeAstId, graphSource, hypergraph)
  -- create first condition branch node
  local newCondBranch = luadb.node.new()
  newCondBranch.meta = newCondBranch.meta or {}
  newCondBranch.meta.type = "ConditionBranch"
  newCondBranch.data.name = nodeName
  newCondBranch.data.astNodeId = nodeAstId

  hypergraph:addNode(newCondBranch)

  -- create also edge to connect these two nodes
  local branchEdge = luadb.edge.new()
  branchEdge.label = "HasBranch"
  branchEdge:setSource(graphSource)
  branchEdge:setTarget(newCondBranch)
  branchEdge:setAsOriented()

  hypergraph:addEdge(branchEdge)
  -- end

  return hypergraph, newCondBranch
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

              hypergraph = insertEdgeIntoHypergraph(graphSourceNode, classMethods, methodName, hypergraph)

              print( "\tSelf method call: " .. methodName)
            elseif (callNodes[1].meta.type == 'Method') and (variableCalledFrom ~= '') then
              local variableType = scope[variableCalledFrom]
              if (variableType) then
                -- TODO: handle case when class name is not found
                local classNode = hypergraph:findNodeByName(variableType)[1]
                local classMethods = hypergraph:findEdgesBySource(classNode.id, 'Contains')

                hypergraph = insertEdgeIntoHypergraph(classNode, classMethods, methodName, hypergraph)
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

              hypergraph = insertEdgeIntoHypergraph(graphSourceNode, classMethods, methodName, hypergraph)

              print( "\tSelf method call: " .. methodName)
            elseif (callNodes[1].meta.type == 'Method') and (variableCalledFrom ~= '') then
              local variableType = scope[variableCalledFrom]
              if (variableType) then
                -- TODO: handle case when class name is not found
                local classNode = hypergraph:findNodeByName(variableType)[1]
                local classMethods = hypergraph:findEdgesBySource(classNode.id, 'Contains')

                hypergraph = insertEdgeIntoHypergraph(classNode, classMethods, methodName, hypergraph)
              end
              print( "\t" .. "Var: " .. variableCalledFrom .. ", Method: " .. methodName)
            end
            
          else
            local conditionNode = findConditionNode(statement.data[1])

            if (conditionNode ~= nil) then

              -- create new luadb node, setup with proper values and insert into hypergraph
              local newCondNode = luadb.node.new()
              newCondNode.meta = newCondNode.meta or {}
              newCondNode.meta.type = "Condition"
              newCondNode.data.name = "Condition"
              newCondNode.data.astNodeId = conditionNode.nodeid

              hypergraph:addNode(newCondNode)
              -- condition node creation end

              -- create new edge to connect method with created condition node
              local edge = luadb.edge.new()
              edge.label = "Executes"
              edge:setSource(graphSourceNode)
              edge:setTarget(newCondNode)
              edge:setAsOriented()

              hypergraph:addEdge(edge)
              -- edge between method and conditon node creation end

              local newCondBranch
              hypergraph, newCondBranch = setupConditionBranch(
                conditionNode.data[2].text, 
                conditionNode.data[3].nodeid, 
                newCondNode, 
                hypergraph
              )

              local newScope = copyScope(scope)

              hypergraph = subsequentMethodHelper(
                conditionNode.data[3], 
                hypergraph, 
                newScope, 
                graphClassNode, 
                newCondBranch
              )

              for key, conditionBranch in pairs(conditionNode.data) do

                if (conditionBranch.key == "IfElseIf") then

                  local newCondBranch
                  hypergraph, newCondBranch = setupConditionBranch(
                    conditionBranch.data[3].text, 
                    conditionBranch.data[4].nodeid, 
                    graphSourceNode, 
                    hypergraph
                  )

                  local newScope = copyScope(scope)

                  hypergraph = subsequentMethodHelper(
                    conditionBranch.data[4], 
                    hypergraph, 
                    newScope, 
                    graphClassNode, 
                    newCondBranch
                  )
                elseif (conditionBranch.key == "IfElse") then

                  local newCondBranch
                  hypergraph, newCondBranch = setupConditionBranch(
                    "default", 
                    conditionBranch.data[3].nodeid, 
                    graphSourceNode, 
                    hypergraph
                  )

                  local newScope = copyScope(scope)

                  hypergraph = subsequentMethodHelper(
                    conditionBranch.data[3], 
                    hypergraph, 
                    newScope, 
                    graphClassNode, 
                    newCondBranch
                  )
                end

              end

            else

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

  -- test shit
  local testQuery = hypergraph:findNodesByType("ConditionBranch")
  print("Number of found condition branches: " .. #testQuery)
  for key, item in pairs(testQuery) do
    print(item.meta.type, item.data.name, item.data.astNodeId)
  end

  return hypergraph
end



return {
  getSubsequentMethods = getSubsequentMethods
}

