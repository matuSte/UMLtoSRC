-- class List
class List
  list: {}

  new: (@name) =>
    print "List " .. @name .. " created"
    @list = {}
  add: (item, tag=0) =>
    table.insert(@list, item)
  printList: =>
    print table.concat(@list)

a = List("we")
a\add("One")
a\add("two")

print a.list[1], a.list[2]
a\printList!
