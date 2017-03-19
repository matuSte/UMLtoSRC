
local function isConditionBlock (node)
	return (node.key == "If")
end

return {
	isConditionBlock = isConditionBlock
}