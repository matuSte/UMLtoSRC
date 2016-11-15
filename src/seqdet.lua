
function findClass(node, sibling, className)

  if (node.key == "CLASS") then
    
   if (sibling.text == className) then
     print(sibling.text)
     
     return node
   end
      
  end

end


function findMethod(props, methodName)

  for key, value in pairs(props) do
    
    if (value.key == "KeyValue") then
      local keyNameNode = value.data[1]
    
      print(value.key, keyNameNode.key, keyNameNode.text)
    
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

function subsequentMethodHelper(index, subsequentMethods, node)

  if (#node.data == 2) and (node.data[1].key == "Callable") and (node.data[2].key == "InvokeArgs") then
    
     subsequentMethods[index] = node.data[1].text
     index = index + 1
    
  else
    for key, value in pairs(node.data) do
  
      index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, value)
  
    end
  end
  
  return index, subsequentMethods

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

function getSubsequentMethods(introMethodNode)

  local index = 0
  local subsequentMethods = {}
  local methodExp = introMethodNode.data[2]
  
  index, subsequentMethods = subsequentMethodHelper(index, subsequentMethods, methodExp)
  
  return subsequentMethods
end

return {
  find = find,
  getSubsequentMethods = getSubsequentMethods
}