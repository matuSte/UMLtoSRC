meg = require 'meg.parser'

-- get textcontent of file
function getFile(filename)
  local f = assert(io.open(filename, "r"))
  local text = f:read("*all")
  f:close()
  
  return text
end

-- print content of table recursive
function printTable_r(t)
  local print_r_cache={}
    local function sub_print_r(t,indent)
        if (print_r_cache[tostring(t)]) then
            print(indent.."*"..tostring(t))
        else
            print_r_cache[tostring(t)]=true
            if (type(t)=="table") then
                for pos,val in pairs(t) do
                    if (type(val)=="table") then
                        print(indent.."["..pos.."] => "..tostring(t).." {")
                        sub_print_r(val,indent..string.rep(" ",string.len(pos)+8))
                        print(indent..string.rep(" ",string.len(pos)+6).."}")
                    elseif (type(val)=="string") then
                        print(indent.."["..pos..'] => "'..val..'"')
                    else
                        print(indent.."["..pos.."] => "..tostring(val))
                    end
                end
            else
                print(indent..tostring(t))
            end
        end
    end
    if (type(t)=="table") then
        print(tostring(t).." {")
        sub_print_r(t,"  ")
        print("}")
    else
        sub_print_r(t,"  ")
    end
    print()
end


function check(sourceMoon)
state, strParsed, strUnparsed = meg.check_special(sourceMoon)
if state == true then
  print("true, " .. strParsed .. "/" .. #sourceMoon)
else
  if strParsed ~= nil then
    print("::::Start::::")
    print(strParsed)
    print('============================ UNPARSED =========================')
    print(strUnparsed)
    print(":::::End::::::")
    print("false, " .. #strParsed .. "/" .. #sourceMoon)
  else
    print('Result was not number. Type of result is: ' .. type(strUnparsed))
    if type(strUnparsed) == "table" then
      printTable_r(strUnparsed)
    else
      print(strUnparsed)
    end
  end
end
end

-- 

arg1 = ...

if arg1 ~= nil then     -- ak bol zadany prvy parameter - cesta k suboru
  check(getFile(arg1))
  return
end


-- ostante

print(meg.check("a = 3"))

