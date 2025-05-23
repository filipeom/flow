---
title: Const Expressions
slug: /types/const-expression
---

Sometimes it is useful to specify that a literal expression is expected to be immutable.
In such cases, you can annotate the expression with the `as const` modifier. We
refer to these expressions as const-expressions.

## Typing for Const Expressions {#toc-const-expression-typing}

The inferred type of const-expressions is the [singleton type](../literals) for primitive values
and the read-only versions for container types. Array literals are inferred as tuple types.

Here are some examples of primitive values:
```js
42 as const; // inferred type is 42

"hello" as const; // inferred type is "hello"
```

Containers become read-only and the modifier is applied deeply
```js
{ f: 42 } as const; // {+f: 42}

[42, "hello"] as const; // $ReadOnly<[42, "hello"]>

{ f: { g: 42 } } as const; // {+f: {+g: 42}}
```

Note that the effect of the modifier does not persist through variables. For example
in
```js
const nonConstObject = { g: 42 };
const constObject = { f: nonConstObject } as const;
```
the type of `nonConstObject` will be `{g: number}` and the type of `constObject` will
be `{+f: {g: number}}`. In other words, only the top-level property `prop` will
be read-only.

Finally, it is an error to apply `as const` to non-literal expressions:
```js flow-check
const x = 1;
const y = x as const;
```

## Typical const-expression example {#toc-const-expression-example}

A common pattern where const-expressions are useful is in enum-like
structures that are not expected to be mutated. For example
```js
export const STATUS = {
  INIT: 'INIT',
  LOADING: 'LOADING',
  SUCCESS: 'SUCCESS',
  ERROR: 'ERROR',
} as const;
```
The type of `STATUS.INIT` is `"INIT"`, the type of `STATUS.LOADING` is `"LOADING"` and so on.

With this definition it is also possible to effectively lift the values of the various fields
to type annotations. For example
```js
type State =
  | { +kind: typeof STATUS.INIT; }
  | { +kind: typeof STATUS.LOADING; progress: number; }
  | { +kind: typeof STATUS.SUCCESS; result: string; }
  | { +kind: typeof STATUS.ERROR; msg: string; };
```
Without the use of `as const` the type `typeof STATUS.INIT` would be `string`, which
would make it unsuitable as a distinguishing tag in a disjoint union.

## Adoption of `as const` syntax
To use the `as const` syntax, you need to upgrade your infrastructure:
- Flow and Flow Parser: 0.256+
- Prettier: 3.1+
- Babel: use the [babel-plugin-syntax-hermes-parser](https://www.npmjs.com/package/babel-plugin-syntax-hermes-parser) plugin version 0.19+, see our [Babel guide](../../tools/babel) for more details.
- ESLint: use [hermes-eslint](https://www.npmjs.com/package/hermes-eslint) plugin version 0.19+, see our [ESLint guide](../../tools/eslint) for more details.
