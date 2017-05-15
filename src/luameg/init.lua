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
local extractorSequence = require 'luameg.extractors.extractorSequence'

local graphConvertor = require 'luameg.convertors.graphConvertors'

local queueUtil = require 'luameg.utils.queue'


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

----------
-- Check source code if it is parsable.
-- @name checkText
-- @author Matus Stefanik
-- @param code - [string] moonscript source code to validate
-- @return [boolean] [string] [string] State of parsable, parsed source code and unparsed source code.
local function checkText(code)
	local isParsable, parsedCode, unparsedCode = moonparser.check_special(code)
	return isParsable, parsedCode, unparsedCode
end

------------
-- Check source code from file if it is parsable.
-- @name checkFile
-- @author Matus Stefanik
-- @param filename - [string] path to file with moonscript source code to validate
-- @return [boolean] [string] [string] State of parsable, parsed source code and unparsed source code.
local function checkFile(filename)
	local file = assert(io.open(filename, "r"))
	local code = file:read("*all")
	file:close()

	return checkText(code)
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

	local ast = astManager:findASTByID(astId)
	local listNodesEdges = extractorClass.getGraph(ast, graph.nodes)

	for k, node in pairs(listNodesEdges.nodes) do
		node.data.astID = astId
		graph:addNode(node)
	end

	for k, edge in pairs(listNodesEdges.edges) do
		graph:addEdge(edge)
	end

	return graph
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
	local pathDir, filename, filetype = string.match(path, "(.-)([^\\/]-%.?([^%.\\/]*))$")

	local astRoot, astId = astManager:findASTByPath(path)

	if astRoot == nil or astId == nil then
		astId = astManager:addAST(ast, path)
		astRoot = ast
	end


	-- vytvorenie uzla typu súbor
	local fileNode = hypergraph.node.new()
	fileNode.meta = fileNode.meta or {}
	fileNode.meta.type = "file"
	fileNode.data.name = filename
	fileNode.data.path = path
	fileNode.data.astID = astId
	fileNode.data.astNodeID = astRoot.nodeid

	-- ziskanie class graph
	local graph = getClassGraph(astManager, astId, nil)

	-- spojenie uzlu file s uzlami class
	local classNodes = graph:findNodesByType("class")
	graph:addNode(fileNode)
	for k, vNode in pairs(classNodes) do
		local edge = hypergraph.edge.new()
		edge:setAsOriented()
		edge.label = "contains"
		edge:setSource(fileNode)
		edge:setTarget(vNode)
		graph:addEdge(edge)
	end

	-- doplnenie graph o sekvencny graf
	-- graph = addSequenceGraphIntoClassGraph(ast, graph)

	return graph, ast
end

--------------------------------------
-- Adds subsequent method calls into already generated class graph. Based on this information
-- we are able to construct UML sequence diagram.
-- @name addSequenceGraphIntoClassGraph
-- @param ast - AST generated from Moonscript source code that is generated by Meg module.
-- @param graph - luadb graph that already contains classes and their methods on the first level.
-- @return mutated class graph that contains subsequent method calls.
local function addSequenceGraphIntoClassGraph(astManager, astId, graph)

	return extractorSequence.getSubsequentMethods(astManager, astId, graph)

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
	projectNode.meta.type = "project"
	local projectEdge = hypergraph.edge.new()
	projectEdge.label = "contains"
	projectEdge:setSource(projectNode)
	projectEdge:setTarget(graphProject.nodes[1])
	projectEdge:setAsOriented()
	graphProject:addNode(projectNode)
	graphProject:addEdge(projectEdge)

	local fileNodes = graphProject:findNodesByType("file")

	-- prejde sa grafom
	for i=1, #fileNodes do
		local nodeFile = fileNodes[i]

		-- ak je subor s koncovkou .moon
		if nodeFile.data.name:lower():sub(-5) == ".moon" then

			-- vytvorit AST z jedneho suboru a nasledne novy graf
			local astFile = processFile(nodeFile.data.path)
			local astId = astManager:addAST(astFile, nodeFile.data.path)

			-- uzol suboru bude obsahovat koren AST stromu
			nodeFile.data.astID = astId
			nodeFile.data.astNodeID = astFile["nodeid"]

			-- ziska sa graf s triedami pre jeden subor
			local graphFileClass = getClassGraph(astManager, astId, nil)

			-- TODO: doplnit class graf o sekvencny
			-- graphFileClass = addSequenceGraphIntoClassGraph(astManager, graphFileClass)

			-- priradi z grafu jednotlive uzly a hrany do kompletneho vysledneho grafu
			for j=1, #graphFileClass.nodes do
				graphProject:addNode(graphFileClass.nodes[j])

				-- vytvori sa hrana "subor obsahuje triedu"
				if graphFileClass.nodes[j].meta.type:lower() == "class" then
					local newEdge = hypergraph.edge.new()
					newEdge.label = "contains"
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

	graphProject = addSequenceGraphIntoClassGraph(astManager, graphProject)

	return graphProject, astManager
