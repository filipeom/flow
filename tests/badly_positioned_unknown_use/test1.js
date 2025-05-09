import * as React from 'react';

declare export function foo<P>(
  Component: React.ComponentType<{|...P|}>,
): React.ComponentType<P>;

class Comp extends React.Component<{}, {}> {}

function f<
  Comp: React.ComponentType<{}>,
>(): Comp => {
} {
  return function() {
    return {}
  };
}

// Error: inexact from foo vs exact from f
var x = f<React.ComponentType<{}>>()(foo(Comp));
