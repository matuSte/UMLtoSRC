local io, table, pairs, type, print, assert = io, table, pairs, type, print, assert

local lpeg = require 'lpeg'
local moonparser  = require 'meg.parser'
local grammar = require 'leg.grammar'
local rules = require 'luameg.rules'

local AST_capt = require 'luameg.captures.AST'

module("luameg")




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
-- returns an AST with included metric values in each node
-- @name processText
-- @param code - string containing the source code to be analyzed
function processText(code)

	local result = patt:match(code)[1]

	return result
end
