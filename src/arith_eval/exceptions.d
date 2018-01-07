/// Exceptions used by ArithEval
module arith_eval.exceptions;

import std.exception;

///
public class InvalidExpressionException : Exception
{
    mixin basicExceptionCtors;
}

///
public class EvaluationException : Exception
{
    mixin basicExceptionCtors;
}