--------------------------
-- INIT luameg plantuml
-- @release 2017/04/05 Matúš Štefánik
--------------------------

local classDiagram = require "luameg.plantuml.classDiagram"

return {
	getClassPlantuml = classDiagram.getPlantUmlFromNode,
	getClassDiagramSvg = classDiagram.getImageFromNode,
	getClassJsonData = classDiagram.getJsonDataFromNode
}
