
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
      edge:setTarget(method.to[1])
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
          methodCallNode = assignModule.findMethodCall(statement.data[2])
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
          methodCallNode = assignModule.findMethodCall(statement.data[1])

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
            local conditionNode = conditionModule.findConditionNode(statement.data[1])

            if (conditionNode ~= nil) then

              local newCondNode
              hypergraph, newCondNode = conditionModule.insertCentralConditionNodeWithEdge(
                hypergraph, 
                conditionNode, 
                graphSourceNode
              )

              local newCondBranch
              hypergraph, newCondBranch = conditionModule.setupConditionBranch(
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
                  hypergraph, newCondBranch = conditionModule.setupConditionBranch(
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
                  hypergraph, newCondBranch = conditionModule.setupConditionBranch(
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

              local loopNode = loopModule.findLoopNode(statement)

              if (loopNode ~= nil) then

                local newLoopNode
                hypergraph, newLoopNode = loopModule.insertCentralLoopNodeWithEdge(
                  hypergraph, 
                  loopNode, 
                  graphSourceNode
                )

                -- let's create loop header text
                local loopConditionText
                local loopBodyNode

                if (loopNode.data[1].key == "WHILE") then
                  local loopKeyWord = loopNode.data[1].text
                  local loopCondition = loopNode.data[2].text
                  loopConditionText = loopKeyWord .. loopCondition
                  loopBodyNode = loopNode.data[3]

                  print("\tLoop construction WHILE: " .. loopConditionText)
                elseif (loopNode.data[1].key == "FOR") then
                  loopConditionText = loopModule.constructForLoopText(loopNode)
                  loopBodyNode = loopNode.data[#loopNode.data]

                  print("\tLoop construction FOR: " .. loopConditionText)
                end
                
                hypergraph = loopModule.insertHeaderNodeWithEdge(
                  hypergraph, 
                  loopConditionText, 
                  newLoopNode
                )

                -- recursive search for subsequent method calls inside loop body
                local newScope = copyScope(scope)

                hypergraph = subsequentMethodHelper(
                  loopBodyNode, 
                  hypergraph, 
                  newScope, 
                  graphClassNode, 
                  newLoopNode
                )
                -- end
              end
            end
          end
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

        hypergraph = subsequentMethodHelper(astMethodNode, hypergraph, {}, class, methodNode)

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

