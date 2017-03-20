-------------------------------------------------------
-- Interface for luameg
-- @release 2017/03/16 Matúš Štefánik, Tomáš Žigo
-------------------------------------------------------

local io, table, pairs, type, print, assert, tostring = io, table, pairs, type, print, assert, tostring

local lpeg = require 'lpeg'
local moonparser  = require 'meg.parser'
local grammar = require 'leg.grammar'
local rules = require 'luameg.rules'

local AST_capt = require 'luameg.captures.AST'


local filestree = require 'luadb.extraction.filestree'
local hypergraph = require 'luadb.hypergraph'

local extractorClass = require 'luameg.extractors.extractorClass'



lpeg.setmaxstack(400)

local capture_table = {}

-- postupne nabalovanie
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
-- @param code - [string] string containing the source code to be analyzed
-- @return [table] ast for moonscript code
local function processText(code)

	local result = patt:match(code)[1]

	return result
end

----------------------------------------------------
-- Main function for source code analysis from file
-- returns an AST
-- @name proccessFile
-- @param filename - [string] file with source code
-- @return [table] ast for moonscript
local function processFile(filename)
	local file = assert(io.open(filename, "r"))
	local code = file:read("*all")
	file:close()

	return processText(code)
end

--------------------------------------
-- Get class graph from ast (one file)
-- @name getClassGraph
-- @param ast - [table] moonscript ast from luameg from which is extracted new graph or inserted new nodes and edges to graph
-- @param graph - [table] optional. Graph which is filled.
-- @return [table] graph with class nodes, methods, properties and arguments.
local function getClassGraph(ast, graph)
	local graph = graph or hypergraph.graph.new()

	return extractorClass.getGraph(ast, graph)
end

--------------------------------------
-- @name getGraphProject
-- @param dir - [string] Directory with moonscript project
-- @return [table] Return complete graph of project
local function getGraphProject(dir)

	-- vytvori sa graf so subormi a zlozkami
	local graphProject = filestree.extract(dir)

	-- vytvori sa uzol pre projekt a pripoji sa k prvemu uzlu s adresarom
	local projectNode = hypergraph.node.new()
	projectNode.data.name = "Project " .. dir   -- TODO: vyriesit ziskanie nazvu projektu
	projectNode.meta = projectNode.meta or {}
	projectNode.meta.type = "Project"
	local projectEdge = hypergraph.edge.new()
	projectEdge.label = "Contains"
	projectEdge:setSource(projectNode)
	projectEdge:setTarget(graphProject.nodes[1])
	projectEdge:setAsOriented()
	graphProject:addNode(projectNode)
	graphProject:addEdge(projectEdge)

	-- prejde sa grafom
	for i=1, #graphProject.nodes do
		local nodeFile = graphProject.nodes[i]

		-- ak je dany uzol typu subor
		if nodeFile.meta ~= nil and nodeFile.meta.type == "file" then

			-- ak je subor s koncovkou .moon
			if nodeFile.data.name:lower():match("^.+(%..+)$"):lower() == ".moon" then

				-- vytvorit AST z jedneho suboru a nasledne novy graf
				local astFile = processFile(nodeFile.data.path)

				-- ziska sa graf s triedami pre jeden subor
				local graphFileClass = getClassGraph(astFile)

				-- priradi z grafu jednotlive uzly a hrany do kompletneho vysledneho grafu
				for j=1, #graphFileClass.nodes do
					graphProject:addNode(graphFileClass.nodes[j])

					-- vytvori sa hrana "subor obsahuje triedu"
					if graphFileClass.nodes[j].meta.type == "Class" then
						local newEdge = hypergraph.edge.new()
						newEdge.label = "Contains"
						newEdge:setSource(nodeFile)
						newEdge:setTarget(graphFileClass.nodes[j])
						newEdge:setAsOriented()

						graphProject:addEdge(newEdge)
					end
				end

				-- priradia sa vsetky hrany z grafu pre triedy do kompletneho vystupneho grafu
				for j=1, #graphFileClass.edges do
					graphProject:addEdge(graphFileClass.edges[j])
				end
				
			end
		end
	end

	return graphProject
end

local a_ = 0

--------------------------
-- Generator for unique IDs
-- @name inc
-- @return [number] unique id
local function inc()
	a_ = a_ + 1
	return a_
end

---------------------------------------
-- @name convertGraphToImportGraph
-- @param graph - [table] luaDB graph from luameg
-- @return [table] graph in import format for HyperLua Lua::LuaGraph. Graph is in format
--   [{type,id,label,params}] = {[{type,id,label,direction}]={type,id,label,params}, [{type,id,label,direction}]={type,id,label,params}} 
--   or simple: [edge]={[incidence]=[node],[incidence]=[node]}
local function convertGraphToImportGraph(graph)
	local newGraph = {}

	local nodes = {}

	if graph == nil or graph.nodes == nil then
		return newGraph
	end

	-- nodes
	for k, vNode in ipairs(graph.nodes) do
		local newNode = {type="node", id=inc(), label=vNode.data.name, params={origid=vNode.id, name=vNode.data.name}}

		-- ak je to root node
		if newNode.id == 1 then 
			newNode.params.root = true 
		end

		-- doplni type uzla bud z meta.type, alebo z data.type
		if vNode.meta ~= nil and vNode.meta.type ~= nil then
			newNode.params.type = vNode.meta.type
		elseif vNode.data.type ~= nil then
			newNode.params.type = vNode.data.type
		end

		-- pre uzly file a directory sa zoberu ich cesty 
		if vNode.meta ~= nil and (vNode.meta.type:lower() == "file" or vNode.meta.type:lower() == "directory") then
			newNode.params.path = vNode.data.path
		end


		-- sem doplnit pre dalsie uzly podla potreby


		-- ulozenie uzla do zoznamu
		nodes[vNode] = newNode		
	end

	-- edges
	for k, vEdge in ipairs(graph.edges) do
		local edge = {type="edge", id=inc(), label=vEdge.label, params={origid=vEdge.id, type=vEdge.label}}

		-- incidencie
		local incid1 = {type="edge_part", id=inc(), label=''}
		local incid2 = {type="edge_part", id=inc(), label=''}

		-- nastavit orientaciu hrany
		if vEdge.orientation:lower() == "oriented" then
			incid1.direction = "in"
			incid2.direction = "out"
		end

		-- ulozenie uzlov a incidencii do zoznamu s hranou
		newGraph[edge] = {[incid1]=nodes[vEdge.from[1]], [incid2]=nodes[vEdge.to[1]]}
	end

	return newGraph
end

return {
	processText = processText,
	processFile = processFile,
	getGraphProject = getGraphProject,
	getClassGraph = getClassGraph,
	convertGraphToImportGraph = convertGraphToImportGraph
}
