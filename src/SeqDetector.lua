
function findClass(node, sibling, className)

  if (node.key == "CLASS") then
    
   if (sibling.text == className) then
--     print(sibling.text)
     return node
   end
   
  end

end


function findMethod(props, methodName)

  for key, value in pairs(props) do
    
    if (value.key == "KeyValue") then
      local keyNameNode = value.data[1]
    
--      print(value.key, keyNameNode.key, keyNameNode.text)
    
      if (keyNameNode.key == "KeyName") and (keyNameNode.text == methodName) then
      
        return value
      
      end
    else
    
      if (value.data) then
        local methodNode = findMethod(value.data, methodName)
        if (methodNode) then
          return methodNode
        end
      end
    
    end
    
  end

  return nil

end

function selectProperties(astData, actualKey)

  if (astData[actualKey + 2].key == "EXTENDS") then
    
    return astData[actualKey + 6]
  else 
    return astData[actualKey + 2]
  end
  
end

--find class method that will be start point for sequence diagram
function find(ast, className, methodName)
  
  for key, value in pairs(ast.data) do
    
    local classNode = findClass(value, ast.data[key + 1], className)
    
    if (classNode) then
      
--      properties array starts with index 2
      local propsArray = selectProperties(ast.data, key)  
      local methodNode = findMethod(propsArray.data, methodName)
      
      if (methodNode) then
        return methodNode
      end
      
    else
      if (value.data) then
        local result = find(value, className, methodName)
        
        if (result) then
          return result
        end
        
      end
    end

  end 
  
  return nil
  
end 

--...................................................................

function findNameNode(node)

--  print(node.text)

  if (node.key == "Name") or (node.key == "SelfName") then
  
    return node.text
    
  else
    
    for key, value in pairs(node.data) do
      
      return findNameNode(value)
      
    end
    
  end

end

function checkIsClass(ast, className)

  for key, value in pairs(ast.data) do
    
    classNode = findClass(value, ast.data[key + 1], className)
    if (classNode) then
     return true
    else
     isClass = checkIsClass(value, className)
     if (isClass) then
       return isClass
     end   
    end
    
  end

  return false

end

function findClassNameNode(node, ast)

  local name, isClass
  if (node.key == "Chain") and (node.data[1].key == "Callable") and (node.data[2].key == "ChainItems") then
    
    name = findNameNode(node.data[1])
    isClass = checkIsClass(ast, name)
    
    return isClass, name
    
  else
    
    for key, value in pairs(node.data) do
      isClass, name = findClassNameNode(value, ast)
      if (name) then
        return isClass, name
      end
    end
    
  end

end

function hasFunctionChild(node)
  if (node.key == "Chain") and (node.data[1].key == "Callable") and (node.data[2].key == "ChainItems") then

    return true
    
  else
    
    for key, value in pairs(node.data) do
      isFunction = hasFunctionChild(value)
      if (isFunction) then
        return isFunction
      end
    end
    
  end
  return false
end

function constructLoopText(node)

  local numOfNodes = #node.data
  local loopText = ""
  
  for i = 2, numOfNodes - 1 do
    loopText = loopText .. node.data[i].text
  end

  return loopText
end

function methodCall(index, subsequentMethods, variableInstances, node, fullAst, actualClass, invokedFromClass)

    local cleanMethodName = string.gsub(node.data[1].text, "@", "")
    local activatedClass
    
--    print(cleanMethodName)
    
--     lets investigate also calls within found method
    if not (cleanMethodName == "print") then
   
      activatedClass = actualClass
      subsequentMethods[index] = {
        classCalledWithin = actualClass,
        classCalledTo = actualClass,
        structure = "method",
        name = cleanMethodName
      }
      index = index + 1
   
--      print("Lets find method in class:", "." .. cleanMethodName .. ".", "." .. actualClass .. ".")
      local newIntroMethod = find(fullAst, actualClass, cleanMethodName)
--      print(newIntroMethod)
      local newIntroMethodExp = newIntroMethod.data[2]
      index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, newIntroMethodExp, fullAst, actualClass, actualClass)
      
    else
    
      activatedClass = "System"
      subsequentMethods[index] = {
        classCalledWithin = actualClass,
        classCalledTo = "System",
        structure = "method",
        name = cleanMethodName
      }
      index = index + 1
    
    end
    
    subsequentMethods[index] = {
      classCalledWithin = actualClass,
      classCalledTo = activatedClass,
      structure = "method-end",
      name = ""
    }
    index = index + 1

    return index, subsequentMethods

end


