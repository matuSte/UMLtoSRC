-- $Id: parser.lua,v 1.3 2007/11/26 18:41:51 hanjos Exp $

-- basic modules
local _G     = _G
local table  = table
local string = string

-- basic functions
local error   = error
local require = require

-- imported modules
local m       = require 'lpeg'

--local scanner = require 'legmoon.scannermoon'
local grammar = require 'leg.grammar'
local Stack = require 'legmoon.data'.Stack
local util = require 'legmoon.moon_util'

local helper = require 'myLua/helper'

-- module declaration
--module 'legmoon.parsermoon'

--[[

-- Searches for the last substring in s which matches pattern
local function rfind(s, pattern, init, finish)
  init = init or #s
  finish = finish or 1
  
  for i = init, finish, -1 do
    local lfind, rfind = string.find(s, pattern, i)
    
    if lfind and rfind then
      return lfind, rfind
    end
  end
  
  return nil
end

-- Counts the number of lines (separated by *'\n'*) in `subject`.
-- Viliam Kubis (01.03.2011) - replaced use of obsolete and deprecated lpeg.Ca with new lpeg.Cf
local function lines (subject)
  local inc = function (acc,arg) return acc + 1 end
  local L = m.Cf( m.Cc(1) * (m.P'\n' + m.P(1)) ^0, inc )
  
  return L:match(subject)
end

-- a little LPeg trick to enable a limited form of left recursion
local prefix 

-- sets a prefix used to distinguish between Var and FunctionCall
local setPrefix = function (p)
  return function (_,i)
    prefix = p
    return i
  end
end

-- matches Var and FunctionCall from _PrefixExp
local matchPrefix = function (p)
  return function (_, i)
    return (prefix == p) and i
  end
end

-- throws an error if the grammar rule `rule` doesn't match
-- `desc` is there for a slightly better error message
local function CHECK(rule, desc)
  patt, desc = m.V(rule), desc or 'chunk'
  
  return patt + m.P(function (s, i)
    local line = lines(s:sub(1, i))
    local vicinity = s:sub(i-5, i+5):gsub("\n", "<EOL>")
    
    error('Malformed '..desc..' in line '..line..', near "'..vicinity..'": a "'..rule:lower()..'" is missing!', 0)
  end)

end --]]

-- this will be used a lot below
-- local S, listOf, anyOf = m.V'IGNORED', grammar.listOf, grammar.anyOf

------------------moon-------------
-- vrati pocet prvok vo v (asi)
local L = m.luversion and m.L or function(v)
  return #v
end

local keywords2 = {}

local trim
trim = function(str)
  return str:match("^%s*(.-)%s*$")
end

local White = m.S(" \t\r\n") ^ 0
local plain_space = m.S(" \t") ^ 0
local Break = m.P("\r") ^ -1 * m.P("\n")
local Stop = Break + -1
local Comment = m.P("--") * (1 - m.S("\r\n")) ^ 0 * L(Stop)
local Space = plain_space * Comment ^ -1
local SomeSpace = m.S(" \t") ^ 1 * Comment ^ -1
local SpaceBreak = Space * Break
local EmptyLine = SpaceBreak
local AlphaNum = m.R("az", "AZ", "09", "__")
local _Name = m.R("az", "AZ", "__") * AlphaNum ^ 0
local Num = m.P("0x") * m.R("09", "af", "AF") ^ 1 * (m.S("uU") ^ -1 * m.S("lL") ^ 2) ^ -1 + m.R("09") ^ 1 * (m.S("uU") ^ -1 * m.S("lL") ^ 2) + (m.R("09") ^ 1 * (m.P(".") * m.R("09") ^ 1) ^ -1 + m.P(".") * m.R("09") ^ 1) * (m.S("eE") * m.P("-") ^ -1 * m.R("09") ^ 1) ^ -1
local Shebang = m.P("#!") * m.P(1 - Stop) ^ 0

local _indent = Stack(0)
local _do_stack = Stack(0)
local state = {
  last_pos = 0
}
local check_indent
check_indent = function(str, pos, indent)
  state.last_pos = pos
  return _indent:top() == indent
end
local advance_indent
advance_indent = function(str, pos, indent)
  local top = _indent:top()
  if top ~= -1 and indent > top then
    _indent:push(indent)
    return true
  end
end
local push_indent
push_indent = function(str, pos, indent)
    _indent:push(indent)
    return true
end
local pop_indent
pop_indent = function()
  assert(_indent:pop(), "unexpected outdent")
  return true
