local v = importstr '../VERSION';
local persesOperator = import 'perses-operator.libsonnet';

// Define the configuration for the perses operator
local config = {
  namespace: 'perses-dev',
  version: 'v' + std.strReplace(v, '\n', ''),
  resources: {
    limits: { cpu: '500m', memory: '128Mi' },
    requests: { cpu: '10m', memory: '64Mi' },
  },
};

// Generate all manifests
persesOperator(config)
