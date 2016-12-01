
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

  if (node.key == "Name") then
  
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

function subsequentMethodHelper(index, subsequentMethods, variableInstances, node, fullAst, actualClass, invokedFromClass)

  local isAssign = (#node.data == 2) and (node.key == "Statement") and (node.data[1].key == "ExpList") and (node.data[2].key == "Assign")
  local isFunctionCall = false
  
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
--        subsequentMethods[index] = {
--          classCalledWithin = actualClass,
--          classCalledTo = actualClass,
--          structure = "method",
--          name = variableClass
--        }
--        index = index + 1
        
--     lets investigate also calls within found method
--        local newIntroMethod = find(fullAst, actualClass, variableClass)
--        local newIntroMethodExp = newIntroMethod.data[2]
--        TODO: variableInstances array must be cloned before nested call, due to scope issues
        index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, node.data[2], fullAst, actualClass, invokedFromClass)
        
      end
     
     end

  elseif (node.key == "Chain") and (node.data[1].key == "Callable") and (node.data[2].key == "ChainItems") then

    variableName = findNameNode(node.data[1])
    calledMethodName = node.data[2].data[1].data[1].text
    
    calledMethodNameWithoutBackslash = string.gsub(calledMethodName, "\\", "")
    
    if (variableInstances[variableName]) then
      subsequentMethods[index] = {
          classCalledWithin = actualClass,
          classCalledTo = variableInstances[variableName],
          structure = "method",
          name = calledMethodNameWithoutBackslash
        }
      index = index + 1
      
--     lets investigate also calls within found method
      local newIntroMethod = find(fullAst, variableInstances[variableName], calledMethodNameWithoutBackslash)
      local newIntroMethodExp = newIntroMethod.data[2]
      index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, newIntroMethodExp, fullAst, variableInstances[variableName], actualClass)
      
    end
    
--    TODO: implement nested method calls

  elseif (#node.data == 2) and (node.data[1].key == "Callable") and (node.data[2].key == "InvokeArgs") then
    
     subsequentMethods[index] = {
          classCalledWithin = actualClass,
          classCalledTo = actualClass,
          structure = "method",
          name = node.data[1].text
        }
     index = index + 1
     
--     lets investigate also calls within found method
    if not (node.data[1].text == "print") then
   
      local newIntroMethod = find(fullAst, actualClass, node.data[1].text)
      local newIntroMethodExp = newIntroMethod.data[2]
      index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, variableInstances, newIntroMethodExp, fullAst, actualClass, actualClass)
    
    end
    
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