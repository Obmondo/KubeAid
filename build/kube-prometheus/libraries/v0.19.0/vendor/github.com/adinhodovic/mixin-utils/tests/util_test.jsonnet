// Test that utils.libsonnet can be imported correctly
local utils = import '../utils.libsonnet';

local tests = {
  testUtilsHasExpectedKeys: {
    result: std.objectHas(utils, 'dashboards'),
    expected: true,
  },
  testDashboardsIsObject: {
    result: std.isObject(utils.dashboards),
    expected: true,
  },
};

// Run tests and verify all pass
local allTestsPass = std.all([
  tests[key].result == tests[key].expected
  for key in std.objectFields(tests)
]);

if allTestsPass then
  {
    success: true,
    message: 'All utils.libsonnet tests passed',
    tests: std.length(std.objectFields(tests)),
  }
else
  error 'Some tests failed: ' + std.toString([
    key
    for key in std.objectFields(tests)
    if tests[key].result != tests[key].expected
  ])
