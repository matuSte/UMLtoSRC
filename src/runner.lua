
local luameg = require 'luameg'
local helper = require './helper'
local seq = require './SeqDetector'
local generator = require './SeqGenerator'

function getFileContent(name)

  local file = assert(io.open(name, "r"))
  local textContent = file:read("*all")
  file:close()
  
  return textContent
end

local code = getFileContent("moonscript_testfile/ms-source.moon")
local ast = luameg.processText(code)

local desiredClass = "Inventory"
local desiredMethod = "new"
local introMethodNode = seq.find(ast, desiredClass, desiredMethod)
local methods = seq.getSubsequentMethods(ast, introMethodNode, desiredClass)

generator.generateSequenceDiagramTxt(methods, desiredClass, desiredMethod)
generator.generateSequenceDiagramImage()

--helper.printTable_r(introMethodNode)

for index, call in pairs(methods) do
  for key, value in pairs(call) do
    print(index, key, value)
  end
  print("\n")
end


--helper.printTable_r(ast)