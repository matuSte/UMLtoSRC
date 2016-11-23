
print, assert = print, assert

luameg = require("luameg")
helper = require("helper")


-- get textcontent of file
local function getFile(filename)
  local f = assert(io.open(filename, "r"))
  local text = f:read("*all")
  f:close()
  
  return text
end

-- prevzate z luatree.utils.init a mierne upravene - pridane uvodzovky
local function print_tree(t, keychain)
    keychain = keychain or ""

    for k, v in pairs(t) do
        if k ~= "parent" and k ~= "nodeid_references" then
            if type(v) == "table" then
                print_tree(v, keychain .. "[" .. tostring(k) .. "]")
            else
                print(keychain .. "[" .. tostring(k) .. "] " .. "'" .. tostring(v) .. "'")
            end
        end
    end
end

local function getChildNode(ast, key, value, data)

	for k, v in pairs(ast) do
           -- ignore parent
        if k ~= "parent" and
           -- ignore all hypergraph cyclic stuff
           k ~= "hypergraph" and k ~= "hypergraphnode" and k ~= "nodeid_references" and
           -- ignore metrics and luaDoc stuff
           k ~= "metrics" and k ~= "luaDoc_functions" and k ~= "luaDoc_tables" and k ~= "text"
           then
           
           	if k == key and v == value then
           		table.insert(data, ast)
           	end
            if type(v) == "table" then
                getChildNode(v, key, value, data)
            end
        end
    end
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
			nil or 1 - do not show text; 2 - show only leaf text; 3 - show all text; 4 - show all text below Line node
			all texts are modified (replaced characters as [, ], >, ", etc.) and trimed
Return something like: 
   "[1 [File [Block [Line [CheckIndent ] [Statement [ExpList [Exp [Value [ChainValue [Callable [Name ] ] ] ] ] ] [Assign [ExpListLow [Exp [Value [SimpleValue ] ] ] ] ] ] ] [Line ] ] ] ]"

String put to: 
 http://www.yohasebe.com/rsyntaxtree/				-- slow, export to PNG, SVG, PDF
 http://ironcreek.net/phpsyntaxtree/				-- fast, export to PNG, SVG
 http://mshang.ca/syntree/						-- problem with big tree
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
		if ast["key"] ~= "Line" and ast["key"] ~= "Block" and ast["key"] ~= "File" and ast["key"] ~= 1 then
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


local arg1, arg2, arg3 = ...

if arg1 ~= nil then
	local AST = luameg.processText(getFile(arg1))

	if arg2 == "1" or arg2 == nil then
 		helper.printTable_r(AST)
	elseif arg2 == "2" then
		for i=1, #AST["nodeid_references"] do
			print(i .. ".")
			helper.printTable(AST["nodeid_references"][i])
			print()
		end
		--print(luameg.getAllClasses(AST))
	elseif arg2 == "3" then
		print_tree(AST)
	elseif arg2 == "4" then
		local data = {}
		getChildNode(AST, "key", "ClassDecl", data)

		local data1 = {}
		for i=1, #data do
			getChildNode(data[i], "key", "KeyName", data1)
			print_tree(data1)
			print()
		end

	elseif arg2 == "5" then
		local classes = luameg.getAllClasses(AST)
		print("Number classes: " .. #classes .. ", and type is: " .. type(classes))
		print()

		for i=1, #classes do
			print("::Name:")
			print(classes[i]["name"])
			print("::Extends:")
			print(classes[i]["extends"])
			print("::Properties:")
			for j=1, #classes[i]["properties"] or 0 do
				print("\t" .. classes[i]["properties"][j])
			end
			print("::Methods:")
			for j=1, #classes[i]["methods"] do
				print("\t" .. classes[i]["methods"][j]["name"])
				print("\t::args:")
				for k=1, #classes[i]["methods"][j]["args"] do
					print("\t\t" .. classes[i]["methods"][j]["args"][k])
				end
			end
			print()
		end
	elseif arg2 == "6" then

		--[[
		--print(AST["data"][1]["data"][1]["data"][2])
		print(AST["key"])
		print(AST["data"][1]["key"])
		print(AST["data"][1]["data"][1]["key"])
		print(AST["data"][1]["data"][1]["data"][1]["key"])
		print(AST["data"][1]["data"][1]["data"][2]["key"])
		]]
		
		local t = 4
		if arg3 ~= nil then
			t = tonumber(arg3)
		end

		local oout = luameg.getAST_treeSyntax(AST, t)
		
		print(oout)

		local state, count = luameg.isValueInTree(AST, "key", "Value")
		print(tostring(state), count)
	elseif arg2 == "7" then
		local classes = luameg.getAllClasses(AST)
		local plant = luameg.getPlantUmlText(classes)
		print(plant)	-- zdrojovy plant subor

		--[[local file = io.open("uml.txt", "w")
		file:write(plant) 	-- zapis do txt suboru
		file:close()

		os.execute("java -jar plantuml.jar -quiet -tsvg uml.txt")

		file = io.open("uml.svg", "r")
		local text = file:read("*all") 	-- precitanie svg
  		file:close()
  		
  		print("SVG::::")
  		print(text)
  		]]
	elseif arg2 == "8" then
		local svgText = luameg.getClassUmlSVG(AST)
		print(":::::")
		print(svgText)
	end





	return
end

print("Use arguments: First is path to file with source code (moonscript). Second is optional (number).")
