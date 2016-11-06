local io, table, pairs, type, print, assert, tostring = io, table, pairs, type, print, assert, tostring

local lpeg = require 'lpeg'
local moonparser  = require 'meg.parser'
local grammar = require 'leg.grammar'
local rules = require 'luameg.rules'

local AST_capt = require 'luameg.captures.AST'

local helper = require("myLua/helper")
local help = require("luatree/utils/init")

-- module("luameg")




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

--[[
		-- ignore parent
		if k ~= "parent" and
           -- ignore all hypergraph cyclic stuff
           k ~= "hypergraph" and k ~= "hypergraphnode" and k ~= "nodeid_references" and
           -- ignore metrics and luaDoc stuff
           k ~= "metrics" and k ~= "luaDoc_functions" and k ~= "luaDoc_tables" and k ~= "text"
           then
]]

-- zapise do data zoznam podstromov, pre ktore boli splnene key a value
local function getChildNode(ast, key, value, data)

	for k, v in pairs(ast) do
           -- ignore parent
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

-- return list of names of all classes from AST
local function getAllClasses(ast) 
	local out = {}

	if ast == nil then
		return out
	end

	local data = {}
	getChildNode(ast, "key", "ClassDecl", data)

	for i=1, #data do
		local d = {}
		getChildNode(data[i], "key", "Assignable", d)
		if (#d > 0) then
			table.insert(out, d[1]["text"])
		end
	end

	return out
end

-- return list of names of all classes from AST with all methods and properties
local function getAllClassesWithProps(ast) 
	local out = {}

	if ast == nil then
		return out
	end

	local classDecl = {}
	getChildNode(ast, "key", "ClassDecl", classDecl)

	for i=1, #classDecl do
		local className = {}
		local classProps = {}
		local props = {}

		getChildNode(classDecl[i], "key", "Assignable", className)
		getChildNode(classDecl[i], "key", "KeyName", classProps)

		if (#className > 0) then
			for j=1, #classProps do
				print(classProps[j]["text"])
				table.insert(props, classProps[j]["text"])
			end
			table.insert(out, {className[1]["text"], props})
		end
		print()
	end

	return out
end


return {
	processText = processText,
	getAllClasses = getAllClasses,
	getAllClassesWithProps = getAllClassesWithProps
}
