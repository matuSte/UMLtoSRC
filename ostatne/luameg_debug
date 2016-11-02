
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


local arg1, arg2 = ...

if arg1 ~= nil then
	src = luameg.processText(getFile(arg1))
	helper.printTable_r(src)

	return
end


print(luameg.processText("class Account extends Acc"))