-- ........................................................
function subsequentMethodHelper(index, subsequentMethods, variableInstances, node, fullAst, actualClass, invokedFromClass)

  local isAssign = (#node.data == 2) and (node.key == "Statement") and (node.data[1].key == "ExpList") and (node.data[2].key == "Assign")
  local isFunctionCall = false
  
--  print(node.key)
  
  if (isAssign) then
    isFunctionCall = hasFunctionChild(node.data[2])
  else
    isFunctionCall = false
  end

-- TODO: solve assigning value returned from method call on some Object
  if isAssign and isFunctionCall then

     variableName = findNameNode(node.data[1])
     isClass, variableClass = findClassNameNode(node.data[2], fullAst)
     
     if (variableName) and (variableClass) then
     
      if (isClass) then
        variableInstances[variableName] = variableClass
      else
        
--     lets investigate also calls within found method
        local cleanMethodName = string.gsub(variableClass, "@", "")
        local newIntroMethod = find(fullAst, actualClass, cleanMethodName)
--        local newIntroMethodExp = newIntroMethod.data[2]
        
--        TODO: variableInstances array must be cloned before nested call, due to scope issues
        if (newIntroMethod) then
          local newIntroMethodExp = newIntroMethod.data[2]
          subsequentMethods[index] = {
            classCalledWithin = actualClass,
            classCalledTo = actualClass,
            structure = "method",
            name = cleanMethodName
          }
          index = index + 1
          
          index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, newIntroMethodExp, fullAst, actualClass, actualClass)
        
          subsequentMethods[index] = {
            classCalledWithin = actualClass,
            classCalledTo = actualClass,
            structure = "method-end",
            name = ""
          }
          index = index + 1
        
        else
        
          index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, node.data[2], fullAst, actualClass, invokedFromClass)
        
        end
        
      end
     
     end

  elseif (node.key == "Chain") and (node.data[1].key == "Callable") and (node.data[2].key == "ChainItems") then

    local variableName = findNameNode(node.data[1])
    local calledMethodName = node.data[2].data[1].data[1].text
    
    local cleanVariableName = string.gsub(variableName, "@", "")
    local calledMethodNameWithoutBackslash = string.gsub(calledMethodName, "\\", "")
    
    local firstMethodCharacter = calledMethodNameWithoutBackslash:sub(1,1)
    
    if (firstMethodCharacter == "(") or (firstMethodCharacter == "!") then
      index, subsequentMethods = methodCall(index, subsequentMethods, variableInstances, node, fullAst, actualClass, invokedFromClass)
    else
    
--      print("Method Call on Obj", cleanVariableName, calledMethodNameWithoutBackslash)
      
      if (variableInstances[cleanVariableName]) then
        subsequentMethods[index] = {
            classCalledWithin = actualClass,
            classCalledTo = variableInstances[cleanVariableName],
            structure = "method",
            name = calledMethodNameWithoutBackslash
          }
        index = index + 1
        
  --     lets investigate also calls within found method
        local newIntroMethod = find(fullAst, variableInstances[cleanVariableName], calledMethodNameWithoutBackslash)
        local newIntroMethodExp = newIntroMethod.data[2]
        index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, newIntroMethodExp, fullAst, variableInstances[cleanVariableName], actualClass)
        
        subsequentMethods[index] = {
          classCalledWithin = actualClass,
          classCalledTo = variableInstances[cleanVariableName],
          structure = "method-end",
          name = ""
        }
        index = index + 1
      end
    
    end
    
--    TODO: implement nested method calls

  elseif (#node.data == 2) and (node.data[1].key == "Callable") and (node.data[2].key == "InvokeArgs") then
    
    index, subsequentMethods = methodCall(index, subsequentMethods, variableInstances, node, fullAst, actualClass, invokedFromClass)
    
  elseif (node.key == "If") then
  
    subsequentMethods[index] = {
        classCalledWithin = actualClass,
        classCalledTo = actualClass,
        structure = "condition-if",
        name = node.data[2].text
    }
    index = index + 1
     
    index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, node.data[3], fullAst, actualClass, invokedFromClass)
  
    for key, elseNode in pairs(node.data) do
     
      if (elseNode.key == "IfElseIf") then
      
        subsequentMethods[index] = {
            classCalledWithin = actualClass,
            classCalledTo = actualClass,
            structure = "condition-else",
            name = elseNode.data[3].text
        }
        index = index + 1
         
        index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, elseNode.data[4], fullAst, actualClass, invokedFromClass)
  
      elseif (elseNode.key == "IfElse") then
      
        subsequentMethods[index] = {
            classCalledWithin = actualClass,
            classCalledTo = actualClass,
            structure = "condition-else",
            name = "default"
        }
        index = index + 1
         
        index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, elseNode.data[3], fullAst, actualClass, invokedFromClass)
        
        subsequentMethods[index] = {
            classCalledWithin = actualClass,
            classCalledTo = actualClass,
            structure = "condition-end",
            name = ""
        }
        index = index + 1
      
      end
     
    end
  
  elseif (node.key == "For") then
  
    local loopText = constructLoopText(node)
  
    subsequentMethods[index] = {
       classCalledWithin = actualClass,
       classCalledTo = actualClass,
       structure = "loop",
       name = loopText
    }
    index = index + 1
    
--    here comes recursive call to For body
    index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, node.data[#node.data], fullAst, actualClass, invokedFromClass)
    
    subsequentMethods[index] = {
       classCalledWithin = actualClass,
       classCalledTo = actualClass,
       structure = "loop-end",
       name = ""
    }
    index = index + 1
  
  elseif (node.key == "While") then
  
    subsequentMethods[index] = {
       classCalledWithin = actualClass,
       classCalledTo = actualClass,
       structure = "loop",
       name = node.data[2].text
    }
    index = index + 1
    
--    here comes recursive call to While body
    index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, node.data[3], fullAst, actualClass, invokedFromClass)
    
    subsequentMethods[index] = {
       classCalledWithin = actualClass,
       classCalledTo = actualClass,
       structure = "loop-end",
       name = ""
    }
    index = index + 1
  
  elseif (node.key == "Return") then
  
    subsequentMethods[index] = {
       classCalledWithin = actualClass,
       classCalledTo = invokedFromClass,
       structure = "return",
       name = ""
    }
    index = index + 1
  
  else
    for key, value in pairs(node.data) do
  
      index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, value, fullAst, actualClass, invokedFromClass)
  
    end
  end
  
  return index, subsequentMethods

end



function getSubsequentMethods(ast, introMethodNode, className)

  local index = 0
  local subsequentMethods = {}
  local variableInstances = {}
  local methodExp = introMethodNode.data[2]
  
  index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, methodExp, ast, className, "")
  
--  for k, v in pairs(variableInstances) do
--    print(k, v)
--  end
  
  return subsequentMethods
end

return {
  find = find,
  getSubsequentMethods = getSubsequentMethods
}