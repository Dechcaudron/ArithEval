module arith_eval.evaluable;

import std.ascii;
import std.conv : to; 
import std.exception;
import std.experimental.checkedint : Checked, Throw;
import std.format;
import std.meta : allSatisfy, aliasSeqOf;
import std.string;
import std.traits : isNumeric, isIntegral, isFloatingPoint;

import pegged.grammar;

mixin(grammar(`
Arithmetic:
    Whole    < Term ";"
    Term     < (Pow / Factor) (Add / Sub)*
    Add      < "+" Factor
    Sub      < "-" Factor
    Factor   < Primary (Mul / Div)*
    Pow      < Primary "**" Primary
    Mul      < "*" Primary
    Div      < "/" Primary
    Primary  < Parens / Neg / Number / Variable
    Parens   < :"(" Term :")"
    Neg      < "-" Primary
    Number   <- ~(~([0-9]+) ~("." ~([0-9]+))?)
    Variable <- ([a-zA-Z]+) ([a-zA-Z0-9_]*)
`));

private T eval(T)(string expr)
if (isNumeric!T)
{
    import std.math : pow;

    auto p = Arithmetic(expr);

    T value(ParseTree p)
    {
        static if (isIntegral!T)
            alias intermediateType = Checked!(T, Throw);
        else
            alias intermediateType = T;
        switch (p.name)
        {
            case "Arithmetic":
                return value(p.children[0]);
            case "Arithmetic.Whole":
                return value(p.children[0]);
            case "Arithmetic.Term":
                intermediateType v;
                static if (isIntegral!T)
                    v = cast(T)0;
                else
                    v = 0;
                foreach(child; p.children) v += value(child);
                return to!T(v);
            case "Arithmetic.Add":
                return value(p.children[0]);
            case "Arithmetic.Sub":
                return -value(p.children[0]);
            case "Arithmetic.Factor":
                intermediateType v;
                static if (isIntegral!T)
                    v = cast(T)1;
                else
                    v = 1;
                foreach(child; p.children) v *= value(child);
                return to!T(v);
            case "Arithmetic.Pow":
                return to!T(value(p.children[0]) ^^ value(p.children[1]));
            case "Arithmetic.Mul":
                return value(p.children[0]);
            case "Arithmetic.Div":
                return to!T(1/value(p.children[0]));
            case "Arithmetic.Primary":
                return value(p.children[0]);
            case "Arithmetic.Parens":
                return value(p.children[0]);
            case "Arithmetic.Neg":
                return -value(p.children[0]);
            case "Arithmetic.Number":
                return to!T(p.matches[0]);
            default:
                throw new Exception("Invalid p.name " ~ p.name);
        }
    }

    return value(p);
}
unittest
{
    import std.math : pow;

    assert(eval!float("1;") == 1.0);
    assert(eval!float("-1;") == -1.0);
    assert(eval!float("1+1;") == 2.0);
    assert(eval!float("1-1;") == 0.0);

    assert(eval!float("1+1+1;") == 3.0);
    assert(eval!float("1-1-1;") == -1.0);
    assert(eval!float("1+1-1;") == 1.0);
    assert(eval!float("1-1+1;") == 1.0);
    assert(eval!float("-1+1+1;") == 1.0);

    assert(eval!float("(-1+1)+1;") == 1.0);
    assert(eval!float("-1+(1+1);") == 1.0);
    assert(eval!float("(-1+1+1);") == 1.0);
    assert(eval!float("1-(1-1);") == 1.0);

    assert(eval!float("1*1;") == 1.0);
    assert(eval!float("1/1;") == 1.0);
    assert(eval!float("-1*1;") == -1.0);
    assert(eval!float("-1/1;") == -1.0);

    assert(eval!float("1+2*3;") == 7.0);
    assert(eval!float("1-2*3;") == -5.0);
    assert(eval!float("-1-2*-3;") == 5.0);
    assert(eval!float("-1+2*-3;") == -7.0);

    assert(eval!float("1/2/(1/2);") == 1.0);
    assert(eval!float("1/2/1/2;") == .25);
    assert(eval!float("1-2*3-2*3;") == -11.0);

    assert(eval!float("2*3*3-3*3+3*4;") == 21.0);
    assert(eval!float("2*3*3-3*(3+3*4);") == -27.0);

    assert(eval!float("12.34;") == 12.34f);
    assert(eval!float("1.234;") == 1.234f);
    assert(eval!float("0.987;") == 0.987f);

    assert(eval!float("2**8;") == 256);
    assert(eval!float("10**3;") == 1000);
    assert(eval!float("5**0;") == 1);
    assert(eval!float("1.56**3.28") == pow(1.56f, 3.28f));
    //TODO: what should we return?
    //assert(eval!float("0**0;") == float.nan);
}

