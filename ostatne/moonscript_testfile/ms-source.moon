class BillsCalculator
  price: 0
  new: (n) =>
    @price = n
  calculate_price: (n) =>
    @price += n
    print @price
    return @price
    
    
class TaxesCalculator
  base: 0
  new: (n) => 
    @base = n
  calculate_taxes: (n) =>
    print @base
    return @base


class Space
  new: () =>
    @some = 0

  calculate: (value) =>
  	price = value
  	b = 1
  	
  	billCalc = BillsCalculator(price)
  	taxCalc = TaxesCalculator(20)
  	
  	if value > 300
  	  price = billCalc\calculate_price(value)
  	  price = taxCalc\calculate_taxes(value)
  	  print price
  	else
  	  price = taxCalc\calculate_taxes(value)
  	  print price

  	while b > 0
  	  print b
  	  b -= 1
  	

class Inventory extends Space
  a: 5
  item: ""
  new: (owner) =>
    b = 4
    obj = Space!
    value = @get_value(100, 254)
    obj\calculate(value)
    @add_item("Sweets")

  add_item: (name) =>
    @item = name
    print "added item " .. name
    temp = 2
  
  get_value: () =>
    return a + b
  
  	

