class Space
  new: () =>
    @some = 0

  calculate: (value, billCalc, taxCalc) =>
  	price = value
  	b = 1
  	
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
      