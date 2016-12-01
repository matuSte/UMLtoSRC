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
  some_method: () =>
    print "hey!"


class Objekt
  new: () =>
    @some = 0

  dummy_method: () =>
  	price = 477
  	
  	billCalc = BillsCalculator(price)
  	taxCalc = TaxesCalculator(20)
  	
  	if b > 300
  	  price = billCalc\calculate_price(price)
  	  price = taxCalc\calculate_taxes(price)
  	  print price
  	elseif b > 200
  	  price = billCalc\calculate_price(price)
  	  print price
  	elseif b > 100
  	  price = taxCalc\calculate_taxes(price)
  	  taxCalc\some_method()
  	  print price
  	else
  	  print price
  	

class Inventory extends Objekt
  a: 5
  new: (owner) =>
    b = 4
    obj = Objekt!
    count = setup_val()
    obj\dummy_method()
    print ""
    add_item "Jozo"

  add_item: (name) =>
    print @@__name .. "." .. @owner .. " -> added item " .. name .. ". Actual count: " .. @items[name]
    temp = 2
    
  setup_val: () =>
  	return 2
  	

