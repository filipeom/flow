//@flow
var React = require("react");

import type {ComponentType} from 'react';

export type Recipe<T> = (draft: T, state: $ReadOnly<T>) => void;
export type Mutate<T> = (recipe: Recipe<T>) => void;

type ConsumerRender<S> = (...S) => globalThis.React.Node;

type ProviderProps<T> = {|
  children: globalThis.React.Node,
  initialState?: T,
|};

export type Provider<T> = ComponentType<ProviderProps<T>>;

type GetReturnType = <T, S>((T) => S) => S;

type ConsumerProps<T, TSelect: $ReadOnlyArray<(T) => mixed>> = {|
  select?: TSelect,
  children?: ConsumerRender<{[K in keyof TSelect]: ReturnType<TSelect[K]>}>,
  render?: ConsumerRender<{[K in keyof TSelect]: ReturnType<TSelect[K]>}>,
|};

type Selector<T, R> = T => R;

export type Store<T> = {
  +Provider: Provider<T>,
  +Consumer: {
    <TSelect: $ReadOnlyArray<(T) => mixed> = $ReadOnlyArray<(T) => mixed>>(
      ConsumerProps<T, TSelect>,
    ): globalThis.React.Node,
    // Need the following to fake this as a functional component
    displayName?: ?string,
    propTypes?: any,
    contextTypes?: any,
  },
  +mutate: Mutate<T>,
  createSelector<R>(Selector<T, R>): Selector<T, R>,
};

declare var store : Store<number>;
<store.Consumer></store.Consumer>
