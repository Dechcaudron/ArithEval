module arith_eval.internal.eval;

import pegged.grammar;
import std.traits;
import std.conv;

package (arith_eval) mixin(grammar(`
Arithmetic:
    Term     < Factor (Add / Sub)*
    Add      < "+" Factor
    Sub      < "-" Factor
    Factor   < Primary (Exp10 / Mul / Div)*
    Exp10    <- [eE] Primary
    Pow      < Primary "^" Primary
    Mul      < "*" Primary
    Div      < "/" Primary
    Primary  < Parens / Neg / Pos / Pow / Number / Variable
    Parens   < "(" Term ")"
    Neg      < "-" Primary
    Pos      < "+" Primary
    Number   <- ~([0-9]+ ('.' [0-9]+)?)

    Variable <- identifier
`));

package (arith_eval) bool isExpressionValid(string s)
in
{
    assert(s !is null);
}
do
{
    auto parseTree = Arithmetic(s);
    return parseTree.begin == 0 && parseTree.end == s.length;
}

package(arith_eval) T evalExpr(T)(string expr)
if (isFloatingPoint!T)
{
    import std.math : pow;

    auto p = Arithmetic(expr);

    T value(ParseTree p)
    {
        switch (p.name)
        {
            case "Arithmetic":
                return value(p.children[0]);
            case "Arithmetic.Whole":
                return value(p.children[0]);
            case "Arithmetic.Term":
                T v = 0;
                foreach(child; p.children) v += value(child);
                return v;
            case "Arithmetic.Add":
                return value(p.children[0]);
            case "Arithmetic.Sub":
                return -value(p.children[0]);
            case "Arithmetic.Factor":
                T v = 1;
                foreach(child; p.children) v *= value(child);
                return v;
            case "Arithmetic.Exp10":
                return 10 ^^ value(p.children[0]);
            case "Arithmetic.Pow":
                return value(p.children[0]) ^^ value(p.children[1]);
            case "Arithmetic.Mul":
                return value(p.children[0]);
            case "Arithmetic.Div":
                return 1/value(p.children[0]);
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

// TESTS
version(unittest)
{
    import unit_threaded;

    @("Evaluation of literal expressions works as expected")
    unittest
    {
        evalExpr!float("12").shouldApproxEqual(12);
        evalExpr!float("12.34").shouldApproxEqual(12.34f);
        evalExpr!float("-12.34").shouldApproxEqual(-12.34f);

        evalExpr!float("1 + 2 + 3").shouldApproxEqual(6);

        evalExpr!float("7 - 1 - 5").shouldApproxEqual(1);

        evalExpr!float("7 - (1 - 5)").shouldApproxEqual(11);

        evalExpr!float("2 * 3 * 4").shouldApproxEqual(24);

        evalExpr!float("6 / 12").shouldApproxEqual(0.5f);
        evalExpr!float("6 / (12 / 2)").shouldApproxEqual(1);

        evalExpr!float("1.56^3.28").shouldApproxEqual(1.56f ^^ 3.28f);
        evalExpr!float("5^0").shouldApproxEqual(5^^0);
        //TODO: what should we return?
        //assert(evalExpr!float("0**0;") == float.nan);

        evalExpr!float("1e23").shouldApproxEqual(1e23);
        evalExpr!float("(1 + 2)e(3 + 4)").shouldApproxEqual(3e7);
    }
}
