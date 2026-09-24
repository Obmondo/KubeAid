local test = import 'jsonnetunit/test.libsonnet';

test.suite({
  testFailure: { actual: 1 + 1, expect: 3 },
})
