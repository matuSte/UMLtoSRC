local lpeg = require 'lpeg'
local parser = require 'meg.parser'

-- catch matched string's position, text and all nested captures values
local function Cp(...)
	return lpeg.Cp() * lpeg.C(...)
end

-- vrati poziciu a chytenu hodnotu zo vsetkymi vnorenymi hodnotami
rules = {
	[1] = Cp(lpeg.V("File")),
    File = Cp(parser.rules.File),
    Block = Cp(parser.rules.Block),
     CheckIndent = Cp(parser.rules.CheckIndent),
    Line = Cp(parser.rules.Line),
    Statement = Cp(parser.rules.Statement),
    Body = Cp(parser.rules.Body),
     Advance = Cp(parser.rules.Advance),
     PushIndent = Cp(parser.rules.PushIndent),
     PreventIndent = Cp(parser.rules.PreventIndent),
     PopIndent = Cp(parser.rules.PopIndent),
    InBlock = Cp(parser.rules.InBlock),
    Local = Cp(parser.rules.Local),
    Import = Cp(parser.rules.Import),
    ImportName = Cp(parser.rules.ImportName),
    ImportNameList = Cp(parser.rules.ImportNameList),
    BreakLoop = Cp(parser.rules.BreakLoop),
    Return = Cp(parser.rules.Return),
    WithExp = Cp(parser.rules.WithExp),
    With = Cp(parser.rules.With),
    Switch = Cp(parser.rules.Switch),
    SwitchBlock = Cp(parser.rules.SwitchBlock),
    SwitchCase = Cp(parser.rules.SwitchCase),
    SwitchElse = Cp(parser.rules.SwitchElse),
    IfCond = Cp(parser.rules.IfCond),
    IfElse = Cp(parser.rules.IfElse),
    IfElseIf = Cp(parser.rules.IfElseIf),
    If = Cp(parser.rules.If),
    Unless = Cp(parser.rules.Unless),
    While = Cp(parser.rules.While), 
    For = Cp(parser.rules.For), 
    ForEach = Cp(parser.rules.ForEach), 
    Do = Cp(parser.rules.Do), 
    Comprehension = Cp(parser.rules.Comprehension),
    TblComprehension = Cp(parser.rules.TblComprehension), 
    CompInner = Cp(parser.rules.CompInner), 
    CompForEach = Cp(parser.rules.CompForEach), 
    CompFor = Cp(parser.rules.CompFor), 
    CompClause = Cp(parser.rules.CompClause), 
    Assign = Cp(parser.rules.Assign), 
    Update = Cp(parser.rules.Update), 
    CharOperators = Cp(parser.rules.CharOperators),
    WordOperators = Cp(parser.rules.WordOperators), 
    BinaryOperator = Cp(parser.rules.BinaryOperator), 
    Assignable = Cp(parser.rules.Assignable), 
    Exp = Cp(parser.rules.Exp), 
    SimpleValue = Cp(parser.rules.SimpleValue),
    ChainValue = Cp(parser.rules.ChainValue), 
    Value = Cp(parser.rules.Value), 
    SliceValue = Cp(parser.rules.SliceValue), 
    String = Cp(parser.rules.String), 
    SingleString = Cp(parser.rules.SingleString), 
    DoubleString = Cp(parser.rules.DoubleString), 
    LuaString = Cp(parser.rules.LuaString), 
    LuaStringOpen = Cp(parser.rules.LuaStringOpen), 
    LuaStringClose = Cp(parser.rules.LuaStringClose), 
    Callable = Cp(parser.rules.Callable), 
    Parens = Cp(parser.rules.Parens),
    FnArgs = Cp(parser.rules.FnArgs), 
    FnArgsExpList = Cp(parser.rules.FnArgsExpList), 
    Chain = Cp(parser.rules.Chain), 
    ChainItems = Cp(parser.rules.ChainItems),
    ChainItem = Cp(parser.rules.ChainItem), 
    DotChainItem = Cp(parser.rules.DotChainItem), 
    ColonChainItem = Cp(parser.rules.ColonChainItem), 
    ColonChain = Cp(parser.rules.ColonChain), 
    Slice = Cp(parser.rules.Slice), 
    Invoke = Cp(parser.rules.Invoke), 
    TableValue = Cp(parser.rules.TableValue), 
    TableLit = Cp(parser.rules.TableLit), 
    TableValueList = Cp(parser.rules.TableValueList), 
    TableLitLine = Cp(parser.rules.TableLitLine), 
    TableBlockInner = Cp(parser.rules.TableBlockInner), 
    TableBlock = Cp(parser.rules.TableBlock), 
    ClassDecl = Cp(parser.rules.ClassDecl), 
    ClassBlock = Cp(parser.rules.ClassBlock), 
    ClassLine = Cp(parser.rules.ClassLine), 
    Export = Cp(parser.rules.Export), 
    KeyValue = Cp(parser.rules.KeyValue), 
    KeyValueList = Cp(parser.rules.KeyValueList),
    KeyValueLine = Cp(parser.rules.KeyValueLine),
    FnArgsDef = Cp(parser.rules.FnArgsDef), 
    FnArgDefList = Cp(parser.rules.FnArgDefList), 
    FnArgDef = Cp(parser.rules.FnArgDef), 
    FunLit = Cp(parser.rules.FunLit),
    NameList = Cp(parser.rules.NameList),
    NameOrDestructure = Cp(parser.rules.NameOrDestructure),
    AssignableNameList = Cp(parser.rules.AssignableNameList),
    ExpList = Cp(parser.rules.ExpList),
    ExpListLow = Cp(parser.rules.ExpListLow),
    InvokeArgs = Cp(parser.rules.InvokeArgs),
    ArgBlock = Cp(parser.rules.ArgBlock),
    ArgLine = Cp(parser.rules.ArgLine),
    
    Name = Cp(parser.rules.Name),
    SelfName = Cp(parser.rules.SelfName),
    KeyName = Cp(parser.rules.KeyName),
    VarArg = Cp(parser.rules.VarArg),

    --KEYWORDS
    LOCAL = Cp(parser.rules.LOCAL),
    IMPORT = Cp(parser.rules.IMPORT),
    BREAK = Cp(parser.rules.BREAK),
    FROM = Cp(parser.rules.FROM),
    IF = Cp(parser.rules.IF),
    ELSE = Cp(parser.rules.ELSE),
    ELSEIF = Cp(parser.rules.ELSEIF),
    UNLESS = Cp(parser.rules.UNLESS),
    RETURN = Cp(parser.rules.RETURN),
    WITH = Cp(parser.rules.WITH),
    SWITCH = Cp(parser.rules.SWITCH),
    DO = Cp(parser.rules.DO),
    WHEN = Cp(parser.rules.WHEN),
    THEN = Cp(parser.rules.THEN),
    CONTINUE = Cp(parser.rules.CONTINUE),
    WHILE = Cp(parser.rules.WHILE),
    FOR = Cp(parser.rules.FOR),
    IN = Cp(parser.rules.IN),
    NOT = Cp(parser.rules.NOT),
    CLASS = Cp(parser.rules.CLASS),
    EXTENDS = Cp(parser.rules.EXTENDS),
    EXPORT = Cp(parser.rules.EXPORT),
    USING = Cp(parser.rules.USING),

    --WHITESPACES           -- nefunguju
    Comment = Cp(parser.Comment),
    Space = Cp(parser.Space),

    --SYMBOLS
    ['\\'] = Cp('\\'),
    [','] = Cp(','),
    ['='] = Cp('='),
    ['*'] = Cp('*'),
    ['['] = Cp('['),
    [']'] = Cp(']'),
    ['{'] = Cp('{'),
    ['}'] = Cp('}'),
    ['('] = Cp('('),
    [')'] = Cp(')'),
    ['*'] = Cp('*'),
    ['..='] = Cp('..='),
    ['+='] = Cp('+='),
    ['-='] = Cp('-='),
    ['*='] = Cp('*='),
    ['/='] = Cp('/='),
    ['%='] = Cp('%='),
    ['or='] = Cp('or='),
    ['and='] = Cp('and='),
    ['&='] = Cp('&='),
    ['|='] = Cp('|='),
    ['>>='] = Cp('>>='),
    ['<<='] = Cp('<<='),
    ['-'] = Cp('-'),
    ['+'] = Cp('+'),
    ['#'] = Cp('#'),
    ['~'] = Cp('~'),
    ['!'] = Cp('!'),
    [':'] = Cp(':'),
    ['->'] = Cp('->'),
    ['=>'] = Cp('=>'),
    [';'] = Cp(';')

    --OPERATORS

--whitespace, komentare, symboly ...
}


return {
    rules = rules
}
