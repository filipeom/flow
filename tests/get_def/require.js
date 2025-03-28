// @flow

require("Unknown");
//       ^

require("Unknown_LibDeclared");
//       ^

require("Untyped");
//       ^

require("Untyped_LibDeclared");
//       ^

require('test_lib');
//        ^

{
const Foo = require('test_lib');
//     ^
const {foo} = require('test_lib');
//      ^
const {foo: fooo} = require('test_lib');
//      ^
const {foo: boo} = require('test_lib');
//           ^
const {bar} = require('test_lib');
//      ^
const {bar: baaaar} = require('test_lib');
//      ^
const {bar: far} = require('test_lib');
//           ^
const {bar: {baz}} = require('test_lib');
//            ^
const {bar: {baz: boz}} = require('test_lib');
//                 ^
const {array: [arr_e]} = require('test_lib');
//              ^ ^
const {tuple: [tuple_e]} = require('test_lib');
//              ^
const {dict: {dynamic}} = require('test_lib');
//             ^
}

{
const {foo} = require('test_lib_cjs');
//      ^
const {foo: fooo} = require('test_lib_cjs');
//      ^
const {foo: boo} = require('test_lib_cjs');
//           ^
const {bar} = require('test_lib_cjs');
//      ^
const {bar: baaaar} = require('test_lib_cjs');
//      ^
const {bar: far} = require('test_lib_cjs');
//           ^
const {bar: {baz}} = require('test_lib_cjs');
//            ^
const {bar: {baz: boz}} = require('test_lib_cjs');
//                 ^
}
