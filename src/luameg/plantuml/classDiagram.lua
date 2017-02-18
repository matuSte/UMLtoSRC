local pairs = pairs


-- TODO: effective append
local function appendText(text, newText)
	return text .. newText
end


--[[
Ukazka vystupnej tabulky dataOut:
	data["Observer"]["extends"]
	data["Observer"]["properties"][i]
	data["Observer"]["methods"][i]["name"]
	data["Observer"]["methods"][i]["args"][i]

@param graph - luaDB graph with class graph
@param nodeName - name of node for search
@param dataOut - optional. Using in recursion. dataOut is returned.
@return table with all collected info for class diagram from this nodeName
]]--
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

-- FIX: problem ak je subor s rovnakym nazvom v roznych adresaroch
--
-- @param graph - luaDB graph with class graph
-- @param nodeName - name of node for search
-- @param dataOut - optional. Using in recursion. dataOut is returned.
-- @return table with all collected info for class diagram from this nodeName
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

-- FIX: problem ak je adresar s rovnakym nazvom v roznych adresaroch
--
-- @param graph - luaDB graph with class graph
-- @param nodeName - name of node for search
-- @param dataOut - optional. Using in recusive. dataOut is returned.
-- @return table with all collected info for class diagram from this nodeName
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

-- @param graph - luaDB graph with class graph
-- @param nodeName - name of node for search
-- @param dataOut - optional. Using in recursion. dataOut is returned.
-- @return table with all collected info for class diagram from this nodeName
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



---------------------------------
-- main functions to get image from node various type (class node, file node, directory node and project node)
---------------------------------
--
--



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
-- @param graph - luaDB graph with class graph
-- @param nodeName - name of node from which is needed image with class diagram
-- @return Text with uml class diagram for plantUML
local function getPlantUmlFromNode(graph, nodeName)
	local nodeArray = graph:findNodeByName(nodeName)

	if nodeArray == nil or nodeArray[1] == nil then
		return "--@startuml\n@enduml"
	end

	local strOut = "@startuml\n"

	local data = nil
	local node = nodeArray[1]

	if node.meta.type == "Project" then
		data = getTableFromProjectNode(graph, node.data.name)
	elseif node.meta.type == "directory" then
		data = getTableFromDirectoryNode(graph, node.data.name)
	elseif node.meta.type == "file" then
		data = getTableFromFileNode(graph, node.data.name)
	elseif node.meta.type == "Class" then
		data = getTableFromClassNode(graph, node.data.name)
	else
		return "@startuml\n@enduml"
	end

	local strExtends = ""

	-- z nazbieranych dat sa vytvori text pre plantuml
	for key, value in pairs(data) do
		-- TODO: pripravit text pre plantUML
		strOut = appendText(strOut, "class " .. key .. " {\n")
		for i=1, #value["properties"] do
			strOut = appendText(strOut, "\t+" .. value["properties"][i] .. "\n")
		end
		for i=1, #value["methods"] do
			strOut = appendText(strOut, "\t+" .. value["methods"][i]["name"] .. "(")
			for j=1, #value["methods"][i]["args"] do
				if j == #value["methods"][i]["args"] then
					strOut = appendText(strOut, value["methods"][i]["args"][j])
				else
					strOut = appendText(strOut, value["methods"][i]["args"][j] .. ", ")
				end
			end
			strOut = appendText(strOut, ")\n")
		end
		strOut = appendText(strOut, "}\n")

		if value["extends"] ~= nil then
			strExtends = appendText(strExtends, value["extends"] .. " <|-- " .. key .. "\n")
		end
	end

	strOut = appendText(strOut, "\n\n" .. strExtends .. "\n")

	strOut = appendText(strOut, "@enduml\n")

	return strOut
end

-- @param graph - luaDB graph with class graph
-- @param nodeName - name of node from which is needed image with class diagram
-- @return Image of Class diagram from node nodeName in SVG format as text
local function getImageFromNode(graph, nodeName)
	local plant = getPlantUmlFromNode(graph, nodeName)

	-- vytvorenie docasneho suboru s plantUML textom
	local file = io.open("_uml.txt", "w")
	file:write(plant) 	-- zapis do txt suboru
	file:close()

	-- spustenie plantuml aplikacie s vytvorenym suborom na vstupe
	os.execute("java -jar plantuml.jar -quiet -tsvg _uml.txt")

	-- plantUML vytvori novy subor s obrazkom. Precita sa a ulozi sa text do premennej
	file = io.open("_uml.svg", "r")
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

