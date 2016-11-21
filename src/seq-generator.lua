
function generateSequenceDiagramTxt(methodCalls, startingClass, startingMethod)

  local file = io.open("plantUml.txt", "w")
  local alreadyUsedClasses = {}
  
  file:write("@startuml\n")
  
  file:write("participant User\n")
  
  file:write("User -> " .. startingClass .. " : " .. startingMethod .. "\n")
  file:write("activate " .. startingClass .. "\n")
  alreadyUsedClasses[startingClass] = true
  
  for key, value in pairs(methodCalls) do
  
    file:write(value.classCalledWithin .. " -> " .. value.classCalledTo .. " : " .. value.name .. "\n")
    if not (alreadyUsedClasses[value.classCalledTo]) then
      file:write("activate " .. value.classCalledTo .. "\n")
      alreadyUsedClasses[value.classCalledTo] = true
    end
  
  end
  
--  file:write("deactivate " .. startingClass .. "\n")
  
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