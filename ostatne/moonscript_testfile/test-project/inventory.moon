class Inventory
  a: 5
  item: ""
  new: (owner) =>
    b = 4
    obj = Space!
    billCalc = BillsCalculator(price)
    taxCalc = TaxesCalculator(20)

    value = @get_value(100, 254)
    obj.calculate value, billCalc, taxCalc
    @add_item("Sweets")

  add_item: (name) =>
    @item = name
    print "added item " .. name
    temp = 2
  
  get_value: () =>
    return a + b
