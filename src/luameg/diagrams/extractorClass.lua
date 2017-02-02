
local luadb = require 'luadb.hypergraph'

-- zapise do 'data' zoznam podstromov, pre ktore boli splnene key a value
-- @name getChildNode
-- @param ast - ast tree in table
-- @param key - which key in table must have value 'value'
-- @param value - required value from table
-- @param data - returned data. Contains all subtrees/subtables containing required value in key
local function getChildNode(ast, key, value, data)

	for k, v in pairs(ast) do
        if k ~= "parent" and k ~= "nodeid_references" and k ~= "text" then
           	if k == key and v == value then
           		table.insert(data, ast)
           	end
            if type(v) == "table" then
                getChildNode(v, key, value, data)
            end
        end
    end
end

-- @name isValueInTree
-- @param ast - AST tree in table
-- @param key - which key in table must have value 'value'
-- @param value - required value from key
-- @return true or false, and count of matches
local function isValueInTree(ast, key, value)
	local outResult = false
	local outCount = 0

	if (ast == nil) then
		return outResult, outCount
	end

	if (ast[key] == value) then
		outResult = true
		outCount = outCount + 1
	end

	for i=1, #ast["data"] do
		local result, count = isValueInTree(ast["data"][i], key, value)
		
		if result == true then
			outResult = (outResult or result)
			outCount = outCount + count
		end
	end

	return outResult, outCount
end

