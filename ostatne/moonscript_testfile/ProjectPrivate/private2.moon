class SomeClass
	x = 0   -- private
	y: 0   -- public
	print "decalred class"     -- simple statement, no member method/variable
	new: (@pubArgVar) =>  -- public method new, public variable pubArgVar
		@var = 12   -- public variable var
	priv = (arg1) =>  -- private method
		print @y .. tostring arg1
	priv2 = ->    -- private method
		print "asd"
	reveal: =>    -- public method
		z = 12
		x += 1
		print x
		priv(@, "mojArg")   -- call private method with arg self and text
		priv2()     -- cal private method without self (no access to member parts)
		@reveal2!    -- call public method
	reveal2: ->     -- public method, without self (no access to member parts)
		print("sad")
		-- print @y    -- missing @ (self)


abc = SomeClass("hodnotaPubArgVar")
print abc.pubArgVar

abc\reveal()
abc.reveal2()


a = SomeClass!
b = SomeClass!
print a.x -- nil
print a.y
print SomeClass.y
a\reveal! -- 1
b\reveal! -- 2