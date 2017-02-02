local io, table, pairs, type, print, assert, tostring = io, table, pairs, type, print, assert, tostring

local lpeg = require 'lpeg'
local moonparser  = require 'meg.parser'
local grammar = require 'leg.grammar'
local rules = require 'luameg.rules'

local AST_capt = require 'luameg.captures.AST'


local filestree = require 'luadb.extraction.filestree'
local luadb = require 'luadb.hypergraph'

local extractorClass = require 'luameg.diagrams.extractorClass'



lpeg.setmaxstack(400)

local capture_table = {}


-- zatial len obycajne skopirovanie
grammar.pipe(capture_table, AST_capt.captures)




--grammar.apply(grammar, rules, captures) 
--   `grammar`: the old grammar. It stays unmodified.
--   `rules`: optional, the new rules. 
--   `captures`: optional, the final capture table.
--  return: `rules`, suitably augmented by `grammar` and `captures`.
local lua = lpeg.P(grammar.apply(moonparser.rules, rules.rules, capture_table))


-- zabalenie do tabulky
local patt = lua / function(...)
	return {...}
end


------------------------------------------------------------------------
-- Main function for source code analysis
-- returns an AST
-- @name processText
-- @param code - string containing the source code to be analyzed
local function processText(code)

	local result = patt:match(code)[1]

	return result
end

-- @name proccessFile
-- @param filename - file with source code
-- @return ast
local function processFile(filename)
	local file = assert(io.open(filename, "r"))
	local code = file:read("*all")
	file:close()

	return processText(code)
end


local function trim(str)
	if type(str) == "string" then
		return str:gsub("^%s*(.-)%s*$", "%1")
	end

	return str
end

local function replace(str) 
	if type(str) == "string" then
		return str:gsub("\"", "'"):gsub("_", " "):gsub("\n", "\\n"):gsub("\r\n", "\\n"):gsub('%[', "("):gsub('%]', ")"):gsub('>', 'gt'):gsub('<', 'lt')
	end

	return str
end


--[[
@name getAST_treeSyntax
@param ast - AST tree in table
@param showText - optional number parameter. 
			nil or 1 - do not show element text; 2 - show only leaf text; 3 - show text from all nodes; 4 - show text from all nodes below Line node
			all texts are modified (replaced characters as [, ], >, ", etc.) and trimed
Return something like: 
   "[1 [File [Block [Line [CheckIndent ] [Statement [ExpList [Exp [Value [ChainValue [Callable [Name ] ] ] ] ] ] [Assign [ExpListLow [Exp [Value [SimpleValue ] ] ] ] ] ] ] [Line ] ] ] ]"

String put to: 
 http://www.yohasebe.com/rsyntaxtree/				-- slow, export to PNG, SVG, PDF
 http://ironcreek.net/phpsyntaxtree/				-- fast, export to PNG, SVG
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

-- get class graph from ast (one file)
local function getClassGraph(ast, graph)
	local graph = graph or luadb.graph.new()

	return extractorClass.getGraph(ast, graph)
end

-- TODO: doplnit sekvencny diagram
-- Return complete graph of project
local function getGraphProject(dir)

	-- vytvori sa graf so subormi a zlozkami
	local graphProject = filestree.extract(dir)

	-- prejde sa grafom
	for i=1, #graphProject.nodes do
		local nodeFile = graphProject.nodes[i]

		-- ak je dany uzol typu subor a ma koncovku .moon
		if nodeFile.meta.type == "file" then
			if nodeFile.data.name:match("^.+(%..+)$") == ".moon" then

				-- vytvorit AST z jedneho suboru a nasledne novy graf
				local ast = processFile(nodeFile.data.path)
				local graphFile = extractorClass.getGraph(ast)


				-- priradi z noveho grafu jednotlive uzly a hrany do kompletneho grafu
				for j=1, #graphFile.nodes do
					graphProject:addNode(graphFile.nodes[j])

					-- vytvori sa hrana "subor obsahuje triedu"
					if graphFile.nodes[j].data.type == "Class" then
						local newEdge = luadb.edge.new()
						newEdge.data.name = "Contains"
						newEdge.data.type = "Contains"
						newEdge:setSource(nodeFile)
						newEdge:setTarget(graphFile.nodes[j])

						graphProject:addEdge(newEdge)
					end
				end
				for j=1, #graphFile.edges do
					graphProject:addEdge(graphFile.edges[j])
				end
				
			end
		end
	end

	return graphProject
end

return {
	processText = processText,
	processFile = processFile,
	getAST_treeSyntax = getAST_treeSyntax,
	getGraphProject = getGraphProject,
	getClassGraph = getClassGraph,

	getClassUmlSVGFromFile = extractorClass.getClassUmlSVGFromFile	-- docasne
}