-- @name getAllClasses
-- @param ast - AST tree in table
-- @return list of names of all classes from AST with all methods and properties
--    { ["name"]=string, ["extends"]=string, ["properties"]={}, ["methods"]={["name"]=string, ["args"]={} } }
local function getAllClasses(ast) 
	local out = {["name"]=nil, ["extends"]=nil, ["properties"]=nil, ["methods"]=nil}

	if ast == nil then
		return out
	end

	-- ziska vsetky podstromy kde su definovane triedy (uzly ClassDecl)
	local classDeclTree = {}
	getChildNode(ast, "key", "ClassDecl", classDeclTree)

	for i=1, #classDeclTree do
		local classNameTree = {}
		local classLinesTree = {}
		local props = {}
		local methods = {}
		local extendedClass = {}
		local extendedClassTree = {}

		-- mnozina vsetkych properties v triede
		local setProps = {}

		-- v classNameTree bude meno triedy (malo by byt len jedno v danom bloku/podstromu ClassDecl)
		getChildNode(classDeclTree[i], "key", "Name", classNameTree)

		-- v classLinesTree budu podstromy vsetkych metod a properties v danom bloku/podstromu ClassDecl
		getChildNode(classDeclTree[i], "key", "KeyValue", classLinesTree)


		-- ziskanie extends class
		for qq=1, #classDeclTree[i]["data"] do
			if classDeclTree[i]["data"][qq]["key"] == "Exp" then
				getChildNode(classDeclTree[i]["data"][qq], "key", "Name", extendedClassTree)
			end
		end

		-- prevod tabulky extendedClass na string alebo nil. extendedClass by mal obsahovat iba jeden element
		if #extendedClassTree > 0 then
			extendedClass = extendedClassTree[1]["text"]
		else
			extendedClass = nil
		end

		-- ziskanie nazvu triedy. Nazov by mal byt iba jeden.
		if (#classNameTree > 0) then

			for j=1, #classLinesTree do
				
				local methodsArgsTrees2 = {}
				local methodsArgsTrees = {}
				local methodsArgs = {}

				getChildNode(classLinesTree[j], "key", "FunLit", methodsArgsTrees)

				-- ziskanie vsetkych metod
				if #methodsArgsTrees > 0 then
					getChildNode(methodsArgsTrees[1], "key", "FnArgDef", methodsArgsTrees2)
					for k=1, #methodsArgsTrees2 do
						table.insert(methodsArgs, methodsArgsTrees2[k]["data"][1]["text"])
					end

					local methodd = {}
					getChildNode(classLinesTree[j], "key", "KeyName", methodd)
					if #methodd > 0 then
						table.insert(methods, {["name"] = methodd[1]["text"], ["args"] = methodsArgs})

						--if methodd[1]["text"] == "new" then
						--	-- vsetky selfname na lavej strane od Assign v Statement, v konstruktore new()
							local stmsTree = {}
							getChildNode(classLinesTree[j], "key", "Statement", stmsTree)
							for k=1, #stmsTree do
								local selfNameTree ={}
								local expListTree ={}
								getChildNode(stmsTree[k], "key", "ExpList", expListTree)
								if #expListTree > 0 then
									getChildNode(expListTree[1], "key", "SelfName", selfNameTree)
									if #selfNameTree > 0 then
										local t = selfNameTree[1]["text"]:gsub('%W', '')
										if #t ~= 0 then
											if setProps[t] == nil or setProps[t] ~= true then
												setProps[t] = true
												table.insert(props, t)
											end
										end
									end
								end
							end

						--end
					end
				else 			
					-- ziskanie vsetkych properties
					local propss = {}
					getChildNode(classLinesTree[j], "key", "KeyName", propss)
					if #propss ~= 0 then
						local t = propss[1]["text"]:gsub('%W', '')
						if #t ~= 0 then
							if setProps[t] == nil or setProps[t] ~= true then
								setProps[t] = true
								table.insert(props, t)
							end
						end
					end
				end
			end
			
			table.insert(out, {["name"]=classNameTree[1]["text"], ["extends"]=extendedClass, ["properties"]=props, ["methods"]=methods})
		end
		
	end

	return out
end





-- @param classes - list of names of all classes from AST with all methods and properties
--        format: {["name"], ["extends"], ["properties"], ["methods"]}
local function getPlantUmlText(classes) 
	local out = "@startuml\n"
	local temp = ""

	-- plantuml template:
	--[[
		@startuml
		class [name] {
			-[propertie]
			+[method]([args])
		}

		[extends] <|-- [name]
		@enduml
	]]

	for i=1, #classes do
		out = out .. "class " .. classes[i]["name"] .. " {\n"

		for j=1, #classes[i]["properties"] or 0 do
			out = out .. "+" .. classes[i]["properties"][j] .. "\n"
		end

		for j=1, #classes[i]["methods"] do
			out = out .. "+" .. classes[i]["methods"][j]["name"] .. "("
			for k=1, #classes[i]["methods"][j]["args"] do
				if k ~= #classes[i]["methods"][j]["args"] then
					out = out .. classes[i]["methods"][j]["args"][k] .. ", "
				else 
					out = out .. classes[i]["methods"][j]["args"][k]
				end
			end
			out = out .. ")\n"
		end

		out = out .. "}\n"

		if classes[i]["extends"] ~= nil then
			temp = temp .. classes[i]["extends"] .. " <|-- " .. classes[i]["name"] .. "\n"
		end
	end

	out = out .. "\n" .. temp
	out = out .. "@enduml\n" 

	return out
end

-- This function need installed java, plantuml.jar and Graphviz-dot
-- @param ast - AST table with tree
-- @return Image with Class Diagram in SVG format
local function getClassUmlSVG(ast)
	local classes = getAllClasses(ast)
	local plant = getPlantUmlText(classes)

	local file = io.open("_uml.txt", "w")
	file:write(plant) 	-- zapis do txt suboru
	file:close()

	-- os.execute("pwd")
	os.execute("java -jar plantuml.jar -quiet -tsvg _uml.txt")

	file = io.open("_uml.svg", "r")
	local text = file:read("*all") 	-- precitanie svg
  	file:close()
  	
  	os.remove("_uml.txt")
  	os.remove("_uml.svg")
  	
  	return text
end

local function getFileText(filename)
	local f = assert(io.open(filename, "r"))
	local text = f:read("*all")
	f:close()

	return text
end

local function getClassUmlSVGFromFile(filename)
	local text = getFileText(filename)
	local ast = processText(text)
	return getClassUmlSVG(ast)
end

-- vrati vsetky nodes z tohto ast (patria do jedneho suboru (AST))
local function getGraph(ast, graph)
	local graph = graph or luadb.graph.new()

	local classes = getAllClasses(ast)

	for i=1, #classes do
		local className = classes[i]["name"]
		local nodeClass = graph:findNodeByName(className)
		if #nodeClass == 0 then
			nodeClass = luadb.node.new()
			nodeClass.data.type = "Class"
			nodeClass.data.name = className

			graph:addNode(nodeClass)
		else
			nodeClass = nodeClass[1]	-- zoberiem len prvy vyskyt (nemalo by byt viacj tried s rovnakym nazvom)
		end
		
		-- extends
		if classes[i]["extends"] ~= nil then
			local nodeExtended = graph:findNodeByName(classes[i]["extends"]) 
			if #nodeExtended == 0 then
				nodeExtended = luadb.nodeClass.new()
				nodeExtended.data.type = "Class"
				nodeExtended.data.name = classes[i]["extends"]
				graph:addNode(nodeExtended)
			else 
				nodeExtended = nodeExtended[1]		-- zoberiem len prvy vyskyt
			end

			local edge = luadb.edge.new()
			edge.data.type = "Extends"
			edge.data.name = "Extends"
			edge:setSource(nodeClass)
			edge:setTarget(nodeExtended)

			graph:addEdge(edge)
		end
		
		-- methods
		for j=1, #classes[i]["methods"] do
			local nodeMethod = luadb.node.new()
			nodeMethod.data.type = "Method"
			nodeMethod.data.name = classes[i]["methods"][j]["name"]
			nodeMethod.data.args = classes[i]["methods"][j]["args"]

			local edge = luadb.edge.new()
			edge.data.type = "Contains"
			edge.data.name = "Contains"
			edge:setSource(nodeClass)
			edge:setTarget(nodeMethod)

			graph:addEdge(edge)
			graph:addNode(nodeMethod)
		end

		-- properties
		for j=1, #classes[i]["properties"] do
			local nodeProp = luadb.node.new()
			nodeProp.data.type = "Property"
			nodeProp.data.name = classes[i]["properties"][j]

			local edge = luadb.edge.new()
			edge.data.type = "Contains"
			edge.data.name = "Contains"
			edge:setSource(nodeClass)
			edge:setTarget(nodeProp)

			graph:addEdge(edge)
			graph:addNode(nodeProp)
		end

		
	end

	return graph
end



return {
	getAllClasses = getAllClasses,
	isValueInTree = isValueInTree,
	getPlantUmlText = getPlantUmlText,
	getClassUmlSVG = getClassUmlSVG,
	getClassUmlSVGFromFile = getClassUmlSVGFromFile,
	getFileText = getFileText,

	getGraph = getGraph
}
