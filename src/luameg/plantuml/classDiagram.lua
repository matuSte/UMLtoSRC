--------------------------------
-- Submodule for generating plantuml template for uml class diagram and svg.
-- @release 03.04.2017 Matúš Štefánik
--------------------------------

local pairs = pairs

---------------------------------------
-- Pomocna funkcia na extrahovanie potrebnych 
-- hodnot ako nazov triedy, metody, clenske premenne, 
-- nazov rodica apod z uzlu typu trieda
--
-- Ukazka vystupnej tabulky dataOut:
--	data["Observer"]["extends"]
--	data["Observer"]["properties"][i]
--	data["Observer"]["methods"][i]["name"]
--	data["Observer"]["methods"][i]["args"][i]
--
-- @name getTableFromCLassNode
-- @author Matus Stefanik
-- @param graph - [table] luaDB graph with class graph
-- @param nodeId - [string] id of node for search
-- @param dataOut - [table] optional. Using in recursion. dataOut is returned.
-- @return [table] table with all collected info for class diagram from this nodeId
local function getTableFromClassNode(graph, nodeId, dataOut)
	local dataOut = dataOut or {}

	assert(graph ~= nil, "Graph is nil")
	assert(type(graph) == "table" and graph.nodes ~= nil and graph.edges ~= nil, "Problem with graph. Is it luadb graph?")
	assert(nodeId ~= nil and type(nodeId) == "string", "Problem with nodeId. Is it string?")

	local node = graph:findNodeByID(nodeId)
	assert(node ~= nil, "Node with id \"" .. nodeId .. "\" is nil. Is it correct id?")

	-- pozadovany uzol musi byt typu Class
	if node.meta.type:lower() == "class" and dataOut[node.data.name] == nil then

		-- vytvorenie polozky zatial s prazdnymi udajmi
		dataOut[node.data.name] = {["extends"]=nil, ["properties"]={}, ["methods"]={}}

		-- najdenie vsetkych metod a clenskych premennych pre uzol class
		local edges_MethodsProperties = graph:findEdgesBySource(node.id, "Contains")
		for i=1, #edges_MethodsProperties do
			local nodeChild = edges_MethodsProperties[i].to[1]
			if nodeChild.meta.type:lower() == "method" then
				-- method with arguments
				local argsList = {}

				local edges_argument = graph:findEdgesBySource(nodeChild.id, "Has")
				for j=1, #edges_argument do
					local nodeArgument = edges_argument[j].to[1]
					if nodeArgument.meta.type:lower() == "argument" then
						table.insert(argsList, nodeArgument.data.name)
					end
				end
				table.insert(dataOut[node.data.name]["methods"], {["name"]=nodeChild.data.name, ["args"]=argsList})
			elseif nodeChild.meta.type:lower() == "property" then
				-- property
				table.insert(dataOut[node.data.name]["properties"], nodeChild.data.name)
			end
		end

		-- najdenie vsetkych rodicovskych tried
		local edges_Class = graph:findEdgesBySource(node.id, "Extends")
		for i=1, #edges_Class do
			local nodeChild = edges_Class[i].to[1]
			if nodeChild.meta.type:lower() == "class" then
				-- extends
				dataOut[node.data.name]["extends"] = nodeChild.data.name
				dataOut = getTableFromClassNode(graph, nodeChild.id, dataOut)
			end
		end
	end

	return dataOut
end

-------------------------------------
-- @name getTableFromFileNode
-- @author Matus Stefanik
-- @param graph - [table] luaDB graph with class graph
-- @param nodeId - [string] id of node for search
-- @param dataOut - [table] optional. Using in recursion. dataOut is returned.
-- @return [table] table with all collected info for class diagram from this nodeId
local function getTableFromFileNode(graph, nodeId, outData)
	local outData = outData or {}

	local node = graph:findNodeByID(nodeId)
	assert(node ~= nil, "Node with id \"" .. nodeId .. "\" is nil. Is it correct id?")

	if node.meta.type:lower() == "file" then

		local edges_class = graph:findEdgesBySource(node.id, "Contains")
		for i=1, #edges_class do
			local nodeChild = edges_class[i].to[1]
			if nodeChild.meta.type:lower() == "class" then
				outData = getTableFromClassNode(graph, nodeChild.id, outData)
			end
		end
	end

	return outData
end

-----------------------------
-- @name getTableFromDirectoryNode
-- @author Matus Stefanik
-- @param graph - [table] luaDB graph with class graph
-- @param nodeId - [string] id of node for search
-- @param dataOut - [table] optional. Using in recusive. dataOut is returned.
-- @return [table] table with all collected info for class diagram from this nodeId
local function getTableFromDirectoryNode(graph, nodeId, outData)
	local outData = outData or {}

	local node = graph:findNodeByID(nodeId)
	assert(node ~= nil, "Node with id \"" .. tostring(nodeId) .. "\" is nil. Is it correct id?")

	if node.meta.type:lower() == "directory" then

		local edges_subfile = graph:findEdgesBySource(node.id, "Subfile")
		for i=1, #edges_subfile do
			local nodeChild = edges_subfile[i].to[1]
			if nodeChild.meta.type:lower() == "file" then
				outData = getTableFromFileNode(graph, nodeChild.id, outData)
			elseif nodeChild.meta.type:lower() == "directory" then
				outData = getTableFromDirectoryNode(graph, nodeChild.id, outData)
			end
		end
	end

	return outData
end