end
local check_do
check_do = function(str, pos, do_node)
  local top = _do_stack:top()
  if top == nil or top then
    return true, do_node
  end
  return false
end
local disable_do
disable_do = function()
  _do_stack:push(false)
  return true
end
local pop_do
pop_do = function()
  assert(_do_stack:pop() ~= nil, "unexpected do pop")
  return true
end

local op
op = function(chars)
  local patt = Space * chars
  if chars:match("^%w*$") then
    keywords2[chars] = true
    patt = patt * -AlphaNum
  end
  return patt
end

local SpaceName = Space * _Name

Num = Space * (Num)

local Name = m.Cmt(SpaceName, function(str, pos, name)
    if keywords2[name] then
      return false
    end
    return true
  end)

local key
  key = function(chars)
  keywords2[chars] = true
  return Space * chars * -AlphaNum
end

local sym
sym = function(chars)
  return Space * chars
end

local symx
symx = function(chars)
  return chars
end

--m.Cmt = function(a, b)
--  return a
--end


local DisableDo = m.Cmt("", disable_do)
local PopDo = m.Cmt("", pop_do)
--local SelfName = Space * "@" * ("@" * (_Name) + _Name)
  local SelfName = Space * "@" * ("@" * (_Name + m.Cc("self.__class")) + _Name + m.Cc("self"))
