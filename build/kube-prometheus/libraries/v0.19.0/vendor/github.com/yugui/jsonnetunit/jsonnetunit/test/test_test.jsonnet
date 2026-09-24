local matcher = import 'jsonnetunit/matcher.libsonnet';
local test = import 'jsonnetunit/test.libsonnet';

local stubMatcher(actual, expected) = matcher {
  satisfied: true,
};

test.suite({
  testDummy: { actual: 'something', expectStub: 'something' },
}) {
  matchers+: {
    expectStub: {
      matcher: stubMatcher,
      expectationType: true,
    },
  },
}
