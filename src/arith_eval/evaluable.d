///
module arith_eval.evaluable;

import arith_eval.exceptions;
import arith_eval.internal.eval;

import std.ascii;
import std.conv : to; 
import std.exception;
import std.experimental.checkedint : Checked, Throw;
import std.format;
import std.meta : allSatisfy, aliasSeqOf;
import std.string;
import std.traits : isNumeric, isIntegral, isFloatingPoint;

/// 
public immutable struct Evaluable(Vars...)
if (allSatisfy!(isValidVariableName, Vars))
{
    /// Expression this instance is set to evaluate
    string expr;

    /**
        Basic constructor of the type.

        Params: expr = expression this instance evaluates

        Throws: InvalidExpressionException if the expression cannot
                evaluated.
    */
    this(string expr)
    in
    {
        assert(expr !is null);
    }
    do
    {
        //TODO: perform runtime checking of variables in the expression

        enforce!InvalidExpressionException(isExpressionValid(expr), 
                        format("Expression \"%s\" cannot be evaluated.", expr));

        this.expr = expr;
    }

    /**
        Evaluates the expression.

        Returns: The value after evaluating the expression (at
                 the point specified by evalPoint, if the number
                 of variables is greater than 0).

        Throws: EvaluationException if an error, such as overflow,
                has occurred during the evaluation.
    */
    public EvalType eval(EvalType = float)(EvalType[Vars.length] evalPoint...) const
    if (isFloatingPoint!EvalType)
    {
        import std.range : iota;
        string replacedExpr = expr;

        foreach(i; aliasSeqOf!(iota(0, Vars.length)))
        {
            import std.array : replace;
            replacedExpr = replacedExpr.replace(Vars[i], to!string(evalPoint[i]));
        }
        
        try
        {
            import std.math : approxEqual;

            immutable EvalType evaluation = evalExpr!EvalType(replacedExpr);

            if (evaluation.approxEqual(EvalType.max) || 
                evaluation.approxEqual(-EvalType.max) ||
                evaluation.approxEqual(EvalType.infinity) ||
                evaluation.approxEqual(-EvalType.infinity))
                    throw new Exception("Evaluation reached maximum possible value and is not reliable.");
            return evaluation;
        }
        catch(Exception e)
        {
            static if (Vars.length == 0)
                immutable string msg = format("Error evaluating expression \"%s\" for type %s.",
                                  expr, EvalType.stringof);
            else
                immutable string msg = format("Error evaluating expression \"%s\" for type %s " ~ 
                                  "on point '%s'.", expr, EvalType.stringof, to!string(evalPoint));
            throw new EvaluationException(msg, e);
        }
    }
}

// TESTS
version(unittest)
{
    import unit_threaded;

    @("Evaluable.__ctor does not throw for supported expressions")
    unittest
    {
        Evaluable!()("12.34").shouldNotThrow();
        Evaluable!()("-12.34").shouldNotThrow();
        Evaluable!()("12.34e10").shouldNotThrow();
        Evaluable!()("12.34e+10").shouldNotThrow();
        Evaluable!()("12.34e-10").shouldNotThrow();
        Evaluable!("foo")("foo").shouldNotThrow();
        Evaluable!()("1 + 2").shouldNotThrow();
        Evaluable!()("1 - 2").shouldNotThrow();
        Evaluable!()("1 * 2").shouldNotThrow();
        Evaluable!()("1 / 2").shouldNotThrow();
        Evaluable!()("1 ^ 2").shouldNotThrow();
    }

    @("Evaluable.__ctor throws for unsupported expressions")
    unittest
    {
        Evaluable!()("2**2").shouldThrow!InvalidExpressionException();
        Evaluable!("foo")("2foo").shouldThrow!InvalidExpressionException();
        Evaluable!("foo", "bar")("foo bar").shouldThrow!InvalidExpressionException();
    }

    @("Evaluable.eval() returns value of the expression according to arguments")
    unittest
    {
        auto noVariables = Evaluable!()("2 + 3");
        noVariables.eval().shouldEqual(5);

        auto oneVar = Evaluable!"x"("2*x");
        oneVar.eval(1f).shouldEqual(2);
        oneVar.eval(3f).shouldEqual(6);

        auto twoVars = Evaluable!("x", "y")("x + y");
        twoVars.eval(1f, 2f).shouldEqual(3);
        twoVars.eval(5f, 5f).shouldEqual(10);
    }

    @("Evaluable.eval() throws EvaluationException if evaluation reaches maximum value")
    unittest
    {
        auto simpleFunction = Evaluable!"x"("x");
        simpleFunction.eval(float.max).shouldThrow!EvaluationException();

        auto add1 = Evaluable!"x"("x + 1");
        add1.eval(float.max).shouldThrow!EvaluationException();

        auto oneOverZero = Evaluable!()("1 / 0");
        oneOverZero.eval().shouldThrow!EvaluationException();
    }
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

version(unittest)
{
    import unit_threaded;

    @("Variable names can only be programming variable identifiers")
    unittest
    {
        isValidVariableName!"x".shouldBeTrue();
        isValidVariableName!"HeLlO_w0rLd".shouldBeTrue();
        isValidVariableName!"9unicorns".shouldBeFalse();
        isValidVariableName!"hello world".shouldBeFalse();
    }
}

