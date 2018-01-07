# ArithEval

**ArithEval** is a minimal arithmetic expression evaluator library for the D programming language. In other words, define a math function as a string depending on as many variables as you want (including none), then evaluate that function giving those variables the values you want. It is **NOT** designed
to be efficient, just easy to use. Bear this in mind if your application requires time-sensitive evaluations.

This library is licensed under the terms of the [GNU GPL3](https://www.gnu.org/licenses/gpl-3.0.html) free software license. Free as in freedom. Also as in free beer. Also as in gluten-free. (*Warning: beer might not be gluten-free*)

Currently, ArithEval uses [Pegged](https://github.com/PhilippeSigaud/Pegged) as its base for parsing math expressions, although this might change in the future.

# How to use

Minimal the library, minimal the tutorial, really. Just instance the `Evaluable` struct from the `arith_eval` package and define your function:

```d
import arith_eval;

auto constantExpression = Evaluable!()("2 + 5");
assert(constantExpression() == 7);

auto a = Evaluable!("x", "y")("(x + y) * x - 3 * 2 * y");
assert(a.eval(2, 2) == (2 + 2) * 2 - 3 * 2 * 2);
assert(a.eval(3, 5) == (3 + 5) * 3 - 3 * 2 * 5);

auto b = Evaluable!("x", "z")("x ^ (2 * z)");
assert(b.eval(1.5f, 1.3f).approxEqual(1.5f ^^ (2 * 1.3f));
```

`Evaluable` is a struct template that takes the name of its variables as its template parameters.

`Evaluable` will throw an `InvalidExpressionException` if it isn't able to understand the expression given, and an `EvaluationException` if something wrong happens during evaluation, such as the value reaching unreliably high values.

Note that currently *ArithEval* will not check your expressions for variables not specified in the template, and using those should be considered an error, so please be extra careful in that aspect. I'll implement the checking once I have some time.

# Supported operations

Currently, supported math operations are the following:

- `x + y`
- `x - y`
- `- x`
- `x * y`
- `x / y`
- `x ^ y` (`x` to the power of `y`)
- `x E y` (`x` times `10` to the power of `y`)

Parenthesis should work wherever you place them, respecting basic math operation priorities.

If you are missing a specific operation, open an issue or submit a PR.

# Add as DUB dependency

Just add the `arith-eval` package as a dependency in your *dub.json* or *dub.sdl* file. For example:

```json
"dependencies" : {
        "arith-eval": "~>0.5.0"
}
```
