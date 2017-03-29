--------------------------------
-- Submodule for generating plantuml template for uml class diagram and svg.
-- @release 29.03.2017 Matúš Štefánik
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
-- @param nodeName - [string] name of node for search
-- @param dataOut - [table] optional. Using in recursion. dataOut is returned.
-- @return [table] table with all collected info for class diagram from this nodeName
local function getTableFromClassNode(graph, nodeName, dataOut)
	local dataOut = dataOut or {}

	--[[ moze vratit viacero uzlov s rovnakym nazvom. Nazov triedy, nazov priecinka, suboru 
	     mozu byt rovnake
	]]
	local nodeArray = graph:findNodeByName(nodeName)

	for n=1, #nodeArray do
		if nodeArray[n].meta.type == "Class" and dataOut[nodeArray[n].data.name] == nil then

			local node = nodeArray[n]

			-- vytvorenie polozky zatial s prazdnymi udajmi
			dataOut[node.data.name] = {["extends"]=nil, ["properties"]={}, ["methods"]={}}
			
			-- najdenie vsetkych metod a clenskych premennych pre uzol class
			for i=1, #graph.edges do

				if graph.edges[i].from[1] == node then
					local nodeChild = graph.edges[i].to[1]
					if nodeChild.meta.type == "Method" then
						-- method with arguments
						table.insert(dataOut[node.data.name]["methods"], {["name"]=nodeChild.data.name, ["args"]=nodeChild.data.args})
					elseif nodeChild.meta.type == "Property" then
						-- property
						table.insert(dataOut[node.data.name]["properties"], nodeChild.data.name)
					elseif nodeChild.meta.type == "Class" and graph.edges[i].label == "Extends" then
						-- extends
						dataOut[node.data.name]["extends"] = nodeChild.data.name
						dataOut = getTableFromClassNode(graph, nodeChild.data.name, dataOut)
					end
				end
			end
		end
	end

	return dataOut
end

-------------------------------------
-- FIX: problem ak je subor s rovnakym nazvom v roznych adresaroch
--
-- @name getTableFromFileNode
-- @author Matus Stefanik
-- @param graph - [table] luaDB graph with class graph
-- @param nodeName - [string] name of node for search
-- @param dataOut - [table] optional. Using in recursion. dataOut is returned.
-- @return [table] table with all collected info for class diagram from this nodeName
local function getTableFromFileNode(graph, nodeName, outData)
	local outData = outData or {}

	local nodeArray = graph:findNodeByName(nodeName)

	for n=1, #nodeArray do
		if nodeArray[n].meta.type == "file" then

			local node = nodeArray[n]

			for i=1, #graph.edges do
				if graph.edges[i].from[1] == node then
					local nodeChild = graph.edges[i].to[1]
					if nodeChild.meta.type == "Class" and graph.edges[i].label == "Contains" then
						outData = getTableFromClassNode(graph, nodeChild.data.name, outData)
					end
				end
			end
		end
	end

	return outData
end

-----------------------------
-- FIX: problem ak je adresar s rovnakym nazvom v roznych adresaroch
-- @name getTableFromDirectoryNode
-- @author Matus Stefanik
-- @param graph - [table] luaDB graph with class graph
-- @param nodeName - [string] name of node for search
-- @param dataOut - [table] optional. Using in recusive. dataOut is returned.
-- @return [table] table with all collected info for class diagram from this nodeName
local function getTableFromDirectoryNode(graph, nodeName, outData)
	local outData = outData or {}

	local nodeArray = graph:findNodeByName(nodeName)

	for n=1, #nodeArray do
		if nodeArray[n].meta.type == "directory" then

			local node = nodeArray[n]

			for i=1, #graph.edges do
				if graph.edges[i].from[1] == node then
					local nodeChild = graph.edges[i].to[1]
					if nodeChild.meta.type == "file" and graph.edges[i].label == "Subfile" then
						outData = getTableFromFileNode(graph, nodeChild.data.name, outData)
					elseif nodeChild.meta.type == "directory" and graph.edges[i].label == "Subfile" then
						outData = getTableFromDirectoryNode(graph, nodeChild.data.name, outData)
					end
				end
			end
		end
	end

	return outData
end

--------------------------
-- @name getTableFromProjectNode
-- @author Matus Stefanik
-- @param graph - [table] luaDB graph with class graph
-- @param nodeName - [string] name of node for search
-- @param dataOut - [table] optional. Using in recursion. dataOut is returned.
-- @return [table] table with all collected info for class diagram from this nodeName
local function getTableFromProjectNode(graph, nodeName, outData)
	local outData = outData or {}

	local nodeArray = graph:findNodeByName(nodeName)

	for n=1, #nodeArray do
		if nodeArray[n].meta.type == "Project" then

			local node = nodeArray[n]

			for i=1, #graph.edges do
				if graph.edges[i].from[1] == node then
					local nodeChild = graph.edges[i].to[1]
					if nodeChild.meta.type == "file" and graph.edges[i].label == "Contains" then
						outData = getTableFromFileNode(graph, nodeChild.data.name, outData)
					elseif nodeChild.meta.type == "directory" and graph.edges[i].label == "Contains" then
						outData = getTableFromDirectoryNode(graph, nodeChild.data.name, outData)
					end
				end
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
-- @param nodeName - [string] name of node from which is needed image with class diagram
-- @return [string] Text with uml class diagram for plantUML
local function getPlantUmlFromNode(graph, nodeName)
	local nodeArray = graph:findNodeByName(nodeName)

	if nodeArray == nil or nodeArray[1] == nil then
		return "--@startuml\n@enduml"
	end

	local strOut = "@startuml\n"

	local data = nil
	local node = nodeArray[1]

	assert((node.meta ~= nil and node.meta.type ~= nil) or (node.data ~= nil and node.data.type ~= nil), 
		"Node has not defined type in meta.type or data.type. Is it correct luadb graph?")

	local nodeType = nil
	if node.meta ~= nil and node.meta.type ~= nil then
		nodeType = node.meta.type
	elseif node.data ~= nil and node.data.type ~= nil then
		nodeType = node.data.type
	end

	if nodeType == "Project" then
		data = getTableFromProjectNode(graph, node.data.name)
	elseif nodeType == "directory" then
		data = getTableFromDirectoryNode(graph, node.data.name)
	elseif nodeType == "file" then
		data = getTableFromFileNode(graph, node.data.name)
	elseif nodeType == "Class" then
		data = getTableFromClassNode(graph, node.data.name)
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
-- @param nodeName - [string] name of node from which is needed image with class diagram
-- @param pathToPlantuml - [string] (optional) path to executable plantuml.jar for generating svg.
-- @return [string] Image of Class diagram from node nodeName in SVG format as text
local function getImageFromNode(graph, nodeName, pathToPlantuml)
	local plant = getPlantUmlFromNode(graph, nodeName)
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

