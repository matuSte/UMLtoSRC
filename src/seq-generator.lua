function deactivationHelper(file, alreadyUsedClasses, activeMethodCalls, activeClass, actualMethodCall)

  while not (activeClass == actualMethodCall.classCalledWithin) do
  
    local lastMethodCall = activeMethodCalls[1]
    
    file:write("deactivate " .. lastMethodCall.calledTo .. "\n")
    alreadyUsedClasses[lastMethodCall.calledTo] = false
    activeClass = lastMethodCall.calledFrom
    table.remove(activeMethodCalls, 1)
  
  end

  return file, alreadyUsedClasses, activeMethodCalls, activeClass
end


function generateSequenceDiagramTxt(methodCalls, startingClass, startingMethod)

  local file = io.open("plantUml.txt", "w")
  local alreadyUsedClasses = {}
  local activeMethodCalls = {}
  local activeClass = startingClass
  
  file:write("@startuml\n")
  
  file:write("participant User\n")
  
  file:write("User -> " .. startingClass .. " : " .. startingMethod .. "\n")
  file:write("activate " .. startingClass .. "\n")
  alreadyUsedClasses[startingClass] = true
  
  for key, value in pairs(methodCalls) do
  
    if (value.structure == "method") then
    
--    we need to deactivate inactive classes
      file, alreadyUsedClasses, activeMethodCalls, activeClass = deactivationHelper(file, alreadyUsedClasses, activeMethodCalls, activeClass, value)

    
--      create new method call only if it is to another class
      if not (value.classCalledTo == value.classCalledWithin) then
        local newMethodCall = {
          calledFrom = value.classCalledWithin,
          calledTo = value.classCalledTo
        }
        table.insert(activeMethodCalls, 1, newMethodCall)
        activeClass = value.classCalledTo
      end
    
      file:write(value.classCalledWithin .. " -> " .. value.classCalledTo .. " : " .. value.name .. "\n")
      if not (alreadyUsedClasses[value.classCalledTo]) then
        file:write("activate " .. value.classCalledTo .. "\n")
        alreadyUsedClasses[value.classCalledTo] = true
      end
      
    elseif (value.structure == "condition-if") then
    
      file:write("alt " .. value.name .. "\n")
    
    elseif (value.structure == "condition-else") then
    
      file:write("else " .. value.name .. "\n")
    
    elseif (value.structure == "condition-end") or (value.structure == "loop-end") then
    
      file:write("end\n")
      
    elseif (value.structure == "loop") then
    
      file:write("loop " .. value.name .. "\n")
    
    elseif (value.structure == "return") then
    
      file:write(value.classCalledWithin .. " --> " .. value.classCalledTo .. "\n")
      file:write("deactivate " .. value.classCalledWithin .. "\n")
      alreadyUsedClasses[value.classCalledWithin] = false
    
    end
  
  end
  
  file:write("deactivate " .. startingClass .. "\n")
  
  file:write("@enduml")

  file.close()
end

function generateSequenceDiagramImage()
  os.execute("java -jar plantuml.jar -verbose plantUml.txt")
end

return {
  generateSequenceDiagramTxt = generateSequenceDiagramTxt,
  generateSequenceDiagramImage = generateSequenceDiagramImage
}