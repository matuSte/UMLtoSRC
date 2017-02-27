
-- helper function which returns true if actual node represents assign statement
local function isAssignStatement (node)
	return (#node.data == 2) and (node.key == "Statement") and (node.data[1].key == "ExpList") and (node.data[2].key == "Assign")
end

-- 
local function isMethodWithArguments (node)
	return (#node.data == 2) and (node.data[1].key == "Callable") and (node.data[2] == "InvokeArgs")
end

-- 
local function isMethodWithoutArguments (node)
	return (#node.data == 1) and (node.data[1].key == "Chain") and (node.data[1].data[1].key == "Callable") and (node.data[1].data[2].key == "ChainItems")
end

-- 
local function isFunctionCall (node)

	if (node.key ~= "ChainValue") then
		return false
	end

	local hasArguments = isMethodWithArguments(node)
	local withoutArguments = isMethodWithoutArguments(node)

	return hasArguments or withoutArguments
end

-- 
function getName(node)

  if (node.key == "Name") or (node.key == "SelfName") then
  	return node.text
  else
  	for index, nextNode in pairs(node.data) do 
    	return getName(nextNode)
    end
  end
end

-- 
local function constructMethodNode (node)

	local newMethodNode = {
		name = "",
		type = "method",
		id = "",
		children = {}
	}

	if (isMethodWithArguments(node)) then

		newMethodNode.name = getName(node.data[1])

	elseif (isMethodWithoutArguments(node)) then

		newMethodNode.name = getName(node.data[1].data[1])

	end

	return newMethodNode
end


return {
	
	isAssignStatement = isAssignStatement,
	isFunctionCall = isFunctionCall,
	constructMethodNode = constructMethodNode

}