end

------
-- Get all child nodes and edges from 'fromNode'
-- @name getSubgraphFromNode
-- @author Matus Stefanik
-- @param graph - [table] luadb graph with oriented edges
-- @param fromNode - [table] luadb node
-- @return [table] all child nodes and child edges from node 'fromNode'. Search by oriented edge. 
-- Table looks like {["nodes"]={}, ["edges"]={}}
local function getSubgraphFromNode(graph, fromNode)
	local childNodes = {}
	local childEdges = {}

	local set = {}
	local queue = queueUtil.new()

	set[fromNode] = true
	queue:pushRight(fromNode)

	while queue:isEmpty() == false do
		local current = queue:popLeft()

		local edgesToChild = graph:findAllEdgesBySource(current.id)
		for i=1, #edgesToChild do
			local childNode = edgesToChild[i].to[1]
			table.insert(childEdges, edgesToChild[i])
			if set[childNode] == nil then
				set[childNode] = true
				queue:pushRight(childNode)
				table.insert(childNodes, childNode)
			end
		end

	end

	return {["nodes"]=childNodes, ["edges"]=childEdges}
end

-------
-- @name changeASTInFile
-- @author Matus Stefanik
-- @param graph - [table] luadb graph contains class nodes. This graph will be changed in this function.
-- @param oldAST - [table] original AST.
-- @param newAST - [table] new AST after change of source code.
-- @param fileNodeChanged - node from graph where is edited text. In this node will change data.astID and data.astNodeID.
-- @param astManager - [table] ast manager. From astManager is removed old AST and added new AST.
-- @return [table] changed luadb graph with removed old nodes and edges, and added new nodes and edges below changed file node.
local function changeASTInFile(graph, oldAST, newAST, fileNodeChanged, astManager)

	-- ziskat povodny podgraf pod zmenenym uzlom typu file
	local oldListChildNodesEdges = getSubgraphFromNode(graph, fileNodeChanged)

	-- nahradenie stareho AST za nove
	local success = astManager:removeAST(oldAST)
	local newAstId = astManager:addAST(newAST, fileNodeChanged.data.path)
	fileNodeChanged.data.astID = newAstId
	fileNodeChanged.data.astNodeID = newAST.nodeid


	-- ziskat novy luadb graf z noveho AST
	local newListNodesEdges = extractorClass.getGraph(newAST, nil)


	-- odstranenie povodnych uzlov a hran
	for k, node in pairs(oldListChildNodesEdges.nodes) do
		graph:removeNodeByID(node.id)
	end

	for k, edge in pairs(oldListChildNodesEdges.edges) do
		graph:removeEdgeByID(edge.id)
	end

	-- pridanie novych uzlov a hran do grafu
	for k, node in pairs(newListNodesEdges.nodes) do
		node.data.astID = newAstId
		graph:addNode(node)

		if node.meta.type:lower() == "class" then
			local newEdge = hypergraph.edge.new()
			newEdge:addSource(fileNodeChanged)
			newEdge:addTarget(node)
			newEdge:setAsOriented()
			newEdge.label = "contains"
			graph:addEdge(newEdge)
		end
	end

	for k, edge in pairs(newListNodesEdges.edges) do
		graph:addEdge(edge)
	end

	return graph
end


return {
	addSequenceGraphIntoClassGraph = addSequenceGraphIntoClassGraph,
	processText = processText,
	processFile = processFile,
	checkText = checkText,
	checkFile = checkFile,
	getGraphProject = getGraphProject,
	getGraphFile = getGraphFile,
	getClassGraph = getClassGraph,
	changeASTInFile = changeASTInFile,
	convertGraphToImportGraph = graphConvertor.convertGraphToImportGraph,
	convertHypergraphToImportGraph = graphConvertor.convertHypergraphToImportGraph
}
