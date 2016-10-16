--[[
<%
  project.title = "parser"
  project.description = "Lua 5.1 parser"
  project.version = "0.1.2"
  project.date = _G.os.date'%B %d, %Y'
  project.modules = { 'grammar', 'parser', 'scanner' }
%>

# Description

Pairing with [scanner.html scanner], this module exports Lua 5.1's syntactic rules as a grammar.

# Dependencies

* [http://www.inf.puc-rio.br/~roberto/lpeg.html LPeg]; 
* [grammar.html grammar]; and 
* [scanner.html scanner].

# The Grammar

The [#variable_rules rules] variable implements the official [http://www.lua.org/manual/5.1/manual.html#8 Lua 5.1 grammar]. It includes all keyword and symbol rules in [scanner.html scanner], as well as the `CHUNK` rule, which matches a complete Lua source file.

[#variable_rules rules] is a table with [http://www.inf.puc-rio.br/~roberto/lpeg.html#grammar open references], not yet a LPeg pattern; to create a pattern, it must be given to `[http://www.inf.puc-rio.br/~roberto/lpeg.html#lpeg lpeg.P]`. This is done to enable users to modify the grammar to suit their particular needs. [grammar.html grammar] provides a small API for this purpose.

The code below shows the Lua 5.1 grammar in LPeg, minus spacing issues.

The following convention is used for rule names:
* **TOKENRULE**: token rules (which represent terminals) are in upper case when applicable (ex. `+, WHILE, NIL, ..., THEN, {, ==`).
* **GrammarRule**: the main grammar rules (non-terminals): Examples are `Chunk`, `FuncName`, `BinOp`, and `TableConstructor`.
* **_GrammarRule**: subdivisions of the main rules, introduced to ease captures. Examples are `_SimpleExp`, `_PrefixExpParens` and `_FieldExp`.
* **METARULE**: grammar rules with a special semantic meaning, to be used for capturing in later modules, like `BOF`, `EOF` and `EPSILON`.

``
rules = {
--   -- See peculiarities below
    IGNORED  = scanner.IGNORED -- used as spacing, not depicted below
    EPSILON = lpeg.P(true)
    EOF     = scanner.EOF -- end of file
    BOF     = scanner.BOF -- beginning of file
    Name    = ID

--   -- Default initial rule
    %[1%]     = CHUNK
    CHUNK   = scanner.BANG^-1 %* Block

    Chunk   = (Stat %* ';'^-1)^0 %* (LastStat %* ';'^-1)^-1
    Block   = Chunk

--   -- STATEMENTS
    Stat          = Assign + FunctionCall + Do + While + Repeat + If
                  + NumericFor + GenericFor + GlobalFunction + LocalFunction
                  + LocalAssign
    Assign        = VarList %* '=' %* ExpList
    Do            = 'do' %* Block %* 'end'
    While         = 'while' %* Exp %* 'do' %* Block %* 'end'
    Repeat        = 'repeat' %* Block %* 'until' %* Exp
    If            = 'if' %* Exp %* 'then' %* Block
                      %* ('elseif' %* Exp %* 'then' %* Block)^0
                      %* (('else' %* Block) + EPSILON)
                      %* 'end'
    NumericFor    = 'for' %* Name %* '='
                      %* Exp %* ',' %* Exp %* ((',' %* Exp) + EPSILON)
                      %* 'do' %* Block %* 'end'
    GenericFor    = 'for' %* NameList %* 'in' %* ExpList %* 'do' %* Block %* 'end'
    GlobalFunction = 'function' %* FuncName %* FuncBody
    LocalFunction = 'local' %* 'function' %* Name %* FuncBody
    LocalAssign   = 'local' %* NameList %* ('=' %* ExpList)^-1
    LastStat      = 'return' %* ExpList^-1
                  + 'break'

--   -- LISTS
    VarList  = Var %* (',' %* Var)^0
    NameList = Name %* (',' %* Name)^0
    ExpList  = Exp %* (',' %* Exp)^0

--   -- EXPRESSIONS
    Exp          = _SimpleExp %* (BinOp %* _SimpleExp)^0
    _SimpleExp   = 'nil' + 'false' + 'true' + Number + String + '...' + Function
                 + _PrefixExp + TableConstructor + (UnOp %* _SimpleExp)
    _PrefixExp   = ( Name                  a Var
                   + _PrefixExpParens      only an expression
                   ) %* (
                       _PrefixExpSquare    a Var
                     + _PrefixExpDot       a Var
                     + _PrefixExpArgs      a FunctionCall
                     + _PrefixExpColon     a FunctionCall
                   ) ^ 0

--   -- Extra rules for semantic actions:
    _PrefixExpParens = '(' %* Exp %* ')'
    _PrefixExpSquare = '[' %* Exp %* ']'
    _PrefixExpDot    = '.' %* ID
    _PrefixExpArgs   = Args
    _PrefixExpColon  = ':' %* ID %* _PrefixExpArgs

--   -- These rules use an internal trick to be distingished from _PrefixExp
    Var              = _PrefixExp
    FunctionCall     = _PrefixExp

--   -- FUNCTIONS
    Function     = 'function' %* FuncBody
    FuncBody     = '(' %* (ParList+EPSILON) %* ')' %* Block %* 'end'
    FuncName     = Name %* _PrefixExpDot^0 %* ((':' %* ID)+EPSILON)
    Args         = '(' %* (ExpList+EPSILON) %* ')'
                 + TableConstructor + String
    ParList      = NameList %* (',' %* '...')^-1
                 + '...'

--   -- TABLES
    TableConstructor = '{' %* (FieldList+EPSILON) %* '}'
    FieldList        = Field %* (FieldSep %* Field)^0 %* FieldSep^-1
    FieldSep         = ',' + ';'

--   -- Extra rules for semantic actions:
    _FieldSquare     = '[' %* Exp %* ']' %* '=' %* Exp
    _FieldID         = ID %* '=' %* Exp
    _FieldExp        = Exp

--   -- OPERATORS
    BinOp    = '+' + '-' + '%*' + '/' + '^' + '%' + '..'
             + '&lt;' + '&lt;=' + '&gt;' + '&gt;=' + '==' + '~='
             + 'and' + 'or'
    UnOp     = '-' + 'not' + '#'

--   -- ...plus scanner's keywords and symbols
}
``

The implementation has certain peculiarities that merit clarification:

* Spacing is matched only between two tokens in a rule, never at the beginning or the end of a rule.
 
* `EPSILON` matches the empty string, which means that it always succeeds without consuming input. Although `rule + EPSILON` can be changed to `rule^-1` without any loss of syntactic power, `EPSILON` was introduced in the parser due to it's usefulness as a placeholder for captures.

* `BOF` and `EOF` are rules used to mark the bounds of a parsing match, and are useful for semantic actions.

* `Name` versus `ID`: the official Lua grammar doesn't distinguish between them, as their syntax is exactly the same (Lua identifiers). But semantically `Name` is a variable identifier, and `ID` is used with different meanings in `_FieldID`, `FuncName`, `_PrefixExpColon` and `_PrefixExpDot`.

* In Lua's [http://www.lua.org/manual/5.1/manual.html#8 original extended BNF grammar], `Var` and `FunctionCall` are defined using left recursion, which is unavailable in PEGs. In this implementation, the problem was solved by modifying the PEG rules to eliminate the left recursion, and by setting some markers (with some LPeg chicanery) to ensure the proper pattern is being used.
--]]

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

-- module declaration
module 'legmoon.parsermoon'

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
    scanner.keywords[chars] = true
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
    if scanner.keywords[name] then
      return false
    end
    return true
  end) / trim

local key
  key = function(chars)
  --scanner.keywords[chars] = true
  return Space * chars * -AlphaNum
end

local DisableDo = m.Cmt("", disable_do)
local PopDo = m.Cmt("", pop_do)
local SelfName = Space * "@" * ("@" * (_Name / util.mark("self_class") + m.Cc("self.__class")) + _Name / util.mark("self") + m.Cc("self"))
local KeyName = SelfName + Space * _Name / util.mark("key_literal")
local VarArg = Space * m.P("...") / trim

 rules = {
    [1] = m.V'File',
    File = Shebang ^ -1 * (m.V'Block' + m.Ct("")),
    Block = m.Ct(m.V'Line' * (Break ^ 1 * m.V'Line') ^ 0),
    CheckIndent = m.Cmt(util.Indent, check_indent),
    Line = (m.V'CheckIndent' * m.V'Statement' + Space * L(Stop)),
    Statement = util.pos(m.V'Import' + m.V'While' + m.V'With' + m.V'For' + m.V'ForEach' + m.V'Switch' + m.V'Return' + m.V'Local' + m.V'Export' + m.V'BreakLoop' 
                + m.Ct(m.V'ExpList') * (m.V'Update' + m.V'Assign') ^ -1 / util.format_assign) 
    			* Space * ((m.V'IF' * m.V'Exp' * (m.V'ELSE' * m.V'Exp') ^ -1 * Space / util.mark("if") + m.V'UNLESS' * m.V'Exp' / util.mark("unless") + m.V'CompInner' / util.mark("comprehension")) * Space) ^ -1 / util.wrap_decorator,
    Body = Space ^ -1 * Break * EmptyLine ^ 0 * m.V'InBlock' + m.Ct(m.V'Statement'),
    Advance = L(m.Cmt(util.Indent, advance_indent)),
    PushIndent = m.Cmt(util.Indent, push_indent),
    PreventIndent = m.Cmt(m.Cc(-1), push_indent),
    PopIndent = m.Cmt("", pop_indent),
    InBlock = m.V'Advance' * m.V'Block' * m.V'PopIndent',
    Local = m.V'LOCAL' * ((op("*") + op("^")) / util.mark("declare_glob") + m.Ct(m.V'NameList') / util.mark("declare_with_shadows")),
    Import = m.V'IMPORT' * m.Ct(m.V'ImportNameList') * SpaceBreak ^ 0 * m.V'FROM' * m.V'Exp' / util.mark("import"),
    ImportName = (util.sym("\\") * m.Ct(m.Cc("colon") * Name) + Name),
    ImportNameList = SpaceBreak ^ 0 * m.V'ImportName' * ((SpaceBreak ^ 1 + util.sym(",") * SpaceBreak ^ 0) * m.V'ImportName') ^ 0,
    BreakLoop = m.Ct(m.V'BREAK' / trim) + m.Ct(m.V'CONTINUE' / trim),
    Return = m.V'RETURN' * (m.V'ExpListLow' / util.mark("explist") + m.C("")) / util.mark("return"),
    WithExp = m.Ct(m.V'ExpList') * m.V'Assign' ^ -1 / util.format_assign,
    With = m.V'WITH' * DisableDo * util.ensure(m.V'WithExp', PopDo) * m.V'DO' ^ -1 * m.V'Body' / util.mark("with"),
    Switch = m.V'SWITCH' * DisableDo * util.ensure(m.V'Exp', PopDo) * m.V'DO' ^ -1 * Space ^ -1 * Break * m.V'SwitchBlock' / util.mark("switch"),
    SwitchBlock = EmptyLine ^ 0 * m.V'Advance' * m.Ct(m.V'SwitchCase' * (Break ^ 1 * m.V'SwitchCase') ^ 0 * (Break ^ 1 * m.V'SwitchElse') ^ -1) * m.V'PopIndent',
    SwitchCase = m.V'WHEN' * m.Ct(m.V'ExpList') * m.V'THEN' ^ -1 * m.V'Body' / util.mark("case"),
    SwitchElse = m.V'ELSE' * m.V'Body' / util.mark("else"),
    IfCond = m.V'Exp' * m.V'Assign' ^ -1 / util.format_single_assign,
    IfElse = (Break * EmptyLine ^ 0 * m.V'CheckIndent') ^ -1 * m.V'ELSE' * m.V'Body' / util.mark("else"),
    IfElseIf = (Break * EmptyLine ^ 0 * m.V'CheckIndent') ^ -1 * m.V'ELSEIF' * util.pos(m.V'IfCond') * m.V'THEN' ^ -1 * m.V'Body' / util.mark("elseif"),
    If = m.V'IF' * m.V'IfCond' * m.V'THEN' ^ -1 * m.V'Body' * m.V'IfElseIf' ^ 0 * m.V'IfElse' ^ -1 / util.mark("if"),
    Unless = m.V'UNLESS' * m.V'IfCond' * m.V'THEN' ^ -1 * m.V'Body' * m.V'IfElseIf' ^ 0 * m.V'IfElse' ^ -1 / util.mark("unless"),
    While = m.V'WHILE' * DisableDo * util.ensure(m.V'Exp', PopDo) * m.V'DO' ^ -1 * m.V'Body' / util.mark("while"),
    For = m.V'FOR' * DisableDo * util.ensure(Name * util.sym("=") * m.Ct(m.V'Exp' * util.sym(",") * m.V'Exp' * (util.sym(",") * m.V'Exp') ^ -1), PopDo) * m.V'DO' ^ -1 * m.V'Body' / util.mark("for"),
    ForEach = m.V'FOR' * m.Ct(m.V'AssignableNameList') * m.V'IN' * DisableDo * util.ensure(m.Ct(util.sym("*") * m.V'Exp' / util.mark("unpack") + m.V'ExpList'), PopDo) * m.V'DO' ^ -1 * m.V'Body' / util.mark("foreach"),
    Do = m.V'DO' * m.V'Body' / util.mark("do"),
    Comprehension = util.sym("[") * m.V'Exp' * m.V'CompInner' * util.sym("]") / util.mark("comprehension"),
    TblComprehension = util.sym("{") * m.Ct(m.V'Exp' * (util.sym(",") * m.V'Exp') ^ -1) * m.V'CompInner' * util.sym("}") / util.mark("tblcomprehension"),
    CompInner = m.Ct((m.V'CompForEach' + m.V'CompFor') * m.V'CompClause' ^ 0),
    CompForEach = m.V'FOR' * m.Ct(m.V'AssignableNameList') * m.V'IN' * (util.sym("*") * m.V'Exp' / util.mark("unpack") + m.V'Exp') / util.mark("foreach"),
    CompFor = key("for" * Name * util.sym("=") * m.Ct(m.V'Exp' * util.sym(",") * m.V'Exp' * (util.sym(",") * m.V'Exp') ^ -1) / util.mark("for")),
    CompClause = m.V'CompFor' + m.V'CompForEach' + m.V'WHEN' * m.V'Exp' / util.mark("when"),
    Assign = util.sym("=") * (m.Ct(m.V'With' + m.V'If' + m.V'Switch') + m.Ct(m.V'TableBlock' + m.V'ExpListLow')) / util.mark("assign"),
    Update = ((util.sym("..=") + util.sym("+=") + util.sym("-=") + util.sym("*=") + util.sym("/=") + util.sym("%=") + util.sym("or=") + util.sym("and=") + util.sym("&=") + util.sym("|=") + util.sym(">>=") + util.sym("<<=")) / trim) * m.V'Exp' / util.mark("update"),
    CharOperators = Space * m.C(m.S("+-*/%^><|&")),
    WordOperators = m.V'OR' + m.V'AND' + op("<=") + op(">=") + op("~=") + op("!=") + op("==") + op("..") + op("<<") + op(">>") + op("//"),
    BinaryOperator = (m.V'WordOperators' + m.V'CharOperators') * SpaceBreak ^ 0,
    Assignable = m.Cmt(m.V'Chain', util.check_assignable) + Name + SelfName,
    Exp = m.Ct(m.V'Value' * (m.V'BinaryOperator' * m.V'Value') ^ 0) / util.flatten_or_mark("exp"),
    SimpleValue = m.V'If' + m.V'Unless' + m.V'Switch' + m.V'With' + m.V'ClassDecl' + m.V'ForEach' + m.V'For' + m.V'While' + m.Cmt(m.V'Do', check_do) + util.sym("-") * -SomeSpace * m.V'Exp' / util.mark("minus") + util.sym("#") * m.V'Exp' / util.mark("length") + util.sym("~") * m.V'Exp' / util.mark("bitnot") + m.V'NOT' * m.V'Exp' / util.mark("not") + m.V'TblComprehension' + m.V'TableLit' + m.V'Comprehension' + m.V'FunLit' + Num,
    ChainValue = (m.V'Chain' + m.V'Callable') * m.Ct(m.V'InvokeArgs' ^ -1) / util.join_chain,
    Value = util.pos(m.V'SimpleValue' + m.Ct(m.V'KeyValueList') / util.mark("table") + m.V'ChainValue' + m.V'String'),
    SliceValue = m.V'Exp',
    String = Space * m.V'DoubleString' + Space * m.V'SingleString' + m.V'LuaString',
    SingleString = util.simple_string("'"),
    DoubleString = util.simple_string('"', true),
    LuaString = m.Cg(m.V'LuaStringOpen', "string_open") * m.Cb("string_open") * Break ^ -1 * m.C((1 - m.Cmt(m.C(m.V'LuaStringClose') * m.Cb("string_open"), util.check_lua_string)) ^ 0) * m.V'LuaStringClose' / util.mark("string"),
    LuaStringOpen = util.sym("[") * m.P("=") ^ 0 * "[" / trim,
    LuaStringClose = "]" * m.P("=") ^ 0 * "]",
    Callable = util.pos(Name / util.mark("ref")) + SelfName + VarArg + m.V'Parens' / util.mark("parens"),
    Parens = util.sym("(") * SpaceBreak ^ 0 * m.V'Exp' * SpaceBreak ^ 0 * util.sym(")"),
    FnArgs = util.symx("(") * SpaceBreak ^ 0 * m.Ct(m.V'FnArgsExpList' ^ -1) * SpaceBreak ^ 0 * util.sym(")") + util.sym("!") * -m.P("=") * m.Ct(""),
    FnArgsExpList = m.V'Exp' * ((Break + util.sym(",")) * White * m.V'Exp') ^ 0,
    Chain = (m.V'Callable' + m.V'String' + -m.S(".\\")) * m.V'ChainItems' / util.mark("chain") + Space * (m.V'DotChainItem' * m.V'ChainItems' ^ -1 + m.V'ColonChain') / util.mark("chain"),
    ChainItems = m.V'ChainItem' ^ 1 * m.V'ColonChain' ^ -1 + m.V'ColonChain',
    ChainItem = m.V'Invoke' + m.V'DotChainItem' + m.V'Slice' + util.symx("[") * m.V'Exp' / util.mark("index") * util.sym("]"),
    DotChainItem = util.symx(".") * _Name / util.mark("dot"),
    ColonChainItem = util.symx("\\") * _Name / util.mark("colon"),
    ColonChain = m.V'ColonChainItem' * (m.V'Invoke' * m.V'ChainItems' ^ -1) ^ -1,
    Slice = util.symx("[") * (m.V'SliceValue' + m.Cc(1)) * util.sym(",") * (m.V'SliceValue' + m.Cc("")) * (util.sym(",") * m.V'SliceValue') ^ -1 * util.sym("]") / util.mark("slice"),
    Invoke = m.V'FnArgs' / util.mark("call") + m.V'SingleString' / util.wrap_func_arg + m.V'DoubleString' / util.wrap_func_arg + L(m.P("[")) * m.V'LuaString' / util.wrap_func_arg,
    TableValue = m.V'KeyValue' + m.Ct(m.V'Exp'),
    TableLit = util.sym("{") * m.Ct(m.V'TableValueList' ^ -1 * util.sym(",") ^ -1 * (SpaceBreak * m.V'TableLitLine' * (util.sym(",") ^ -1 * SpaceBreak * m.V'TableLitLine') ^ 0 * util.sym(",") ^ -1) ^ -1) * White * util.sym("}") / util.mark("table"),
    TableValueList = m.V'TableValue' * (util.sym(",") * m.V'TableValue') ^ 0,
    TableLitLine = m.V'PushIndent' * ((m.V'TableValueList' * m.V'PopIndent') + (m.V'PopIndent' * util.Cut)) + Space,
    TableBlockInner = m.Ct(m.V'KeyValueLine' * (SpaceBreak ^ 1 * m.V'KeyValueLine') ^ 0),
    TableBlock = SpaceBreak ^ 1 * m.V'Advance' * util.ensure(m.V'TableBlockInner', m.V'PopIndent') / util.mark("table"),
    ClassDecl = m.V'CLASS' * -m.P(":") * (m.V'Assignable' + m.Cc(nil)) * (m.V'EXTENDS' * m.V'PreventIndent' * util.ensure(m.V'Exp', m.V'PopIndent') + m.C("")) ^ -1 * (m.V'ClassBlock' + m.Ct("")) / util.mark("class"),
    ClassBlock = SpaceBreak ^ 1 * m.V'Advance' * m.Ct(m.V'ClassLine' * (SpaceBreak ^ 1 * m.V'ClassLine') ^ 0) * m.V'PopIndent',
    ClassLine = m.V'CheckIndent' * ((m.V'KeyValueList' / util.mark("props") + m.V'Statement' / util.mark("stm") + m.V'Exp' / util.mark("stm")) * util.sym(",") ^ -1),
    Export = m.V'EXPORT' * (m.Cc("class") * m.V'ClassDecl' + op("*") + op("^") + m.Ct(m.V'NameList') * (util.sym("=") * m.Ct(m.V'ExpListLow')) ^ -1) / util.mark("export"),
    KeyValue = (util.sym(":") * -SomeSpace * Name * m.Cp()) / util.self_assign + m.Ct((KeyName + util.sym("[") * m.V'Exp' * util.sym("]") + Space * m.V'DoubleString' + Space * m.V'SingleString') * util.symx(":") * (m.V'Exp' + m.V'TableBlock' + SpaceBreak ^ 1 * m.V'Exp')),
    KeyValueList = m.V'KeyValue' * (util.sym(",") * m.V'KeyValue') ^ 0,
    KeyValueLine = m.V'CheckIndent' * m.V'KeyValueList' * util.sym(",") ^ -1,
    FnArgsDef = util.sym("(") * White * m.Ct(m.V'FnArgDefList' ^ -1) * (m.V'USING' * m.Ct(m.V'NameList' + Space * "nil") + m.Ct("")) * White * util.sym(")") + m.Ct("") * m.Ct(""),
    FnArgDefList = m.V'FnArgDef' * ((util.sym(",") + Break) * White * m.V'FnArgDef') ^ 0 * ((util.sym(",") + Break) * White * m.Ct(VarArg)) ^ 0 + m.Ct(VarArg),
    FnArgDef = m.Ct((Name + SelfName) * (util.sym("=") * m.V'Exp') ^ -1),
    FunLit = m.V'FnArgsDef' * (util.sym("->") * m.Cc("slim") + util.sym("=>") * m.Cc("fat")) * (m.V'Body' + m.Ct("")) / util.mark("fndef"),
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
  local result = builder:match(input)
  
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

