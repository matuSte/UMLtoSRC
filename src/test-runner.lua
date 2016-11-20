
local luameg = require 'luameg'
local helper = require './helper'
local seq = require './seqdet'

function getFileContent(name)

  local file = assert(io.open(name, "r"))
  local textContent = file:read("*all")
  file:close()
  
  return textContent
end

local code = getFileContent("moonscript_testfile/ms-source.moon")
local ast = luameg.processText(code)

local introMethodNode = seq.find(ast, "Inventory", "new")
local methods = seq.getSubsequentMethods(ast, introMethodNode)


--helper.printTable_r(introMethodNode)

for key, value in pairs(methods) do
  print(key, value)
end

--helper.printTable_r(ast)