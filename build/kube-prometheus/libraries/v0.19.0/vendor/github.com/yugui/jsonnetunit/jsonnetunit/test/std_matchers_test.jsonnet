local test = import 'jsonnetunit/test.libsonnet';

test.suite({
  testExpectNull: { actual: null, expect: null },
  testExpectBool: { actual: true, expect: true },
  testExpectString: { actual: 'str', expect: 'str' },
  testExpectNumber: { actual: 1, expect: 1 },
  testExpectArray: {
    actual: [null, true, 'str', 1],
    expect: [null, true, 'str', 1],
  },
  testExpectObject: {
    actual: { a: null, b: true, c: 'str', d: 1 },
    expect: { a: null, b: true, c: 'str', d: 1 },
  },
} + {
  testExpectNotNull: { actual: 1, expectNot: null },
  testExpectNotStringInt: { actual: '1', expectNot: 1 },
  testExpectNotBoolInt: { actual: true, expectNot: 1 },
  testExpectNotArray: {
    actual: [1, 2, 3],
    expectNot: [1, 4, 3],
  },
  testExpectNotObject: {
    actual: { a: 1, b: 2, c: 3 },
    expectNot: { a: 1, b: 4, c: 3 },
  },
} + {
  testExpectLt: {
    actual: 1,
    expectLt: 2,
  },
  testExpectLe: {
    actual: 1,
    expectLe: 2,
  },
  testExpectLeEq: {
    actual: 1,
    expectLe: 1,
  },
  testExpectGt: {
    actual: 2,
    expectGt: 1,
  },
  testExpectGe: {
    actual: 2,
    expectGe: 1,
  },
  testExpectGeEq: {
    actual: 2,
    expectGe: 2,
  },
} + {
  testExpectThatFunction: {
    actual: 1,
    expectThat: function(actual) actual == 1,
  },
  testExpectThatObject: {
    actual: 1,
    expectThat: {
      actual: error 'to be provided',
      result: self.actual == 1,
    },
  },
})
