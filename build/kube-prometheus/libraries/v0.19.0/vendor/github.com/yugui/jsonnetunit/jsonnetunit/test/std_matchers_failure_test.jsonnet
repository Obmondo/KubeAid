local test = import 'jsonnetunit/test.libsonnet';

test.suite({
  testEq: { actual: 1, expect: 2 },
  testNe: { actual: 1, expectNot: 1 },

  testLt: { actual: 2, expectLt: 1 },
  testLtEq: { actual: 2, expectLt: 2 },
  testLe: { actual: 2, expectLe: 1 },

  testGt: { actual: 1, expectGt: 2 },
  testGtEq: { actual: 1, expectGt: 1 },
  testGe: { actual: 1, expectGe: 2 },

  testThatFunction: {
    actual: 1,
    expectThat: function(actual) actual == 2,
  },
  testThatObject: {
    actual: 1,
    expectThat: {
      actual: error 'to be provided',
      result: self.actual == 2,
    },
  },
  testThatObjectDesc: {
    actual: 1,
    expectThat: {
      actual: error 'to be provided',
      result: self.actual == 2,
      description: 'the condition that the value is 2',
    },
  },
})
