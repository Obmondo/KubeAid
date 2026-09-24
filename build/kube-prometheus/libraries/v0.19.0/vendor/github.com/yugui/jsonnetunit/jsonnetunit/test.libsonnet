local stdMatchers = import 'std_matchers.libsonnet';

local testCase(matchers, name, spec) = (
  local candidates = [
    {
      name: name,
      matcher: matchers[matcherName].matcher(spec.actual, spec[matcherName]),
      expectationType: matchers[matcherName].expectationType,
    }
    for matcherName in std.objectFields(matchers)
    if std.objectHas(spec, matcherName)
  ];
  if std.length(candidates) == 0 then
    error 'Unrecognized spec ' + spec + ' '
  else if std.length(candidates) > 1 then
    error 'Ambiguous expectation in spec ' + spec
  else
    candidates[0]
);

local suite(tests) = {
  matchers:: stdMatchers,

  result:: [
    testCase(self.matchers, t, tests[t])
    for t in std.objectFields(tests)
    if std.startsWith(t, 'test')
  ],

  verify: (
    local failures = [
      tc
      for tc in self.result
      if !tc.matcher.matches(tc.expectationType)
    ];
    if std.length(failures) > 0 then
      local message = 'Failed %d/%d test cases:\n' % [
        std.length(failures),
        std.length(self.result),
      ] + std.join('\n', [
        '%s: %s' % [tc.name, tc.matcher.message(tc.expectationType)]
        for tc in failures
      ]);
      error message
    else
      'Passed %d test cases' % std.length(self.result)
  ),
};

{
  suite: suite,
}
