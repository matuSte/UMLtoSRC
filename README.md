# UMLtoSRC

Mozno testovat so suborom _install/bin/testParser.lua:  
```lua  
print("=======STARTED==========")
  
parser = require("legmoon.parsermoon")  
  
function getFile(filename)  
  local f = assert(io.open(filename, "r"))  
  local text = f:read("*all")  
  f:close()  
  return text  
end  
  
  
local text = getFile("fileToParse.lua");


print("==========Code01================")
print(text)
print("------------RESULT-------------")
print(parser.check(text))

print("=======FINNISH===========")
```  

# Mozno uzitocne linky

Making a toy programming language in Lua, part 1  
http://www.playwithlua.com?p=66  

An introduction to Parsing Expression Grammars with LPeg  
http://leafo.net/guides/parsing-expression-grammars.html
  
Parsing Expression Grammars For Lua, version 1.0  
http://www.inf.puc-rio.br/~roberto/lpeg/  
  
MoonScript 0.5.0 - Language Guide  
http://moonscript.org/reference/  

# Vhodne IDE na testovanie
ZeroBrane Studio

```bash
wget https://download.zerobrane.com/ZeroBraneStudioEduPack-1.40-linux.sh
sudo chmod 775 ZeroBraneStudioEduPack-1.40-linux.sh
./ZeroBraneStudioEduPack-1.40-linux.sh
zbstudio   
```

Edit -> Preferences -> Settings:System  dopisat:  
*path.lua = "[absolutnaCestaDoHyperLua]/_install/bin/lua"*  