public struct Evaluable(EvalType, Vars...)
if(isNumeric!EvalType && allSatisfy!(isValidVariableName, Vars))
{
    string expr;

    this(string expr) inout
    in
    {
        assert(expr !is null);
    }
    body
    {
        //TODO: perform runtime checking of variables in the expression

        expr ~= ";";
        enforce!InvalidExpressionException(Arithmetic(expr).successful, 
                        "Expression " ~ expr ~ " cannot be used.");

        this.expr = expr;
    }
    unittest
    {
        assertNotThrown!InvalidExpressionException(Evaluable!int("5 + 2"));        
        assertNotThrown!InvalidExpressionException(Evaluable!(short, "x", "y")("2*2"));
        assertNotThrown!InvalidExpressionException(Evaluable!(short, "x", "y")("2**4"));
        assertThrown!InvalidExpressionException(Evaluable!(short, "x", "y")("2y"));
        assertThrown!InvalidExpressionException(Evaluable!(short, "x", "y")("2^4"));
        assertThrown!InvalidExpressionException(Evaluable!(short, "x", "y")("x y"));
    }

    //TODO: surely there must be a way to avoid redefining this method
    this(string expr) inout shared
    in
    {
        assert(expr !is null);
    }
    body
    {
        //TODO: perform runtime checking of variables in the expression

        expr ~= ";";
        enforce!InvalidExpressionException(Arithmetic(expr).successful, 
                        "Expression " ~ expr ~ " cannot be used.");

        this.expr = expr;
    }
    unittest
    {
        assertNotThrown!InvalidExpressionException(shared Evaluable!(short, "x", "y")("2*2"));
        assertNotThrown!InvalidExpressionException(shared Evaluable!(short, "x", "y")("2**4"));
        assertThrown!InvalidExpressionException(shared Evaluable!(short, "x", "y")("2y"));
        assertThrown!InvalidExpressionException(shared Evaluable!(short, "x", "y")("2^4"));
        assertThrown!InvalidExpressionException(shared Evaluable!(short, "x", "y")("x y"));
    }

    /**
        Evaluates the expression.

        Returns: The value after evaluating the expression (at
                 the point specified by evalPoint, if the number
                 of variables is greater than 0).

        Throws: OverflowException if overflow has occurred during
                the evaluation.
    */
    public EvalType opCall(EvalType[Vars.length] evalPoint...) const
    {
        import std.range : iota;
        string replacedExpr = expr;

        foreach(i; aliasSeqOf!(iota(0, Vars.length)))
        {
            import std.array : replace;
            replacedExpr = replacedExpr.replace(Vars[i], to!string(evalPoint[i]));
        }

        import std.conv : ConvOverflowException;

        void handleOverflow(Throwable e)
        {
            static if (Vars.length == 0)
                immutable string msg = format("Expression \"%s\" evaluation for type %s overflowed.",
                                  expr, EvalType.stringof);
            else
                immutable string msg = format("Expression \"%s\" evaluation for type %s on point '%s' " ~
                                  "overflowed.", expr, EvalType.stringof, to!string(evalPoint));
            throw new OverflowException(msg, e);
        }
        
        try
        {
            immutable EvalType evaluation = arith_eval.evaluable.eval!EvalType(replacedExpr);
            static if (isFloatingPoint!EvalType)
                if (evaluation > EvalType.max || evaluation < -EvalType.max)
                    handleOverflow(null);
            return evaluation;
        }
        catch(ConvOverflowException e)
        {
            handleOverflow(e);
        }
        catch(Throw.CheckFailure e)
        {
            handleOverflow(e);
        }

        assert(0); // Required by compiler
    }

    public EvalType opCall(EvalType[Vars.length] evalPoint...) const shared
    {
        return (cast(Evaluable)this).opCall(evalPoint);
    }
}

unittest
{
    import std.math : pow;
    import std.stdio : writefln;

    auto noVariables = Evaluable!int("2 + 3");
    assert(noVariables() == 5);

    auto overflowsInteger = Evaluable!ubyte("250 + 10");
    assertThrown!OverflowException(overflowsInteger());

    auto a = Evaluable!(float, "x", "y", "z")("2*2");
    assert(a(0, 1 ,2) == 4);
    assert(a(-1, 0.5, 3) == 4);

    auto b = Evaluable!(short, "x", "y")("x*y");
    assert(b(0, 0) == 0);
    assert(b(2, 2) == 4);
    assert(b(2, 6) == 12);

    auto c = Evaluable!(float, "x", "y")("1/x*4 + y");
    assert(c(1, 1) == 5);
    assert(c(2, 3) == 5);
    assert(c(4, 5) == 6);
    assert(c(8, 3) == 3.5f);
    assert(c(12, 7.5f) == 4 / 12.0f + 7.5f);

    auto c2 = Evaluable!(int, "x", "y")("(x + y) * x - 3 * 2 * y");
    assert(c2(2, 2) == (2 + 2) * 2 - 3 * 2 * 2);
    assert(c2(3, 5) == (3 + 5) * 3 - 3 * 2 * 5);

    auto e = Evaluable!(float, "x", "z")("x**(2*z)");
    assert(e(1.5f, 1.3f) == pow(1.5f, 2 * 1.3f));
    
    auto f = shared Evaluable!(float, "x")("x + 1");
    assert(f(2) == 3f);

    auto g = Evaluable!(short, "x")("x**x");
    assert(g(3) == 27);

    assertThrown!OverflowException(g(10));

    auto h = Evaluable!(byte, "x", "y")("x * y");
    assert(h(2, 3) == 6);
    
}

public class InvalidExpressionException : Exception
{
    mixin basicExceptionCtors;
}

public class OverflowException : Exception
{
    mixin basicExceptionCtors;
}

private enum isAlphaNumOrUnderscoreString(string s)
{
    foreach(char c; s)
        if(!c.isAlphaNum && c != '_')
            return false;

    return true;
} 
    
private enum isValidVariableName(string T) = 
    T[0].isAlpha &&
    isAlphaNumOrUnderscoreString(T);

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
