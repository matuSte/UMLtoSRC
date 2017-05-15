class BillsCalculator
  price: 0
  new: (n) =>
    @price = n
  calculate_price: (n) =>
    @price += n
    print @price
    return @price