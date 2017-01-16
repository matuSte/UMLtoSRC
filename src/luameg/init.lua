local io, table, pairs, type, print, assert, tostring = io, table, pairs, type, print, assert, tostring

local lpeg = require 'lpeg'
local moonparser  = require 'meg.parser'
local grammar = require 'leg.grammar'
local rules = require 'luameg.rules'

local AST_capt = require 'luameg.captures.AST'



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
--    { ["name"]=string, ["extended"]=string, ["properties"]={}, ["methods"]={["name"]=string, ["args"]={} } }
local function getAllClasses(ast) 
	local out = {["name"]=nil, ["extended"]=nil, ["properties"]=nil, ["methods"]=nil}

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


		-- ziskanie extended class
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


-- @param classes - list of names of all classes from AST with all methods and properties
--        format: {["name"], ["extended"], ["properties"], ["methods"]}
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

return {
	processText = processText,
	getAllClasses = getAllClasses,
	isValueInTree = isValueInTree,
	getAST_treeSyntax = getAST_treeSyntax,
	getPlantUmlText = getPlantUmlText,
	getClassUmlSVG = getClassUmlSVG,
	getClassUmlSVGFromFile = getClassUmlSVGFromFile,
	getFileText = getFileText
}
