class Objekt
  new: () =>
    @some = 0

class Inventory extends Objekt
  a: 5
  new: (owner) =>
    @owner = owner

  add_item: (name) =>
    print @@__name .. "." .. @owner .. " -> added item " .. name .. ". Actual count: " .. @items[name]
    temp = 2

