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
-- @return ast for moonscript
local function processText(code)

	local result = patt:match(code)[1]

	return result
end

-- @name proccessFile
-- @param filename - file with source code
-- @return ast for moonscript
local function processFile(filename)
	local file = assert(io.open(filename, "r"))
	local code = file:read("*all")
	file:close()

	return processText(code)
end


-- get class graph from ast (one file)
-- @name getClassGraph
-- @param ast - moonscript ast from luameg from which is extracted new graph or inserted new nodes and edges to graph
-- @param graph - optional. Graph which is filled.
-- @return graph with class nodes, methods, properties and arguments.
local function getClassGraph(ast, graph)
	local graph = graph or hypergraph.graph.new()

	return extractorClass.getGraph(ast, graph)
end


-- TODO: doplnit sekvencny diagram
-- @name getGraphProject
-- @param dir - Directory with moonscript project
-- @return Return complete graph of project
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


return {
	processText = processText,
	processFile = processFile,
	getGraphProject = getGraphProject,
	getClassGraph = getClassGraph
}
