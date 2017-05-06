-----------------
-- Submodule for extracting sequence diagram from AST
-- @release 09.04.2017 Tomáš Žigo
-----------------

-- imports area starts

local assignModule = require 'luameg.extractors.extractorSequenceHelpers.assignMethodCall'
local conditionModule = require 'luameg.extractors.extractorSequenceHelpers.conditionControl'
local loopModule = require 'luameg.extractors.extractorSequenceHelpers.loopControl'
local returnHandlerModule = require 'luameg.extractors.extractorSequenceHelpers.returnHandler'
local luadb = require 'luadb.hypergraph'

-- imports area ends

-- shallow iteration properties
local changeCounter = 0
local function resetChangeCounter()
  changeCounter = 0
end

local function incrementChangeCounter()
  changeCounter = changeCounter + 1
end

local function isAnotherIterationNeeded()
  if (changeCounter > 0) then
    return true
  else
    return false
  end
end
-- ends

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

local function setParameterTypes (methodNode, arguments, hypergraph, originalHypergraph)
  
  print("ITERATE ARGUMENTS")
  for key, val in pairs(arguments) do
    print(key, val)
  end

  local argumentEdges = hypergraph:findEdgesBySource(methodNode.id, "has")
  local argumentCount = 0
  for key, edge in pairs(argumentEdges) do
    local argumentNode = edge.to[1]
    if (argumentNode.meta.type == "argument") then
      print("I FOUND SUITABLE ARGUMENT - BEGINNING IDENTIFICATION")
      argumentCount = argumentCount + 1
      local typeEdges = hypergraph:findEdgesBySource(argumentNode.id, "hasType")
      print("SETTING, TYPE EDGES COUNT: ", #typeEdges)
      if ((#typeEdges == 0) and (arguments[argumentCount] ~= nil)) then
        local typeNode = luadb.node.new()
        typeNode.meta = typeNode.meta or {}
        typeNode.meta.type = "customType"
        typeNode.data.name = arguments[argumentCount]

        hypergraph:addNode(typeNode)
        originalHypergraph:addNode(typeNode)

        -- create new edge to connect method with created condition node
        local typeEdge = luadb.edge.new()
        typeEdge.label = "hasType"
        typeEdge:setSource(argumentNode)
        typeEdge:setTarget(typeNode)
        typeEdge:setAsOriented()

        hypergraph:addEdge(typeEdge)
        originalHypergraph:addEdge(typeEdge)

        print("NEW TYPE HAS BEEN ADDED: ", arguments[argumentCount])
        incrementChangeCounter()
      end
    end
  end

  return hypergraph, originalHypergraph
end

local function insertEdgeIntoHypergraph (graphSourceNode, classMethods, methodName, hypergraph, originalHypergraph, arguments)
  for key, methodEdge in pairs(classMethods) do
    local methodNode = methodEdge.to[1]
    if (methodNode.data.name == methodName) then
      local edge = luadb.edge.new()
      edge.label = "executes"
      edge:setSource(graphSourceNode)
      edge:setTarget(methodNode)
      edge:setAsOriented()
      hypergraph:addEdge(edge)

      print(edge.label, edge.from[1].data.name, edge.to[1].data.name)

      hypergraph, originalHypergraph = setParameterTypes(
        methodNode, 
        arguments, 
        hypergraph, 
        originalHypergraph
      )
      break
    end
  end

  return hypergraph, originalHypergraph
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

local function setupInitialScope(methodNode, hypergraph)
  local scope = {}

  local argumentEdges = hypergraph:findEdgesBySource(methodNode.id, "has")
  for key, edge in pairs(argumentEdges) do
    local argumentNode = edge.to[1]
    if (argumentNode.meta.type == "argument") then
      local typeEdges = hypergraph:findEdgesBySource(argumentNode.id, "hasType")
      if (#typeEdges ~= 0) then
        local typeNode = typeEdges[1].to[1]

        scope[argumentNode.data.name] = typeNode.data.name
        print("SETUP INITIAL SCOPE LOG:", argumentNode.data.name, typeNode.data.name)
      end
    end
  end

  return scope
end

local function cloneHypergraph(hypergraph)
  local newGraph = luadb.graph.new()
  for i=1, #hypergraph.nodes, 1 do
    newGraph:addNode(hypergraph.nodes[i])
  end

  for i=1, #hypergraph.edges, 1 do
    newGraph:addEdge(hypergraph.edges[i])
  end

  return newGraph
end

-- ........................................................
local function subsequentMethodHelper(methodNode, hypergraph, originalHypergraph, scope, graphClassNode, graphSourceNode)

  -- STEP 1: iterate through method node data, which contains all subsequent statements

  -- STEP 2: in every iteration distinguish two cases: assign statement and just call 
  --         statement
  local methodNodeBody = findMethodBody(methodNode)

  if (methodNodeBody == nil) then
    return hypergraph, originalHypergraph
  end

  for index, line in pairs(methodNodeBody.data) do

    for key, statement in pairs(line.data) do
      if (statement.key == 'Statement') then

        local methodCallNode, methodCallArguments

        -- test if line contains assign statement or not
        if (assignModule.isAssignStatement(statement)) then
          methodCallNode, methodCallArguments = assignModule.findMethodCall(statement.data[2])
          variableAssignedTo = assignModule.getName(statement.data[1])
          print("\tAssign Statement, variable name is: " .. variableAssignedTo)

          if (methodCallNode ~= nil) then
            local variableCalledFrom, methodName = assignModule.constructMethodNode(methodCallNode)
            local callNodes = hypergraph:findNodesByName(methodName)

            print("METHOD NAME LOG !!! " .. methodName)

            -- TODO: handle method names that are the same as class names
            if (callNodes[1].meta.type == 'class') and (variableCalledFrom == '') then
              scope[variableAssignedTo] = methodName
              print( "\tConstructor: " .. methodName)
            elseif (callNodes[1].meta.type == 'method') and (variableCalledFrom == '') then
              local classMethods = hypergraph:findEdgesBySource(graphClassNode.id, 'contains')
              local matchedArgs = assignModule.checkArgumentsAgainstScope(scope, methodCallArguments)

              hypergraph, originalHypergraph = insertEdgeIntoHypergraph(
                graphSourceNode, 
                classMethods, 
                methodName, 
                hypergraph, 
                originalHypergraph, 
                matchedArgs
              )

              print( "\tSelf method call: " .. methodName)
            elseif (callNodes[1].meta.type == 'method') and (variableCalledFrom ~= '') then
              local variableType = scope[variableCalledFrom]
              if (variableType) then
                -- TODO: handle case when class name is not found
                local classNode = hypergraph:findNodesByName(variableType)[1]
                local classMethods = hypergraph:findEdgesBySource(classNode.id, 'contains')

                print("ASSIGN FROM OBJECT: " .. classNode.id .. ", " .. classNode.data.name .. ", " .. #classMethods)
                
                local matchedArgs = assignModule.checkArgumentsAgainstScope(scope, methodCallArguments)
                hypergraph, originalHypergraph = insertEdgeIntoHypergraph(
                  graphSourceNode, 
                  classMethods, 
                  methodName, 
                  hypergraph, 
                  originalHypergraph, 
                  matchedArgs
                )
              end
              -- print( "\t" .. "Var: " .. variableCalledFrom .. " of type: " .. variableType .. ", Method: " .. methodName)
            end
            
          end
        -- not assign statement block
        else
          methodCallNode, methodCallArguments = assignModule.findMethodCall(statement.data[1])

          if (methodCallNode ~= nil) then
            local variableCalledFrom, methodName = assignModule.constructMethodNode(methodCallNode)
            print( "\tVoid Call on method: " .. methodName)

            local callNodes = hypergraph:findNodesByName(methodName)

            if (assignModule.isSystemCall(methodName)) or (#callNodes == 0) then
              print ("\tSystem call.")
            elseif (callNodes[1].meta.type == 'method') and (variableCalledFrom == '') then
              local classMethods = hypergraph:findEdgesBySource(graphClassNode.id, 'contains')
              local matchedArgs = assignModule.checkArgumentsAgainstScope(scope, methodCallArguments)

              hypergraph, originalHypergraph = insertEdgeIntoHypergraph(
                graphSourceNode, 
                classMethods, 
                methodName, 
                hypergraph, 
                originalHypergraph, 
                matchedArgs
              )

              print( "\tSelf method call: " .. methodName)
            elseif (callNodes[1].meta.type == 'method') and (variableCalledFrom ~= '') then
              local variableType = scope[variableCalledFrom]
              if (variableType) then
                -- TODO: handle case when class name is not found
                local classNode = hypergraph:findNodesByName(variableType)[1]
                local classMethods = hypergraph:findEdgesBySource(classNode.id, 'contains')
                local matchedArgs = assignModule.checkArgumentsAgainstScope(scope, methodCallArguments)

                hypergraph, originalHypergraph = insertEdgeIntoHypergraph(
                  graphSourceNode, 
                  classMethods, 
                  methodName, 
                  hypergraph, 
                  originalHypergraph, 
                  matchedArgs
                )
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

              hypergraph, originalHypergraph = subsequentMethodHelper(
                conditionNode.data[3], 
                hypergraph,
                originalHypergraph,  
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
                    newCondNode, 
                    hypergraph
                  )

                  local newScope = copyScope(scope)

                  hypergraph, originalHypergraph = subsequentMethodHelper(
                    conditionBranch.data[4], 
                    hypergraph,
                    originalHypergraph,  
                    newScope, 
                    graphClassNode, 
                    newCondBranch
                  )
                elseif (conditionBranch.key == "IfElse") then

                  local newCondBranch
                  hypergraph, newCondBranch = conditionModule.setupConditionBranch(
                    "default", 
                    conditionBranch.data[3].nodeid, 
                    newCondNode, 
                    hypergraph
                  )

                  local newScope = copyScope(scope)

                  hypergraph, originalHypergraph = subsequentMethodHelper(
                    conditionBranch.data[3], 
                    hypergraph,
                    originalHypergraph, 
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

                hypergraph, originalHypergraph = subsequentMethodHelper(
                  loopBodyNode, 
                  hypergraph,
                  originalHypergraph, 
                  newScope, 
                  graphClassNode, 
                  newLoopNode
                )
                -- end
              else

                local potentialReturnNode = statement.data[1]
                if (potentialReturnNode.key == "Return") then

                  hypergraph = returnHandlerModule.insertReturnNode(
                    hypergraph, 
                    potentialReturnNode, 
                    graphSourceNode
                  )

                end

              end
            end
          end
        end
      end
    end
  end

  return hypergraph, originalHypergraph
end



local function getSubsequentMethods(astManager, hypergraph)

  resetChangeCounter()
  incrementChangeCounter()

  local finalGraph

  while (isAnotherIterationNeeded()) do
    resetChangeCounter()
    local clonedHypergraph = cloneHypergraph(hypergraph)

    local classes = clonedHypergraph:findNodesByType('class')
    assert(astManager ~= nil, "astManager cannot be nil.")
    
    local typeNodes = hypergraph:findNodesByType("customType")
    print("TYPE NODES COUNT BEFORE: ", #typeNodes)

    for key, class in pairs(classes) do
      print("CLASS: ", class.data.name, class.meta.type, class.data.astNodeId)

      local ast = astManager:findASTByID(class.data.astId)
      assert(ast ~= nil, 'AST not found. Does there exist ast with astId:"' .. class.data.astId .. '" in astManager?')

      local classMethods = clonedHypergraph:findEdgesBySource(class.id, 'contains')
      for key, classMethod in pairs(classMethods) do

        -- print(key, classMethod.label, classMethod.to, classMethod.from)
        local methodNode = classMethod.to[1]

        for key2, val2 in pairs(methodNode) do
          print(key2, val2)
        end

        if (methodNode.meta.type == 'method') then
          print("METHOD: ", methodNode.data.name, methodNode.meta.type, methodNode.data.astNodeId)

          local scope = setupInitialScope(methodNode, clonedHypergraph)
          local astMethodNode = findAstNode(ast, methodNode.data.astNodeId)

          clonedHypergraph, hypergraph = subsequentMethodHelper(
            astMethodNode, 
            clonedHypergraph, 
            hypergraph, 
            scope, 
            class, 
            methodNode
          )

        end
        -- print('\t', methodNode.id, methodNode.data.name, methodNode.meta.type, methodNode.data.astNodeId)
      end

    end

    typeNodes = hypergraph:findNodesByType("customType")
    print("TYPE NODES COUNT AFTER: ", #typeNodes)

    print("PRINTING CHANGE COUNTER: ", changeCounter)
    finalGraph = clonedHypergraph

  end

  return finalGraph
end



return {
  getSubsequentMethods = getSubsequentMethods
}

