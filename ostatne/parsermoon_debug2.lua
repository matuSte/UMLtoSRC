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

local scanner = require 'legmoon.scannermoon'
local grammar = require 'legmoon.grammarmoon'
local Stack = require 'legmoon.data'.Stack
local util = require 'legmoon.moon_util'

local helper = require 'myLua/helper'

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

end

-- this will be used a lot below
local S, listOf, anyOf = m.V'IGNORED', grammar.listOf, grammar.anyOf

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
local _Name = m.C(m.R("az", "AZ", "__") * AlphaNum ^ 0)
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
  local patt = Space * m.C(chars)
  if chars:match("^%w*$") then
    keywords2[chars] = true
    patt = patt * -AlphaNum
  end
  return patt
end

local SpaceName = Space * _Name

Num = Space * (Num / function(v)
  return {
    "number",
    v
  }
end)

local Name = m.Cmt(SpaceName, function(str, pos, name)
    if keywords2[name] then
      return false
    end
    return true
  end) / trim

local key
  key = function(chars)
  keywords2[chars] = true
  return Space * chars * -AlphaNum
end

local DisableDo = m.Cmt("", disable_do)
local PopDo = m.Cmt("", pop_do)
local SelfName = Space * "@" * ("@" * (_Name + m.Cc("self.__class")) + _Name + m.Cc("self"))
local KeyName = SelfName + Space * _Name
local VarArg = Space * m.P("...")

 rules = {
    [1] = m.V'File',
    File = Shebang ^ -1 * (m.V'Block' + ""),
    Block = m.V'Line' * (Break ^ 1 * m.V'Line') ^ 0,
    CheckIndent = m.Cmt(util.Indent, check_indent),
    Line = (m.V'CheckIndent' * m.V'Statement' + Space * L(Stop)),
    Statement = util.pos(m.V'Import' + m.V'While' + m.V'With' + m.V'For' + m.V'ForEach' + m.V'Switch' + m.V'Return' + m.V'Local' + m.V'Export' + m.V'BreakLoop' 
                + m.V'ExpList' * (m.V'Update' + m.V'Assign') ^ -1) 
    			* Space * ((m.V'IF' * m.V'Exp' * (m.V'ELSE' * m.V'Exp') ^ -1 * Space + m.V'UNLESS' * m.V'Exp' + m.V'CompInner') * Space) ^ -1 ,
    Body = Space ^ -1 * Break * EmptyLine ^ 0 * m.V'InBlock' + m.V'Statement',
    Advance = L(m.Cmt(util.Indent, advance_indent)),
    PushIndent = m.Cmt(util.Indent, push_indent),
    PreventIndent = m.Cmt(m.Cc(-1), push_indent),
    PopIndent = m.Cmt("", pop_indent),
    InBlock = m.V'Advance' * m.V'Block' * m.V'PopIndent',
    Local = m.V'LOCAL' * ((op("*") + op("^")) + m.V'NameList' ),
    Import = m.V'IMPORT' * m.V'ImportNameList' * SpaceBreak ^ 0 * m.V'FROM' * m.V'Exp',
    ImportName = (util.sym("\\") * m.Cc("colon") * Name + Name),
    ImportNameList = SpaceBreak ^ 0 * m.V'ImportName' * ((SpaceBreak ^ 1 + util.sym(",") * SpaceBreak ^ 0) * m.V'ImportName') ^ 0,
    BreakLoop = m.V'BREAK' +m.V'CONTINUE',
    Return = m.V'RETURN' * (m.V'ExpListLow' + m.C("")),
    WithExp = m.V'ExpList' * m.V'Assign' ^ -1,
    With = m.V'WITH' * DisableDo * util.ensure(m.V'WithExp', PopDo) * m.V'DO' ^ -1 * m.V'Body',
    Switch = m.V'SWITCH' * DisableDo * util.ensure(m.V'Exp', PopDo) * m.V'DO' ^ -1 * Space ^ -1 * Break * m.V'SwitchBlock',
    SwitchBlock = EmptyLine ^ 0 * m.V'Advance' * m.V'SwitchCase' * (Break ^ 1 * m.V'SwitchCase') ^ 0 * (Break ^ 1 * m.V'SwitchElse') ^ -1 * m.V'PopIndent',
    SwitchCase = m.V'WHEN' * m.V'ExpList' * m.V'THEN' ^ -1 * m.V'Body',
    SwitchElse = m.V'ELSE' * m.V'Body',
    IfCond = m.V'Exp' * m.V'Assign' ^ -1 ,
    IfElse = (Break * EmptyLine ^ 0 * m.V'CheckIndent') ^ -1 * m.V'ELSE' * m.V'Body',
    IfElseIf = (Break * EmptyLine ^ 0 * m.V'CheckIndent') ^ -1 * m.V'ELSEIF' * util.pos(m.V'IfCond') * m.V'THEN' ^ -1 * m.V'Body' ,
    If = m.V'IF' * m.V'IfCond' * m.V'THEN' ^ -1 * m.V'Body' * m.V'IfElseIf' ^ 0 * m.V'IfElse' ^ -1,
    Unless = m.V'UNLESS' * m.V'IfCond' * m.V'THEN' ^ -1 * m.V'Body' * m.V'IfElseIf' ^ 0 * m.V'IfElse' ^ -1 ,
    While = m.V'WHILE' * DisableDo * util.ensure(m.V'Exp', PopDo) * m.V'DO' ^ -1 * m.V'Body' ,
    For = m.V'FOR' * DisableDo * util.ensure(Name * util.sym("=") * m.V'Exp' * util.sym(",") * m.V'Exp' * (util.sym(",") * m.V'Exp') ^ -1, PopDo) * m.V'DO' ^ -1 * m.V'Body',
    ForEach = m.V'FOR' * m.V'AssignableNameList' * m.V'IN' * DisableDo * util.ensure(util.sym("*") * m.V'Exp' + m.V'ExpList', PopDo) * m.V'DO' ^ -1 * m.V'Body',
    Do = m.V'DO' * m.V'Body' ,
    Comprehension = util.sym("[") * m.V'Exp' * m.V'CompInner' * util.sym("]"),
    TblComprehension = util.sym("{") * m.V'Exp' * (util.sym(",") * m.V'Exp') ^ -1 * m.V'CompInner' * util.sym("}") ,
    CompInner = (m.V'CompForEach' + m.V'CompFor' * m.V'CompClause' ^ 0),
    CompForEach = m.V'FOR' * m.V'AssignableNameList' * m.V'IN' * (util.sym("*") * m.V'Exp' + m.V'Exp'),
    CompFor = key("for" * Name * util.sym("=") * m.V'Exp' * util.sym(",") * m.V'Exp' * (util.sym(",") * m.V'Exp') ^ -1),
    CompClause = m.V'CompFor' + m.V'CompForEach' + m.V'WHEN' * m.V'Exp' ,
    Assign = util.sym("=") * (m.V'With' + m.V'If' + m.V'Switch' + m.V'TableBlock' + m.V'ExpListLow') ,
    Update = ((util.sym("..=") + util.sym("+=") + util.sym("-=") + util.sym("*=") + util.sym("/=") + util.sym("%=") + util.sym("or=") + util.sym("and=") + util.sym("&=") + util.sym("|=") + util.sym(">>=") + util.sym("<<="))) * m.V'Exp',
    CharOperators = Space * m.C(m.S("+-*/%^><|&")),
    WordOperators = m.V'OR' + m.V'AND' + m.V'<=' + m.V'>=' + m.V'~=' + m.V'!=' + m.V'==' + m.V'..' + m.V'<<' + m.V'>>' + m.V'//',
    BinaryOperator = (m.V'WordOperators' + m.V'CharOperators') * SpaceBreak ^ 0,
    Assignable = m.Cmt(m.V'Chain', util.check_assignable) + Name + SelfName,
    Exp = m.V'Value' * (m.V'BinaryOperator' * m.V'Value') ^ 0 ,
    SimpleValue = m.V'If' + m.V'Unless' + m.V'Switch' + m.V'With' + m.V'ClassDecl' + m.V'ForEach' + m.V'For' + m.V'While' + m.Cmt(m.V'Do', check_do) + util.sym("-") * -SomeSpace * m.V'Exp' + util.sym("#") * m.V'Exp' + util.sym("~") * m.V'Exp' + m.V'NOT' * m.V'Exp' + m.V'TblComprehension' + m.V'TableLit' + m.V'Comprehension' + m.V'FunLit' + Num,
    ChainValue = (m.V'Chain' + m.V'Callable') * m.V'InvokeArgs' ^ -1,
    Value = util.pos(m.V'SimpleValue' + m.V'KeyValueList'  + m.V'ChainValue' + m.V'String'),
    SliceValue = m.V'Exp',
    String = Space * m.V'DoubleString' + Space * m.V'SingleString' + m.V'LuaString',
    SingleString = util.simple_string("'"),
    DoubleString = util.simple_string('"', true),
    LuaString = m.Cg(m.V'LuaStringOpen', "string_open") * m.Cb("string_open") * Break ^ -1 * m.C((1 - m.Cmt(m.C(m.V'LuaStringClose') * m.Cb("string_open"), util.check_lua_string)) ^ 0) * m.V'LuaStringClose',
    LuaStringOpen = util.sym("[") * m.P("=") ^ 0 * "[",
    LuaStringClose = "]" * m.P("=") ^ 0 * "]",
    Callable = util.pos(Name) + SelfName + VarArg + m.V'Parens',
    Parens = util.sym("(") * SpaceBreak ^ 0 * m.V'Exp' * SpaceBreak ^ 0 * util.sym(")"),
    FnArgs = util.symx("(") * SpaceBreak ^ 0 * m.V'FnArgsExpList' ^ -1 * SpaceBreak ^ 0 * util.sym(")") + util.sym("!") * -m.P("=") * "",
    FnArgsExpList = m.V'Exp' * ((Break + util.sym(",")) * White * m.V'Exp') ^ 0,
    Chain = (m.V'Callable' + m.V'String' + -m.S(".\\")) * m.V'ChainItems' + Space * (m.V'DotChainItem' * m.V'ChainItems' ^ -1 + m.V'ColonChain'),
    ChainItems = m.V'ChainItem' ^ 1 * m.V'ColonChain' ^ -1 + m.V'ColonChain',
    ChainItem = m.V'Invoke' + m.V'DotChainItem' + m.V'Slice' + util.symx("[") * m.V'Exp' * util.sym("]"),
    DotChainItem = util.symx(".") * _Name,
    ColonChainItem = util.symx("\\") * _Name,
    ColonChain = m.V'ColonChainItem' * (m.V'Invoke' * m.V'ChainItems' ^ -1) ^ -1,
    Slice = util.symx("[") * (m.V'SliceValue' + m.Cc(1)) * util.sym(",") * (m.V'SliceValue' + m.Cc("")) * (util.sym(",") * m.V'SliceValue') ^ -1 * util.sym("]") ,
    Invoke = m.V'FnArgs' + m.V'SingleString'+ m.V'DoubleString' + L(m.P("[")) * m.V'LuaString',
    TableValue = m.V'KeyValue' + m.V'Exp',
    TableLit = util.sym("{") * (m.V'TableValueList' ^ -1 * util.sym(",") ^ -1 * (SpaceBreak * m.V'TableLitLine' * (util.sym(",") ^ -1 * SpaceBreak * m.V'TableLitLine') ^ 0 * util.sym(",") ^ -1) ^ -1) * White * util.sym("}"),
    TableValueList = m.V'TableValue' * (util.sym(",") * m.V'TableValue') ^ 0,
    TableLitLine = m.V'PushIndent' * ((m.V'TableValueList' * m.V'PopIndent') + (m.V'PopIndent' * util.Cut)) + Space,
    TableBlockInner = m.V'KeyValueLine' * (SpaceBreak ^ 1 * m.V'KeyValueLine') ^ 0,
    TableBlock = SpaceBreak ^ 1 * m.V'Advance' * util.ensure(m.V'TableBlockInner', m.V'PopIndent'),
    ClassDecl = m.V'CLASS' * -m.P(":") * (m.V'Assignable' + m.Cc(nil)) * (m.V'EXTENDS' * m.V'PreventIndent' * util.ensure(m.V'Exp', m.V'PopIndent') + m.C("")) ^ -1 * (m.V'ClassBlock' + ""),
    ClassBlock = SpaceBreak ^ 1 * m.V'Advance' * m.V'ClassLine' * (SpaceBreak ^ 1 * m.V'ClassLine') ^ 0 * m.V'PopIndent',
    ClassLine = m.V'CheckIndent' * ((m.V'KeyValueList' + m.V'Statement' + m.V'Exp' ) * util.sym(",") ^ -1),
    Export = m.V'EXPORT' * (m.Cc("class") * m.V'ClassDecl' + op("*") + op("^") + m.V'NameList' * (util.sym("=") * m.V'ExpListLow') ^ -1),
    KeyValue = (util.sym(":") * -SomeSpace * Name * m.Cp()) + (KeyName + util.sym("[") * m.V'Exp' * util.sym("]") + Space * m.V'DoubleString' + Space * m.V'SingleString' * util.symx(":") * (m.V'Exp' + m.V'TableBlock' + SpaceBreak ^ 1 * m.V'Exp')),
    KeyValueList = m.V'KeyValue' * (util.sym(",") * m.V'KeyValue') ^ 0,
    KeyValueLine = m.V'CheckIndent' * m.V'KeyValueList' * util.sym(",") ^ -1,
    FnArgsDef = util.sym("(") * White * m.V'FnArgDefList' ^ -1 * (m.V'USING' * m.V'NameList' + Space * "nil" + "") * White * util.sym(")") , -- + m.Ct("") * m.Ct(""),
    FnArgDefList = m.V'FnArgDef' * ((util.sym(",") + Break) * White * m.V'FnArgDef') ^ 0 * ((util.sym(",") + Break) * White * VarArg) ^ 0 + VarArg,
    FnArgDef = (Name + SelfName) * (util.sym("=") * m.V'Exp') ^ -1,
    FunLit = m.V'FnArgsDef' * (util.sym("->") * m.Cc("slim") + util.sym("=>") * m.Cc("fat")) * (m.V'Body' + "") ,
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
grammar.complete(rules, scanner.keywords)
grammar.complete(rules, scanner.symbols)

--[[
Checks if `input` is valid Lua source code.

**Parameters:**
* `input`: a string containing Lua source code.

**Returns:**
* `true`, if `input` is valid Lua source code, or `false` and an error message if the matching fails.
--]]
function check(input)
  local builder = m.P(rules)
  print("rules:")
  helper.printTable_r(rules)
  local result = builder:match(input)
  
  print("rules:")
  helper.printTable_r(rules)
  print("===================%")
  print("grammar:")
  helper.printTable_r(grammar)
  print("==============%")
  print("result:")
  helper.printTable_r(result)
  
  if result ~= #input + 1 then -- failure, build the error message
    local init, _ = rfind(input, '\n*', result - 1) 
    local _, finish = string.find(input, '\n*', result + 1)
    
    init = init or 0
    finish = finish or #input
    
    local line = lines(input:sub(1, result))
    local vicinity = input:sub(init + 1, finish)
    
    return false, 'Syntax error at line '..line..', near "'..vicinity..'"'
  end
  
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


print("============")

check("a = 4")
 --check(helper.getFile("myLua/moon.lua"))

print("============")



--[[
=============================
result:
  a
===========================
rules:
table: 0x4139c620 {
  [1] => userdata: 0x413a7de8
  [LOCAL] => userdata: 0x40d3a168
  [.] => userdata: 0x4139c218
  [ImportNameList] => userdata: 0x40d45638
  [...] => userdata: 0x413ac1e8
  [Callable] => userdata: 0x40d3f268
  [Local] => userdata: 0x413ade60
  [Assign] => userdata: 0x40d55d40
  [TableValueList] => userdata: 0x40d485e0
  [TableBlockInner] => userdata: 0x40d48190
  [TableBlock] => userdata: 0x40d44e08
  [TblComprehension] => userdata: 0x40d52578
  [ForEach] => userdata: 0x40d4c9f8
  [InBlock] => userdata: 0x413ad2a8
  [SingleString] => userdata: 0x41a5ea18
  [RETURN] => userdata: 0x413b3d70
  [Line] => userdata: 0x40d3b0e0
  [<] => userdata: 0x413a8340
  [[] => userdata: 0x4139fbd0
  [ClassDecl] => userdata: 0x40d406c8
  [EXPORT] => userdata: 0x413a74a0
  [TableLit] => userdata: 0x40d43108
  [WHILE] => userdata: 0x41397d98
  [File] => userdata: 0x40d44700
  [NIL] => userdata: 0x40d3a6b8
  [ArgBlock] => userdata: 0x41a5c4f0
  [SwitchCase] => userdata: 0x40d42d80
  [==] => userdata: 0x413ac708
  [SWITCH] => userdata: 0x413a8438
  [#] => userdata: 0x4139ffb0
  [>>] => userdata: 0x413b27e8
  [KeyValueList] => userdata: 0x40d53f90
  [SliceValue] => userdata: 0x41a5dd00
  [IfElse] => userdata: 0x40d43800
  [FnArgDef] => userdata: 0x41a55320
  [WithExp] => userdata: 0x40d45bb0
  [ImportName] => userdata: 0x40d3d2b8
  [UNTIL] => userdata: 0x41397d18
  [IfCond] => userdata: 0x40d43080
  [ColonChain] => userdata: 0x413ac230
  [FUNCTION] => userdata: 0x413b2a88
  [CLASS] => userdata: 0x413a8040
  [IMPORT] => userdata: 0x413afae0
  [Unless] => userdata: 0x40d3feb0
  [CompForEach] => userdata: 0x40d53108
  [WHEN] => userdata: 0x4139fb58
  [IF] => userdata: 0x413b3018
  [BinaryOperator] => userdata: 0x41a57e70
  [Invoke] => userdata: 0x40d39430
  [USING] => userdata: 0x413a6ae0
  [ELSEIF] => userdata: 0x413b2b50
  [TableLitLine] => userdata: 0x40d3d090
  [ClassBlock] => userdata: 0x40d4c660
  [WITH] => userdata: 0x413a7c28
  [REPEAT] => userdata: 0x40d3b8a8
  [//] => userdata: 0x4139db68
  [IN] => userdata: 0x413b3f30
  [InvokeArgs] => userdata: 0x41a5b918
  [IfElseIf] => userdata: 0x40d3f098
  [NOT] => userdata: 0x40d3ac50
  [ClassLine] => userdata: 0x40d4f5a8
  [DotChainItem] => userdata: 0x40d3d870
  [TableValue] => userdata: 0x40d42e60
  [PopIndent] => userdata: 0x413b2cd0
  [LuaStringOpen] => userdata: 0x40d444a8
  [Chain] => userdata: 0x41a5ee08
  [Comprehension] => userdata: 0x40d51840
  [For] => userdata: 0x40d4b5a8
  [Body] => userdata: 0x40d48a30
  [CharOperators] => userdata: 0x41a56ba0
  [LuaString] => userdata: 0x41a609d8
  [ExpList] => userdata: 0x40d4a838
  [;] => userdata: 0x413a0bf0
  [KeyValueLine] => userdata: 0x40d54430
  [FnArgsDef] => userdata: 0x41a59728
  [FnArgsExpList] => userdata: 0x40d3bde8
  [=] => userdata: 0x4139f0b0
  [Advance] => userdata: 0x4139f6d0
  [>] => userdata: 0x4139cea0
  [EXTENDS] => userdata: 0x41397e18
  [\] => userdata: 0x413b2050
  [OR] => userdata: 0x40d3b238
  [{] => userdata: 0x413af398
  [%] => userdata: 0x4139e5a8
  [..] => userdata: 0x4139df08
  [Do] => userdata: 0x40d512a0
  [>=] => userdata: 0x413a1480
  [<=] => userdata: 0x413adb20
  [}] => userdata: 0x413abff0
  [FnArgs] => userdata: 0x40d45c38
  [:] => userdata: 0x413a7d80
  [-=] => userdata: 0x4139d020
  [ChainValue] => userdata: 0x41a5d6f0
  [CompFor] => userdata: 0x40d54f20
  [Switch] => userdata: 0x40d41c00
  [~=] => userdata: 0x41395fc8
  [SwitchElse] => userdata: 0x40d42ef8
  [LuaStringClose] => userdata: 0x40d45fd8
  [AssignableNameList] => userdata: 0x40d4a318
  [Block] => userdata: 0x413ad0f0
  [While] => userdata: 0x40d405b0
  [<<] => userdata: 0x413af540
  [THEN] => userdata: 0x413b3e40
  [KeyValue] => userdata: 0x40d53280
  [/=] => userdata: 0x4139cf70
  [Statement] => userdata: 0x413aac38
  []] => userdata: 0x413a18e8
  [/] => userdata: 0x413ac9d8
  [FALSE] => userdata: 0x413b2ee8
  [FunLit] => userdata: 0x40d492b0
  [%=] => userdata: 0x41396090
  [ColonChainItem] => userdata: 0x40d3fab0
  [(] => userdata: 0x413958f8
  [Update] => userdata: 0x41a56088
  [ExpListLow] => userdata: 0x40d4b1c8
  [-] => userdata: 0x413b3cb0
  [ChainItem] => userdata: 0x413b2338
  [SimpleValue] => userdata: 0x41a5caa8
  [+=] => userdata: 0x413b02e8
  [+] => userdata: 0x4139f870
  [FROM] => userdata: 0x413ad5d0
  [)] => userdata: 0x41395928
  [!=] => userdata: 0x413a1d90
  [*=] => userdata: 0x4139c400
  [CompClause] => userdata: 0x40d55688
  [*] => userdata: 0x413aca48
  [NameList] => userdata: 0x40d499e0
  [Exp] => userdata: 0x41a58830
  [Return] => userdata: 0x40d4fbd0
  [,] => userdata: 0x413a7f08
  [SUPER] => userdata: 0x413ad478
  [Import] => userdata: 0x40d39288
  [BreakLoop] => userdata: 0x40d4fa00
  [Slice] => userdata: 0x40d401f0
  [Export] => userdata: 0x40d3e9f0
  [PreventIndent] => userdata: 0x413b2c18
  [If] => userdata: 0x40d3f818
  [CompInner] => userdata: 0x40d52a08
  [DO] => userdata: 0x413b2668
  [ArgLine] => userdata: 0x41a5c7e0
  [FOR] => userdata: 0x413b2fa8
  [UNLESS] => userdata: 0x413af310
  [Value] => userdata: 0x41a5dbe0
  [BREAK] => userdata: 0x413b2478
  [ELSE] => userdata: 0x413b2838
  [WordOperators] => userdata: 0x41a57a70
  [^] => userdata: 0x413a1af8
  [DoubleString] => userdata: 0x41a60458
  [FnArgDefList] => userdata: 0x41a548a0
  [NameOrDestructure] => userdata: 0x40d49d80
  [TRUE] => userdata: 0x40d3d018
  [CONTINUE] => userdata: 0x413a1e70
  [..=] => userdata: 0x41396320
  [END] => userdata: 0x413b2e08
  [SwitchBlock] => userdata: 0x40d42890
  [Parens] => userdata: 0x40d43980
  [PushIndent] => userdata: 0x41398268
  [AND] => userdata: 0x413add18
  [Assignable] => userdata: 0x41a58288
  [ChainItems] => userdata: 0x40d3f6a0
  [With] => userdata: 0x40d46250
  [String] => userdata: 0x41a5e268
  [CheckIndent] => userdata: 0x413b1b58
}

rules:
table: 0x4139c620 {
  [1] => userdata: 0x413a7de8
  [LOCAL] => userdata: 0x40d3a168
  [.] => userdata: 0x4139c218
  [ImportNameList] => userdata: 0x40d45638
  [...] => userdata: 0x413ac1e8
  [Callable] => userdata: 0x40d3f268
  [Local] => userdata: 0x413ade60
  [Assign] => userdata: 0x40d55d40
  [TableValueList] => userdata: 0x40d485e0
  [TableBlockInner] => userdata: 0x40d48190
  [TableBlock] => userdata: 0x40d44e08
  [TblComprehension] => userdata: 0x40d52578
  [ForEach] => userdata: 0x40d4c9f8
  [InBlock] => userdata: 0x413ad2a8
  [SingleString] => userdata: 0x41a5ea18
  [RETURN] => userdata: 0x413b3d70
  [Line] => userdata: 0x40d3b0e0
  [<] => userdata: 0x413a8340
  [[] => userdata: 0x4139fbd0
  [ClassDecl] => userdata: 0x40d406c8
  [EXPORT] => userdata: 0x413a74a0
  [TableLit] => userdata: 0x40d43108
  [WHILE] => userdata: 0x41397d98
  [File] => userdata: 0x40d44700
  [NIL] => userdata: 0x40d3a6b8
  [ArgBlock] => userdata: 0x41a5c4f0
  [SwitchCase] => userdata: 0x40d42d80
  [==] => userdata: 0x413ac708
  [SWITCH] => userdata: 0x413a8438
  [#] => userdata: 0x4139ffb0
  [>>] => userdata: 0x413b27e8
  [KeyValueList] => userdata: 0x40d53f90
  [SliceValue] => userdata: 0x41a5dd00
  [IfElse] => userdata: 0x40d43800
  [FnArgDef] => userdata: 0x41a55320
  [WithExp] => userdata: 0x40d45bb0
  [ImportName] => userdata: 0x40d3d2b8
  [UNTIL] => userdata: 0x41397d18
  [IfCond] => userdata: 0x40d43080
  [ColonChain] => userdata: 0x413ac230
  [FUNCTION] => userdata: 0x413b2a88
  [CLASS] => userdata: 0x413a8040
  [IMPORT] => userdata: 0x413afae0
  [Unless] => userdata: 0x40d3feb0
  [CompForEach] => userdata: 0x40d53108
  [WHEN] => userdata: 0x4139fb58
  [IF] => userdata: 0x413b3018
  [BinaryOperator] => userdata: 0x41a57e70
  [Invoke] => userdata: 0x40d39430
  [USING] => userdata: 0x413a6ae0
  [ELSEIF] => userdata: 0x413b2b50
  [TableLitLine] => userdata: 0x40d3d090
  [ClassBlock] => userdata: 0x40d4c660
  [WITH] => userdata: 0x413a7c28
  [REPEAT] => userdata: 0x40d3b8a8
  [//] => userdata: 0x4139db68
  [IN] => userdata: 0x413b3f30
  [InvokeArgs] => userdata: 0x41a5b918
  [IfElseIf] => userdata: 0x40d3f098
  [NOT] => userdata: 0x40d3ac50
  [ClassLine] => userdata: 0x40d4f5a8
  [DotChainItem] => userdata: 0x40d3d870
  [TableValue] => userdata: 0x40d42e60
  [PopIndent] => userdata: 0x413b2cd0
  [LuaStringOpen] => userdata: 0x40d444a8
  [Chain] => userdata: 0x41a5ee08
  [Comprehension] => userdata: 0x40d51840
  [For] => userdata: 0x40d4b5a8
  [Body] => userdata: 0x40d48a30
  [CharOperators] => userdata: 0x41a56ba0
  [LuaString] => userdata: 0x41a609d8
  [ExpList] => userdata: 0x40d4a838
  [;] => userdata: 0x413a0bf0
  [KeyValueLine] => userdata: 0x40d54430
  [FnArgsDef] => userdata: 0x41a59728
  [FnArgsExpList] => userdata: 0x40d3bde8
  [=] => userdata: 0x4139f0b0
  [Advance] => userdata: 0x4139f6d0
  [>] => userdata: 0x4139cea0
  [EXTENDS] => userdata: 0x41397e18
  [\] => userdata: 0x413b2050
  [OR] => userdata: 0x40d3b238
  [{] => userdata: 0x413af398
  [%] => userdata: 0x4139e5a8
  [..] => userdata: 0x4139df08
  [Do] => userdata: 0x40d512a0
  [>=] => userdata: 0x413a1480
  [<=] => userdata: 0x413adb20
  [}] => userdata: 0x413abff0
  [FnArgs] => userdata: 0x40d45c38
  [:] => userdata: 0x413a7d80
  [-=] => userdata: 0x4139d020
  [ChainValue] => userdata: 0x41a5d6f0
  [CompFor] => userdata: 0x40d54f20
  [Switch] => userdata: 0x40d41c00
  [~=] => userdata: 0x41395fc8
  [SwitchElse] => userdata: 0x40d42ef8
  [LuaStringClose] => userdata: 0x40d45fd8
  [AssignableNameList] => userdata: 0x40d4a318
  [Block] => userdata: 0x413ad0f0
  [While] => userdata: 0x40d405b0
  [<<] => userdata: 0x413af540
  [THEN] => userdata: 0x413b3e40
  [KeyValue] => userdata: 0x40d53280
  [/=] => userdata: 0x4139cf70
  [Statement] => userdata: 0x413aac38
  []] => userdata: 0x413a18e8
  [/] => userdata: 0x413ac9d8
  [FALSE] => userdata: 0x413b2ee8
  [FunLit] => userdata: 0x40d492b0
  [%=] => userdata: 0x41396090
  [ColonChainItem] => userdata: 0x40d3fab0
  [(] => userdata: 0x413958f8
  [Update] => userdata: 0x41a56088
  [ExpListLow] => userdata: 0x40d4b1c8
  [-] => userdata: 0x413b3cb0
  [ChainItem] => userdata: 0x413b2338
  [SimpleValue] => userdata: 0x41a5caa8
  [+=] => userdata: 0x413b02e8
  [+] => userdata: 0x4139f870
  [FROM] => userdata: 0x413ad5d0
  [)] => userdata: 0x41395928
  [!=] => userdata: 0x413a1d90
  [*=] => userdata: 0x4139c400
  [CompClause] => userdata: 0x40d55688
  [*] => userdata: 0x413aca48
  [NameList] => userdata: 0x40d499e0
  [Exp] => userdata: 0x41a58830
  [Return] => userdata: 0x40d4fbd0
  [,] => userdata: 0x413a7f08
  [SUPER] => userdata: 0x413ad478
  [Import] => userdata: 0x40d39288
  [BreakLoop] => userdata: 0x40d4fa00
  [Slice] => userdata: 0x40d401f0
  [Export] => userdata: 0x40d3e9f0
  [PreventIndent] => userdata: 0x413b2c18
  [If] => userdata: 0x40d3f818
  [CompInner] => userdata: 0x40d52a08
  [DO] => userdata: 0x413b2668
  [ArgLine] => userdata: 0x41a5c7e0
  [FOR] => userdata: 0x413b2fa8
  [UNLESS] => userdata: 0x413af310
  [Value] => userdata: 0x41a5dbe0
  [BREAK] => userdata: 0x413b2478
  [ELSE] => userdata: 0x413b2838
  [WordOperators] => userdata: 0x41a57a70
  [^] => userdata: 0x413a1af8
  [DoubleString] => userdata: 0x41a60458
  [FnArgDefList] => userdata: 0x41a548a0
  [NameOrDestructure] => userdata: 0x40d49d80
  [TRUE] => userdata: 0x40d3d018
  [CONTINUE] => userdata: 0x413a1e70
  [..=] => userdata: 0x41396320
  [END] => userdata: 0x413b2e08
  [SwitchBlock] => userdata: 0x40d42890
  [Parens] => userdata: 0x40d43980
  [PushIndent] => userdata: 0x41398268
  [AND] => userdata: 0x413add18
  [Assignable] => userdata: 0x41a58288
  [ChainItems] => userdata: 0x40d3f6a0
  [With] => userdata: 0x40d46250
  [String] => userdata: 0x41a5e268
  [CheckIndent] => userdata: 0x413b1b58
}

===================%
grammar:
table: 0x4139db28 {
  [Ct] => function: 0x4139f188
  [copy] => function: 0x413a7bc0
  [listOf] => function: 0x413ac680
  [apply] => function: 0x413af410
  [pipe] => function: 0x413af3f0
  [_M] => table: 0x4139db28 {
            *table: 0x4139db28
          }
  [anyOf] => function: 0x4139d120
  [_NAME] => "legmoon.grammarmoon"
  [complete] => function: 0x4139fa68
  [C] => function: 0x4139f310
  [_PACKAGE] => "legmoon."
}

==============%
 
 --]]
