
class TaxesCalculator
  base: 0
  new: (n) => 
    @base = n
  calculate_taxes: (n) =>
    print @base
    return @base
