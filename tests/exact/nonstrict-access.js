type T = {|
  all: string,
  some: string,
|} | {|
  all: string,
  some: string,
|} | {|
  all: string,
|};


{
  declare const x: T;

  // Prop access
  (x.all: string); // OK
  (x['all']: string); // OK
  (x.some: string); // ERROR
  (x['some']: string); // ERROR
  (x.some: string | void); // OK
  (x['some']: string | void); // OK
  (x.NONE); // ERROR
  (x['NONE']); // ERROR

  // Destructuring
  const {all, some} = x;
  (all: string); // OK
  (some: string); // ERROR
  (some: string | void); // OK

  const {NONE} = x; // ERROR
}

// Object literals are exact
{
  declare const cond: boolean;
  const toSpread = cond ? {all: "foo"} : {all: "foo", some: "bar"};
  const obj = {
    ...toSpread,
    baz: 2,
  };

  // Prop access
  (obj.all: string); // OK
  (obj.baz: number); // OK
  (obj.some: string | void); // OK
  (obj.some: string); // ERROR

  // Destructuring
  const {all, some, baz} = obj;
  (all: string); // OK
  (baz: number); // OK
  (some: string | void); // OK
  (some: string); // ERROR
}

// Intersection
{
  // It should not be possible to create such an object (intersection of
  // different exact objects), but unfortunately we have many instances
  // of this (e.g. React props) that exist due to other unsoundness issues.
  declare const o: {|a: number|} & {|b: string|};

  // Prop access
  (o.a: number); // OK
  (o.b: string); // OK

  const {a, b} = o;
  (a: number); // OK
  (b: string); // OK
}

// Computed with union
{
  declare const Foo:{
    foo: 1,
    bar: 2,
  };
  type K = 'foo' | 'bar' | 'xxx';
  declare const k: K;

  Foo[k]; // ERROR: prop-missing
}
