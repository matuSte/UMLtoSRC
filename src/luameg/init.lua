-------------------------------------------------------
-- Interface for luameg
-- @release 2017/04/09 Matúš Štefánik, Tomáš Žigo
-------------------------------------------------------

local io, table, pairs, type, print, assert, tostring = io, table, pairs, type, print, assert, tostring

local lpeg = require 'lpeg'
local moonparser  = require 'meg.parser'
local grammar = require 'leg.grammar'
local rules = require 'luameg.rules'

local AST_capt = require 'luameg.captures.AST'


local filestree = require 'luadb.extraction.filestree'
local hypergraph = require 'luadb.hypergraph'
local moduleAstManager = require "luadb.manager.AST"

local extractorClass = require 'luameg.extractors.extractorClass'
local graphConvertor = require 'luameg.convertors.graphConvertors'



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
-- @author Matus Stefanik
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
-- @author Matus Stefanik
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
-- @author Matus Stefanik
-- @param astManager - [table] AST manager from luadb.managers.AST. Manager contains many AST with unique astId
-- @param astId - [string] id of AST in astManager from which is extracted new graph or inserted new nodes and edges to graph
-- @param graph - [table] optional. Graph which is filled.
-- @return [table] graph with class nodes, methods, properties and arguments.
local function getClassGraph(astManager, astId, graph)
	local graph = graph or hypergraph.graph.new()
	assert(astManager ~= nil, "astManager is nil.")

	return extractorClass.getGraph(astManager, astId, graph)
end

-------------------------------
-- Get complete graph from one file
-- @name getGraphFile
-- @author Matus Stefanik
-- @param path - [string] path to file
-- @param astManager - [table] (optional) AST manager from luadb.managers.AST. Manager contains many AST with unique astId.
-- @return [table] graph with class graph and sequence graph and [table] AST for this file
local function getGraphFile(path, astManager)
	assert(path ~= nil, "Path is nil")
	local ast = processFile(path)
	assert(ast ~= nil, "Ast for file is nil. Does file exist?")

	local astManager = astManager or moduleAstManager.new()

	local astRoot, astId = astManager:findASTByPath(path)

	if astRoot == nil then
		astId = astManager:addAST(ast, path)
		astRoot = ast
	end

	local graph = getClassGraph(astManager, astId, nil)

	-- doplnenie graph o sekvencny graf
	-- graph = addSequenceGraphIntoClassGraph(ast, graph)

	return graph, ast
end

--------------------------------------
-- Get complete graph from directory
-- @name getGraphProject
-- @author Matus Stefanik
-- @param dir - [string] Directory with moonscript project
-- @param astManager - [table] (optional) AST manager from luadb.managers.AST. Manager contains many AST with unique astId.
-- @return [table] Return complete graph of project and [table] ast manager with all processed AST
local function getGraphProject(dir, astManager)
	assert(dir ~= nil, "Directory path is nil")

	local astManager = astManager or moduleAstManager.new()

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
			if nodeFile.data.name:lower():match("^.+(%..+)$") == ".moon" then

				-- vytvorit AST z jedneho suboru a nasledne novy graf
				local astFile = processFile(nodeFile.data.path)
				local astId = astManager:addAST(astFile, nodeFile.data.path)

				-- uzol suboru bude obsahovat koren AST stromu
				nodeFile.data.astId = astId
				nodeFile.data.astNodeId = astFile["nodeid"]

				-- ziska sa graf s triedami pre jeden subor
				local graphFileClass = getClassGraph(astManager, astId, nil)

				-- TODO: doplnit class graf o sekvencny

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

	return graphProject, astManager
end


return {
	processText = processText,
	processFile = processFile,
	getGraphProject = getGraphProject,
	getGraphFile = getGraphFile,
	getClassGraph = getClassGraph,
	convertGraphToImportGraph = graphConvertor.convertGraphToImportGraph,
	convertHypergraphToImportGraph = graphConvertor.convertHypergraphToImportGraph
}
