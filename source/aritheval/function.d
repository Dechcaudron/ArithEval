module aritheval.evaluable;

import std.meta : allSatisfy, aliasSeqOf;
import std.string;
import std.conv : to;
import std.exception;

import pegged.grammar;

mixin(grammar(`
Arithmetic:
    Whole    < Term ";"
    Term     < Factor (Add / Sub)*
    Add      < "+" Factor
    Sub      < "-" Factor
    Factor   < Primary (Mul / Div)*
    Mul      < "*" Primary
    Div      < "/" Primary
    Primary  < Parens / Neg / Number / Variable
    Parens   < :"(" Term :")"
    Neg      < "-" Primary
    Number   <- [0-9]+
    Variable <- ([a-zA-Z]+) ([a-zA-Z0-9_]*)
`));

static assert(Arithmetic("2;").successful);

private float eval(string expr)
{
    auto p = Arithmetic(expr);

    //writeln(p);

    float value(ParseTree p)
    {
        switch (p.name)
        {
            case "Arithmetic":
                return value(p.children[0]);
            case "Arithmetic.Whole":
                return value(p.children[0]);
            case "Arithmetic.Term":
                float v = 0.0;
                foreach(child; p.children) v += value(child);
                return v;
            case "Arithmetic.Add":
                return value(p.children[0]);
            case "Arithmetic.Sub":
                return -value(p.children[0]);
            case "Arithmetic.Factor":
                float v = 1.0;
                foreach(child; p.children) v *= value(child);
                return v;
            case "Arithmetic.Mul":
                return value(p.children[0]);
            case "Arithmetic.Div":
                return 1.0/value(p.children[0]);
            case "Arithmetic.Primary":
                return value(p.children[0]);
            case "Arithmetic.Parens":
                return value(p.children[0]);
            case "Arithmetic.Neg":
                return -value(p.children[0]);
            case "Arithmetic.Number":
                return to!float(p.matches[0]);
            default:
                return float.nan;
        }
    }

    return value(p);
}
unittest
{
    assert(eval("1;") == 1.0);
    assert(eval("-1;") == -1.0);
    assert(eval("1+1;") == 2.0);
    assert(eval("1-1;") == 0.0);

    assert(eval("1+1+1;") == 3.0);
    assert(eval("1-1-1;") == -1.0);
    assert(eval("1+1-1;") == 1.0);
    assert(eval("1-1+1;") == 1.0);
    assert(eval("-1+1+1;") == 1.0);

    assert(eval("(-1+1)+1;") == 1.0);
    assert(eval("-1+(1+1);") == 1.0);
    assert(eval("(-1+1+1);") == 1.0);
    assert(eval("1-(1-1);") == 1.0);

    assert(eval("1*1;") == 1.0);
    assert(eval("1/1;") == 1.0);
    assert(eval("-1*1;") == -1.0);
    assert(eval("-1/1;") == -1.0);

    assert(eval("1+2*3;") == 7.0);
    assert(eval("1-2*3;") == -5.0);
    assert(eval("-1-2*-3;") == 5.0);
    assert(eval("-1+2*-3;") == -7.0);

    assert(eval("1/2/(1/2);") == 1.0);
    assert(eval("1/2/1/2;") == .25);
    assert(eval("1-2*3-2*3;") == -11.0);

    assert(eval("2*3*3-3*3+3*4;") == 21.0);
    assert(eval("2*3*3-3*(3+3*4);") == -27.0);
}

class InvalidExpressionException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(msg, file, line, null);
    }
}

public struct Evaluable(Vars...)
if(allSatisfy!(isValidVariableName, Vars))
{
    immutable string expr;

    this(string expr)
    in
    {
        assert(expr !is null);
    }
    body
    {
        //TODO: perform runtime checking of variables in the expression

        expr ~= ";";
        enforce!InvalidExpressionException(Arithmetic(expr).successful, "Expression "~expr~" cannot be used.");

        this.expr = expr;
    }
    unittest
    {
        assertNotThrown!InvalidExpressionException(Evaluable!("x", "y")("2*2"));
        assertThrown!InvalidExpressionException(Evaluable!("x", "y")("2y"));
        assertThrown!InvalidExpressionException(Evaluable!("x", "y")("2**4"));
        assertThrown!InvalidExpressionException(Evaluable!("x", "y")("2^4"));
    }

    public float eval(float[Vars.length] evalPoint...)
    {
        import std.range : iota;
        string replacedExpr = expr;

        foreach(i; aliasSeqOf!(iota(0, Vars.length)))
        {
            import std.array;
            replacedExpr = replacedExpr.replace(Vars[i], to!string(evalPoint[i]));
        }

        return aritheval.evaluable.eval(replacedExpr);
    }
}
unittest
{
    import std.stdio;

    auto a = Evaluable!("x", "y", "z")("2*2");
    assert(a.eval(0, 1 ,2) == 4);
    assert(a.eval(-1, 0.5, 3) == 4);

    auto b = Evaluable!("x", "y")("x*y");
    assert(b.eval(0, 0) == 0);
    assert(b.eval(2, 2) == 4);
    assert(b.eval(2, 6) == 12);

    auto c = Evaluable!("x", "y")("1/x*4 + y");
    assert(c.eval(1, 1) == 5);
    assert(c.eval(2, 3) == 5);
    assert(c.eval(4, 5) == 6);
    assert(c.eval(8, 3) == 3.5);
    assert(c.eval(0, 5) == float.infinity);
}


private enum isValidVariableName(string T) = inPattern(T[0], "a-zA-Z") && countchars(T, "^a-zA-Z0-9_") == 0;
unittest
{
    assert(isValidVariableName!"x");
    assert(isValidVariableName!"hello_world");
    assert(isValidVariableName!"HeLlO_w0rLd");
    assert(isValidVariableName!"charlie1");
    assert(!isValidVariableName!"9unicorns");
    assert(!isValidVariableName!"123");
    assert(!isValidVariableName!"hello world");
}
