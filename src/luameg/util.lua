
local function trim(str)
	if type(str) == "string" then
		return str:gsub("^%s*(.-)%s*$", "%1")
	end

	return str
end

-- replace some characters as ", _, \n, \r\n, [, ], <, >
local function replace(str) 
	if type(str) == "string" then
		return str:gsub("\"", "'"):gsub("_", " "):gsub("\n", "\\n"):gsub("\r\n", "\\n"):gsub('%[', "("):gsub('%]', ")"):gsub('>', 'gt'):gsub('<', 'lt')
	end

	return str
end


--[[
@name getAST_treeSyntax
@param ast - ast from luameg (moonscript)
@param showText - optional number parameter. 
			nil or 1 - do not show element text; 2 - show only leaf text; 3 - show text from all nodes; 4 - show text from all nodes below Line node
			all texts are modified (replaced characters as [, ], >, ", etc.) and trimed
@return Tree in text format
Return something like: 
   "[1 [File [Block [Line [CheckIndent ] [Statement [ExpList [Exp [Value [ChainValue [Callable [Name ] ] ] ] ] ] [Assign [ExpListLow [Exp [Value [SimpleValue ] ] ] ] ] ] ] [Line ] ] ] ]"

String put to: 
 http://ironcreek.net/phpsyntaxtree/				-- fast, export to PNG, SVG
 http://www.yohasebe.com/rsyntaxtree/				-- slow, export to PNG, SVG, PDF
 http://mshang.ca/syntree/							-- problem with big tree
]]
local function getAST_treeSyntax(ast, showText) 
	local showText = showText or 1

	local newout = ""

	if (ast == nil) then
		return ""
	end

	newout = "[" .. ast["key"]

	-- show all text
	if (showText == 3) then
		newout = newout .. ' [ "' .. replace(trim(ast["text"])) .. '"] '
	end

	-- show all text better
	if (showText == 4) then
		if ast["key"] ~= "Line" and ast["key"] ~= "Block" and ast["key"] ~= "File" 
			and ast["key"] ~= 1 and ast["key"] ~= "CHUNK" then
			newout = newout .. ' [ "' .. replace(trim(ast["text"])) .. '"] '
		end
	end

	-- show text only from leaf
	if (showText == 2 and #ast["data"] == 0) then
		newout = newout .. ' [ " ' .. replace(trim(ast["text"])).. '"] '
	end

	for i=1,#ast["data"] do
		-- show all text
		newout = newout .. " " .. getAST_treeSyntax(ast["data"][i], showText)
	end
	newout = newout .. " ]"
	
	return newout
end


return {
	getAST_treeSyntax = getAST_treeSyntax
}