--local SelfName = Space * "@" * ("@" * (_Name / util.mark("self_class") + m.Cc("self.__class")) + _Name / util.mark("self") + m.Cc("self"))
local KeyName = SelfName + Space * _Name
local VarArg = Space * m.P("...")

 rules = {
    [1] = m.V'File',
    File = Shebang ^ -1 * (m.V'Block'),
    Block = m.V'Line' * (Break ^ 1 * m.V'Line') ^ 0,
    CheckIndent = m.Cmt(util.Indent, check_indent),
    Line = (m.V'CheckIndent' * m.V'Statement' + Space * L(Stop)),
    Statement = m.V'Import' + m.V'While' + m.V'With' + m.V'For' + m.V'ForEach' + m.V'Switch' + m.V'Return' + m.V'Local' + m.V'Export' + m.V'BreakLoop' 
                + m.V'ExpList' * (m.V'Update' + m.V'Assign') ^ -1
          * Space * ((key('if') * m.V'Exp' * (key('else') * m.V'Exp') ^ -1 * Space + key('unless') * m.V'Exp' + m.V'CompInner') * Space) ^ -1,
    Body = Space ^ -1 * Break * EmptyLine ^ 0 * m.V'InBlock' + m.V'Statement',
    Advance = L(m.Cmt(util.Indent, advance_indent)),
    PushIndent = m.Cmt(util.Indent, push_indent),
    PreventIndent = m.Cmt(m.Cc(-1), push_indent),
    PopIndent = m.Cmt("", pop_indent),
    InBlock = m.V'Advance' * m.V'Block' * m.V'PopIndent',
    Local = key('local') * ((op("*") + op("^")) + m.V'NameList'),
    Import = key'import' * m.V'ImportNameList' * SpaceBreak ^ 0 * key('from') * m.V'Exp',
    ImportName = (util.sym("\\") * Name + Name),
    ImportNameList = SpaceBreak ^ 0 * m.V'ImportName' * ((SpaceBreak ^ 1 + util.sym(",") * SpaceBreak ^ 0) * m.V'ImportName') ^ 0,
    BreakLoop = key('break') + key('continue'),
    Return = key('return') * (m.V'ExpListLow'),
    WithExp = m.V'ExpList' * m.V'Assign' ^ -1 ,
    With = key('with') * DisableDo * util.ensure(m.V'WithExp', PopDo) * key('do') ^ -1 * m.V'Body',
    Switch = key('switch') * DisableDo * util.ensure(m.V'Exp', PopDo) * key('do') ^ -1 * Space ^ -1 * Break * m.V'SwitchBlock',
    SwitchBlock = EmptyLine ^ 0 * m.V'Advance' * m.V'SwitchCase' * (Break ^ 1 * m.V'SwitchCase') ^ 0 * (Break ^ 1 * m.V'SwitchElse') ^ -1 * m.V'PopIndent',
    SwitchCase = key('when') * m.V'ExpList' * key('then') ^ -1 * m.V'Body',
    SwitchElse = key('else') * m.V'Body',
    IfCond = m.V'Exp' * m.V'Assign' ^ -1,
    IfElse = (Break * EmptyLine ^ 0 * m.V'CheckIndent') ^ -1 * key('else') * m.V'Body',
    IfElseIf = (Break * EmptyLine ^ 0 * m.V'CheckIndent') ^ -1 * key('elseif') * m.V'IfCond' * key('then') ^ -1 * m.V'Body',
    If = key('if') * m.V'IfCond' * key('then') ^ -1 * m.V'Body' * m.V'IfElseIf' ^ 0 * m.V'IfElse' ^ -1,
    Unless = key('unless') * m.V'IfCond' * key('then') ^ -1 * m.V'Body' * m.V'IfElseIf' ^ 0 * m.V'IfElse' ^ -1,
    While = key('while') * DisableDo * util.ensure(m.V'Exp', PopDo) * key('do') ^ -1 * m.V'Body',
    For = key('for') * DisableDo * util.ensure(Name * util.sym("=") * m.V'Exp' * util.sym(",") * m.V'Exp' * (util.sym(",") * m.V'Exp') ^ -1, PopDo) * key('do') ^ -1 * m.V'Body',
    ForEach = key('for') * m.V'AssignableNameList' * key('in') * DisableDo * util.ensure((util.sym("*") * m.V'Exp' + m.V'ExpList'), PopDo) * key('do') ^ -1 * m.V'Body',
    Do = key('do') * m.V'Body',
    Comprehension = util.sym("[") * m.V'Exp' * m.V'CompInner' * util.sym("]"),
    TblComprehension = util.sym("{") * m.V'Exp' * (util.sym(",") * m.V'Exp') ^ -1 * m.V'CompInner' * util.sym("}"),
    CompInner = (m.V'CompForEach' + m.V'CompFor') * m.V'CompClause' ^ 0,
    CompForEach = key('for') * (m.V'AssignableNameList') * key('in') * (util.sym("*") * m.V'Exp' + m.V'Exp'),
    CompFor = key("for" * Name * util.sym("=") * (m.V'Exp' * util.sym(",") * m.V'Exp' * (util.sym(",") * m.V'Exp') ^ -1)),
    CompClause = m.V'CompFor' + m.V'CompForEach' + key('when') * m.V'Exp',
    Assign = util.sym("=") * ((m.V'With' + m.V'If' + m.V'Switch') + (m.V'TableBlock' + m.V'ExpListLow')),
    Update = ((util.sym("..=") + util.sym("+=") + util.sym("-=") + util.sym("*=") + util.sym("/=") + util.sym("%=") + util.sym("or=") + util.sym("and=") + util.sym("&=") + util.sym("|=") + util.sym(">>=") + util.sym("<<="))) * m.V'Exp',
    CharOperators = Space * m.S("+-*/%^><|&"),
    WordOperators = op("or") + op("and") + op("<=") + op(">=") + op("~=") + op("!=") + op("==") + op("..") + op("<<") + op(">>") + op("//"),
    BinaryOperator = (m.V'WordOperators' + m.V'CharOperators') * SpaceBreak ^ 0,
    Assignable = m.Cmt(m.V'Chain', util.check_assignable) + Name + SelfName,
    Exp = (m.V'Value' * (m.V'BinaryOperator' * m.V'Value') ^ 0),
    SimpleValue = m.V'If' + m.V'Unless' + m.V'Switch' + m.V'With' + m.V'ClassDecl' + m.V'ForEach' + m.V'For' + m.V'While' + m.Cmt(m.V'Do', check_do) + util.sym("-") * -SomeSpace * m.V'Exp' + util.sym("#") * m.V'Exp' + util.sym("~") * m.V'Exp' + key('not') * m.V'Exp' + m.V'TblComprehension' + m.V'TableLit' + m.V'Comprehension' + m.V'FunLit' + Num,
    ChainValue = (m.V'Chain' + m.V'Callable') * m.V'InvokeArgs' ^ -1,
    Value = m.V'SimpleValue' + m.V'KeyValueList' + m.V'ChainValue' + m.V'String',
    SliceValue = m.V'Exp',
    String = Space * m.V'DoubleString' + Space * m.V'SingleString' + m.V'LuaString',
    SingleString = util.simple_string("'"),
    DoubleString = util.simple_string('"', true),
    LuaString = m.Cg(m.V'LuaStringOpen', "string_open") * m.Cb("string_open") * Break ^ -1 * ((1 - m.Cmt(m.V'LuaStringClose' * m.Cb("string_open"), util.check_lua_string)) ^ 0) * m.V'LuaStringClose',
  --  LuaString = m.V'LuaStringOpen' * Break ^ -1 * m.C((1 - m.Cmt(m.C(m.V'LuaStringClose'), util.check_lua_string)) ^ 0) * m.V'LuaStringClose',
    LuaStringOpen = util.sym("[") * m.P("=") ^ 0 * "[",
    LuaStringClose = "]" * m.P("=") ^ 0 * "]",
    Callable = Name + SelfName + VarArg + m.V'Parens',
    Parens = util.sym("(") * SpaceBreak ^ 0 * m.V'Exp' * SpaceBreak ^ 0 * util.sym(")"),
    FnArgs = util.symx("(") * SpaceBreak ^ 0 * m.V'FnArgsExpList' ^ -1 * SpaceBreak ^ 0 * util.sym(")") + util.sym("!") * -m.P("="),
    FnArgsExpList = m.V'Exp' * ((Break + util.sym(",")) * White * m.V'Exp') ^ 0,
    Chain = (m.V'Callable' + m.V'String' + -m.S(".\\")) * m.V'ChainItems' + Space * (m.V'DotChainItem' * m.V'ChainItems' ^ -1 + m.V'ColonChain'),
    ChainItems = m.V'ChainItem' ^ 1 * m.V'ColonChain' ^ -1 + m.V'ColonChain',
    ChainItem = m.V'Invoke' + m.V'DotChainItem' + m.V'Slice' + util.symx("[") * m.V'Exp' * util.sym("]"),
    DotChainItem = util.symx(".") * _Name,
    ColonChainItem = util.symx("\\") * _Name,
    ColonChain = m.V'ColonChainItem' * (m.V'Invoke' * m.V'ChainItems' ^ -1) ^ -1,
    Slice = util.symx("[") * (m.V'SliceValue' ^-1) * util.sym(",") * (m.V'SliceValue'^-1) * (util.sym(",") * m.V'SliceValue') ^ -1 * util.sym("]"),
    Invoke = m.V'FnArgs' + m.V'SingleString' + m.V'DoubleString' + L(m.P("[")) * m.V'LuaString',
    TableValue = m.V'KeyValue' + m.V'Exp',
    TableLit = util.sym("{") * (m.V'TableValueList' ^ -1 * util.sym(",") ^ -1 * (SpaceBreak * m.V'TableLitLine' * (util.sym(",") ^ -1 * SpaceBreak * m.V'TableLitLine') ^ 0 * util.sym(",") ^ -1) ^ -1) * White * util.sym("}"),
    TableValueList = m.V'TableValue' * (util.sym(",") * m.V'TableValue') ^ 0,
    TableLitLine = m.V'PushIndent' * ((m.V'TableValueList' * m.V'PopIndent') + (m.V'PopIndent' * util.Cut)) + Space,
    TableBlockInner = m.V'KeyValueLine' * (SpaceBreak ^ 1 * m.V'KeyValueLine') ^ 0,
    TableBlock = SpaceBreak ^ 1 * m.V'Advance' * util.ensure(m.V'TableBlockInner', m.V'PopIndent') ,
    ClassDecl = key('class') * -m.P(":") * (m.V'Assignable') * (key('extends') * m.V'PreventIndent' * util.ensure(m.V'Exp', m.V'PopIndent')) ^ -1 * (m.V'ClassBlock')^-1,
    ClassBlock = SpaceBreak ^ 1 * m.V'Advance' * m.V'ClassLine' * (SpaceBreak ^ 1 * m.V'ClassLine') ^ 0 * m.V'PopIndent',
    ClassLine = m.V'CheckIndent' * ((m.V'KeyValueList' + m.V'Statement' + m.V'Exp') * util.sym(",") ^ -1),
    Export = key('export') * (m.V'ClassDecl' + op("*") + op("^") + m.V'NameList' * (util.sym("=") * m.V'ExpListLow') ^ -1),
  --KeyValue = (util.sym(":") * -SomeSpace * Name) + (KeyName + util.sym("[") * m.V'Exp' * util.sym("]") + Space * m.V'DoubleString' + Space * m.V'SingleString' * util.symx(":") * (m.V'Exp' + m.V'TableBlock' + SpaceBreak ^ 1 * m.V'Exp')),
    KeyValue = (util.sym(":") * -SomeSpace * Name) + ((KeyName + util.sym("[") * m.V'Exp' * util.sym("]") + Space * m.V'DoubleString' + Space * m.V'SingleString') * util.symx(":") * (m.V'Exp' + m.V'TableBlock' + SpaceBreak ^ 1 * m.V'Exp')),
    --KeyValue = (util.sym(":") * -SomeSpace * Name * m.Cp()) / util.self_assign + m.Ct( (KeyName + util.sym("[") * m.V'Exp' * util.sym("]") + Space * m.V'DoubleString' + Space * m.V'SingleString') * util.symx(":") * (m.V'Exp' + m.V'TableBlock' + SpaceBreak ^ 1 * m.V'Exp')),
    KeyValueList = m.V'KeyValue' * (util.sym(",") * m.V'KeyValue') ^ 0,
    KeyValueLine = m.V'CheckIndent' * m.V'KeyValueList' * util.sym(",") ^ -1,
    FnArgsDef = (util.sym("(") * White * (m.V'FnArgDefList' ^ -1) * (key('using') * (m.V'NameList' + Space * "nil"))^-1 * White * util.sym(")") )^-1,-- + m.Ct("") * m.Ct(""),
    FnArgDefList = m.V'FnArgDef' * ((util.sym(",") + Break) * White * m.V'FnArgDef') ^ 0 * ((util.sym(",") + Break) * White * VarArg) ^ 0 + VarArg,
    FnArgDef = ((Name + SelfName) * (util.sym("=") * m.V'Exp') ^ -1),
    FunLit = m.V'FnArgsDef' * (util.sym("->") + util.sym("=>")) * (m.V'Body'^-1),
    NameList = Name * (util.sym(",") * Name) ^ 0,
    NameOrDestructure = Name + m.V'TableLit',
    AssignableNameList = m.V'NameOrDestructure' * (util.sym(",") * m.V'NameOrDestructure') ^ 0,
    ExpList = m.V'Exp' * (util.sym(",") * m.V'Exp') ^ 0,
    ExpListLow = m.V'Exp' * ((util.sym(",") + util.sym(";")) * m.V'Exp') ^ 0,
    InvokeArgs = -m.P("-") * (m.V'ExpList' * (util.sym(",") * (m.V'TableBlock' + SpaceBreak * m.V'Advance' * m.V'ArgBlock' * m.V'TableBlock' ^ -1) + m.V'TableBlock') ^ -1 + m.V'TableBlock'),
    ArgBlock = m.V'ArgLine' * (util.sym(",") * SpaceBreak * m.V'ArgLine') ^ 0 * m.V'PopIndent',
    ArgLine = m.V'CheckIndent' * m.V'ExpList'
}