--------------------------
-- Function return all needed data from project node. It means that all 
-- data from file, directory and class nodes are collected.
-- @name getTableFromProjectNode
-- @author Matus Stefanik
-- @param graph - [table] luaDB graph with class graph
-- @param nodeId - [string] id of node for search
-- @param dataOut - [table] optional. Using in recursion. dataOut is returned.
-- @return [table] table with all collected info for class diagram from this nodeId
local function getTableFromProjectNode(graph, nodeId, outData)
	local outData = outData or {}

	local node = graph:findNodeByID(nodeId)
	assert(node ~= nil, "Node with id \"" .. nodeId .. "\" is nil. Is it correct id?")

	if node.meta.type:lower() == "project" then

		local edges_fileDir = graph:findEdgesBySource(node.id, "Contains")
		for i=1, #edges_fileDir do
			local nodeChild = edges_fileDir[i].to[1]
			if nodeChild.meta.type:lower() == "file" then
				outData = getTableFromFileNode(graph, nodeChild.id, outData)
			elseif nodeChild.meta.type:lower() == "directory" then
				outData = getTableFromDirectoryNode(graph, nodeChild.id, outData)
			end
		end
	end

	return outData
end



--------------------
-- Main functions to get plantuml template from node various type (class node, file node, directory node and project node)
-- @name getPlantUmlFromNode
-- @author Matus Stefanik
-- @param graph - [table] luaDB graph with class graph
-- @param nodeId - [string] id of node from which is needed image with class diagram
-- @return [string] Text with uml class diagram for plantUML
local function getPlantUmlFromNode(graph, nodeId)
	assert(graph ~= nil and type(graph) == "table" and graph.nodes ~= nil, "Problem with graph. Is it luadb graph?")
	local node = graph:findNodeByID(nodeId)

	if node == nil then
		return "--@startuml\n@enduml"
	end

	local strOut = "@startuml\n"

	local data = nil

	assert((node.meta ~= nil and node.meta.type ~= nil) or (node.data ~= nil and node.data.type ~= nil), 
		"Node has not defined type in meta.type or data.type. Is it correct luadb graph?")

	local nodeType = nil
	if node.meta ~= nil and node.meta.type ~= nil then
		nodeType = node.meta.type
	elseif node.data ~= nil and node.data.type ~= nil then
		nodeType = node.data.type
	end

	if nodeType:lower() == "project" then
		data = getTableFromProjectNode(graph, node.id)
	elseif nodeType:lower() == "directory" then
		data = getTableFromDirectoryNode(graph, node.id)
	elseif nodeType:lower() == "file" then
		data = getTableFromFileNode(graph, node.id)
	elseif nodeType:lower() == "class" then
		data = getTableFromClassNode(graph, node.id)
	else
		return "@startuml\n@enduml"
	end

	local strExtends = ""

	--[[
	plantuml template:

		@startuml
		class [name] {
			+[property]
			+[method]([args])
		}
		[extends] <|-- [name]
		@enduml

	]]

	-- z nazbieranych dat sa vytvori text pre plantuml
	for key, value in pairs(data) do
		-- trieda
		strOut = strOut .. "class " .. key .. " {\n"
		
		-- properties
		for i=1, #value["properties"] do
			strOut = strOut .. "\t+" .. value["properties"][i] .. "\n"
		end
		
		-- methods
		for i=1, #value["methods"] do
			strOut = strOut .. "\t+" .. value["methods"][i]["name"] .. "("

			-- arguments
			for j=1, #value["methods"][i]["args"] do
				if j == #value["methods"][i]["args"] then
					strOut = strOut .. value["methods"][i]["args"][j]
				else
					strOut = strOut .. value["methods"][i]["args"][j] .. ", "
				end
			end
			strOut = strOut .. ")\n"
		end

		-- end of class block
		strOut = strOut .. "}\n"

		-- extends
		if value["extends"] ~= nil then
			strExtends = strExtends .. value["extends"] .. " <|-- " .. key .. "\n"
		end
	end

	strOut = strOut .. "\n\n" .. strExtends .. "\n"

	strOut = strOut .. "@enduml\n"

	return strOut
end

----------------
-- Main functions to get svg image from node various type (class node, file node, directory node and project node)
-- @name getImageFromNode
-- @author Matus Stefanik
-- @param graph - [table] luaDB graph with class graph
-- @param nodeId - [string] id of node from which is needed image with class diagram
-- @param pathToPlantuml - [string] (optional) path to executable plantuml.jar for generating svg.
-- @return [string] Image of Class diagram from node nodeId in SVG format as text
local function getImageFromNode(graph, nodeId, pathToPlantuml)
	local plant = getPlantUmlFromNode(graph, nodeId)
	local pathToPlantuml = pathToPlantuml or "plantuml.jar"

	-- vytvorenie docasneho suboru s plantUML textom
	local file = assert(io.open("_uml.txt", "w"))
	file:write(plant) 	-- zapis do txt suboru
	file:close()

	-- spustenie plantuml aplikacie s vytvorenym suborom na vstupe
	os.execute("java -jar " .. pathToPlantuml .. " -quiet -tsvg _uml.txt")

	-- plantUML vytvori novy subor s obrazkom. Precita sa a ulozi sa text do premennej
	file = assert(io.open("_uml.svg", "r"))
	local text = file:read("*all") 	-- precitanie svg
  	file:close()
  	
  	-- upratanie docasnych suborov
  	os.remove("_uml.txt")
  	os.remove("_uml.svg")
  	
  	-- vrati sa text SVG
  	return text
end


return {
	getPlantUmlFromNode = getPlantUmlFromNode,
	getImageFromNode = getImageFromNode
}

