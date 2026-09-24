local baseMatcher = import 'matcher.libsonnet';

local equalMatcher(actual, expectation) = baseMatcher {
  satisfied: actual == expectation,
  positiveMessage: 'Expected ' + actual + ' to be ' + expectation,
  negativeMessage: 'Expected ' + actual + ' not to be ' + expectation,
};

local ltMatcher(actual, expectation) = baseMatcher {
  satisfied: actual < expectation,
  positiveMessage: 'Expected ' + actual + ' to be less than ' + expectation,
};

local leMatcher(actual, expectation) = baseMatcher {
  satisfied: actual <= expectation,
  positiveMessage: 'Expected ' + actual +
                   ' to be less than or equal to ' + expectation,
};

local gtMatcher(actual, expectation) = baseMatcher {
  satisfied: actual > expectation,
  positiveMessage: 'Expected ' + actual +
                   ' to be greater than ' + expectation,
};

local geMatcher(actual, expectation) = baseMatcher {
  satisfied: actual >= expectation,
  positiveMessage: 'Expected ' + actual +
                   ' to be greater than or equal to ' + expectation,
};

local thatMatcher(actual, expectation) = baseMatcher {
  satisfied: (
    if std.type(expectation) == 'function' then
      expectation(actual)
    else
      (expectation { actual: actual }).result
  ),
  positiveMessage: 'Expected ' + actual + ' to satisfy ' + self.description,
  description:: (
    if std.type(expectation) == 'function' then
      'the function'
    else
      local evaluation = expectation { actual: actual };
      if std.objectHas(evaluation, 'description') then
        evaluation.description
      else
        evaluation
  ),
};

{
  expect: {
    matcher: equalMatcher,
    expectationType: true,
  },
  expectNot: {
    matcher: equalMatcher,
    expectationType: false,
  },
  expectLt: {
    matcher: ltMatcher,
    expectationType: true,
  },
  expectLe: {
    matcher: leMatcher,
    expectationType: true,
  },
  expectGt: {
    matcher: gtMatcher,
    expectationType: true,
  },
  expectGe: {
    matcher: geMatcher,
    expectationType: true,
  },
  expectThat: {
    matcher: thatMatcher,
    expectationType: true,
  },
}
