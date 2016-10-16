# UMLtoSRC

Mozno testovat so suborom _install/bin/testParser.lua:

print("=======STARTED==========")

lpeg = require("legmoon.parsermoon")
helper = require("myLua.helper")

function getFile(filename)
  local f = assert(io.open(filename, "r"))
  local text = f:read("*all")
  f:close()
  return text
end


local text = getFile("myLua/moon.lua");


print("==========Code01================")
print(text)
print("------------RESULT-------------")
print(lpeg.check(text))

print("=======FINNISH===========")

