module aritheval.evaluable;

import std.meta;

import pegged.examples.arithmetic;

public struct Evaluable(Vars...)
if(allSatisfy!(isValidVariableName, Vars))
{
    immutable string expr;

    this(string expr)
    {
        this.expr = expr;
    }

    pragma(msg, "Inst with "~Vars.length~" values");
    public float eval(float[Vars.length] evalPoint...)
    {

    }
}

@pure
private bool isValidVariableName(string T)()
{
    return ;
}
unittest
{
    assert(isValidVariableName("x"));
    assert(isValidVariableName("HelLooOO"));
}
