
print, assert = print, assert

luameg = require("luameg")
helper = require("myLua/helper")


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
           -- ignore parent
        if k ~= "parent" and
           -- ignore all hypergraph cyclic stuff
           k ~= "hypergraph" and k ~= "hypergraphnode" and k ~= "nodeid_references" and
           -- ignore metrics and luaDoc stuff
           k ~= "metrics" and k ~= "luaDoc_functions" and k ~= "luaDoc_tables"
           then
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


local arg1, arg2 = ...

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
		local classes = luameg.getAllClassesWithProps(AST)
		print("Number classes: " .. #classes .. ", and type is: " .. type(classes))

		--helper.printTable_r(classes)
		for i=1, #classes do	
			for j=1, #classes[i] do
				if type(classes[i][j]) == "table" then
					for k=1, #classes[i][j] do
						print('\t"' .. tostring(classes[i][j][k]) .. '"')
					end
				else 
					print('"' .. classes[i][j] .. '"')
				end
			end
		end
	end





	return
end

print("Use arguments: First is path to file with source code (moonscript). Second is optional (number).")
--print(luameg.processText("class Account extends Acc"))
