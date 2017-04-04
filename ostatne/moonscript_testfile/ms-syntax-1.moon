class TestFunctionCall
	new: () =>

	customPrint: () =>
		print "something"

	parenthesses: () =>
		print "Test text 1"
		print ("Test text 2")
		@customPrint!

	getNumber: () =>
		return 7

	getNumberWithArg: (num, custom = 0) =>
		return num + 1 + custom

	assignWithFunctionCall: () =>
		a = @getNumber!
		b = @getNumber()

		c = @getNumberWithArg 6
		d = @getNumberWithArg (16)

class ObjectMethodCalls
	b: 0
	d: 0
	f: 1
	h: 1

	new: () =>

	assignExample: () =>
		testVar = TestFunctionCall!

		a = testVar.getNumber!
		@b = testVar\getNumber!

		c = testVar.getNumber()
		@d = testVar\getNumber()

		e = testVar.getNumberWithArg 6, 1
		@f = testVar\getNumberWithArg 6, 1

		g = testVar.getNumberWithArg (16)
		@h = testVar\getNumberWithArg (16)

class ConditionsTest
	ifMethod: () =>
		a = 10

		if a > 3
			b = 4
		elseif a > 7
			b = 7
		else
			b = 17

class LoopsTest
	forCycle: () =>
		k = 11
		a = 0

		for i = 0, k
			a = a + 1

		while k > 0
			print k
			k = k - 1



