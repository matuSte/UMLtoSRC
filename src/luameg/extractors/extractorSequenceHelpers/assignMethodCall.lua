
-- helper function which returns true if actual node represents assign statement
local function isAssignStatement (node)
	return (#node.data == 2) and (node.key == "Statement") and (node.data[1].key == "ExpList") and (node.data[2].key == "Assign")
end

-- 
local function isMethodWithArguments (node)
	return (#node.data == 2) and (node.data[1].key == "Callable") and (node.data[2].key == "InvokeArgs")
end

-- 
local function isMethodWithoutArguments (node)
	return (#node.data == 1) and (node.data[1].key == "Chain") and (node.data[1].data[1].key == "Callable") and (node.data[1].data[2].key == "ChainItems")
end

-- 
local function isObjectMethodWithArguments (node)
	return (#node.data == 2) and (#node.data[1].data == 2) and (node.data[1].key == "Chain") and (node.data[2].key == "InvokeArgs") and (node.data[1].data[1].key == "Callable") and (node.data[1].data[2].key == "ChainItems")
end

--
-- local function binaryOperatorCall (node)
-- 	return (#node.data == 1) and (node.data[1].key == 'Value') and (#noda.data[1].data == 1) and (node.data[1].data[1].key == 'ChainValue') and (#node.data[1].data[1].data == 1) and (#node.data[1].data[1].data[1].data == 2)
-- end

local function isSystemCall (methodName)
	local systemMethods = {
		print = 0
	}
	local index = systemMethods[methodName] or -1

	return (index ~= -1)
end

-- 
local function isFunctionCall (node)

	if (node.key ~= 'Exp') then
		return false
	else
		-- if (binaryOperatorCall(node) == true) then
		-- 	local hasArguments = isMethodWithArguments(node.data[3].data[1])
		-- 	local withoutArguments = isMethodWithoutArguments(node.data[3].data[1])

		-- 	return (hasArguments or withoutArguments) and (node.data[1].data[1].key == 'ChainValue')
		-- else
			local expKey = node.key
			node = node.data[1].data[1]

			local hasArguments = isMethodWithArguments(node)
			local withoutArguments = isMethodWithoutArguments(node)
			local objectMethodWithArguments = isObjectMethodWithArguments(node)

			return hasArguments or withoutArguments or objectMethodWithArguments 
		-- end
	end
end

-- 
local function findMethodCall(statement)
  local methodCall = nil

  for i, node in pairs(statement.data) do
    if (isFunctionCall(node)) then
      methodCall = node
      break
    else
      methodCall = findMethodCall(node)
    end
  end

  return methodCall
end

-- 
function getName(node)

  if (node.key == "Name") or (node.key == "SelfName") then
  	local nodeText = node.text
  	return nodeText:gsub("@", "")
  else
  	for index, nextNode in pairs(node.data) do 
    	return getName(nextNode)
    end
  end
end

-- 
local function constructMethodNode (node)

	local methodName = ""
	local varName = ""

	-- pure method call with arguments
	if (isMethodWithArguments(node.data[1].data[1])) then

		node = node.data[1].data[1]
		methodName = getName(node.data[1])

	-- method call without arguments - this case has conflicts between method call on object and
	-- pure method call
	elseif (isMethodWithoutArguments(node.data[1].data[1])) then

		node = node.data[1].data[1]
		-- newMethodNode.name = getName(node.data[1].data[1])
		local helpName = node.data[1].data[2].data[1].text
		print("-------------- " .. helpName .. " ---------------")
		if (helpName:sub(1,1) == '.') then
			varName = getName(node.data[1].data[1])
			methodName = helpName:gsub("^.", "")
		elseif (helpName:sub(1,1) == '\\') then
			varName = getName(node.data[1].data[1])
			helpName = node.data[1].data[2].data[1].data[1].text
			methodName = helpName:gsub("^\\", "")
		else
			methodName = getName(node.data[1].data[1])
		end

	-- object method call with arguments
	elseif (isObjectMethodWithArguments(node.data[1].data[1])) then

		node = node.data[1].data[1]
		varName = getName(node.data[1].data[1])
		methodName = node.data[1].data[2].text:gsub("^.", "")
		methodName = methodName:gsub("^\\", "")

	-- when method is called on object with binary operator '/' we need to consider the same
	-- cases as in pure method calls
	-- elseif (binaryOperatorCall(node)) then

	-- 	varName = getName(node.data[1].data[1])
	-- 	if (isMethodWithArguments(node.data[3].data[1])) then

	-- 		methodName = getName(node.data[3].data[1].data[1])

	-- 	elseif (isMethodWithoutArguments(node.data[3].data[1])) then

	-- 		methodName = getName(node.data[3].data[1].data[1].data[1])

	-- 	end

	end

	return varName, methodName
end


return {
	isAssignStatement = isAssignStatement,
	isFunctionCall = isFunctionCall,
	findMethodCall = findMethodCall,
	constructMethodNode = constructMethodNode,
	getName = getName,
	isSystemCall = isSystemCall
}