-- puts all the keywords and symbols to the grammar
--grammar.complete(rules, scanner.keywords)
--grammar.complete(rules, scanner.symbols)

--[[
Checks if `input` is valid Lua source code.

**Parameters:**
* `input`: a string containing Lua source code.

**Returns:**
* `true`, if `input` is valid Lua source code, or `false` and an error message if the matching fails.
--]]
function check(input)
  local builder = m.P(rules)
  local result = builder:match(input)
  
  --print("rules:")
  --helper.printTable_r(rules)
  --print("===================%")
  --print("grammar:")
  --helper.printTable_r(grammar)
  --print("==============%")
  
  if (type(result) == "table") then
    print(input)
    print("============")
    helper.printTable_r(result)
  else
    print(input:sub(1, result))
    print("\nUnparsed:\n=========\n")
    print(input:sub(result))
    print("=========")
    print("result:")
    local res = "OK" 
    if result ~= #input+1 then
      res = "ERROR"
    end
    print(result .. "/" .. #input .. " " .. res)
  end

  
  --[[ if result ~= #input + 1 then -- failure, build the error message
    local init, _ = rfind(input, '\n*', result - 1) 
    local _, finish = string.find(input, '\n*', result + 1)
    
    init = init or 0
    finish = finish or #input
    
    local line = lines(input:sub(1, result))
    local vicinity = input:sub(init + 1, finish)
    
    return false, 'Syntax error at line '..line..', near "'..vicinity..'"'
  end
  --]]
  
  return true
end

--[[
Uses [grammar.html#function_apply grammar.apply] to return a new grammar, with `captures` and extra rules. [#variable_rules rules] stays unmodified.

**Parameters:**
* `extraRules`: optional, the new and modified rules. See [grammar.html#function_apply grammar.apply] for the accepted format.
* `captures`: optional, the desired captures. See [grammar.html#function_apply grammar.apply] for the accepted format.

**Returns:**
* the extended grammar.
--]]
function apply(extraRules, captures)
  return grammar.apply(rules, extraRules, captures)
end



-- ./lua parsermoon.lua [file]

local arg1, arg2 = ...

print("============")

--assert(4 + 2 == 5, "text")

--check("a = 4")
 check(helper.getFile("myLua/" .. arg1 .. ".lua"))
--helper.printTable_r(rules);

print("============")
