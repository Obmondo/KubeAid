# Developement

## Running tests

1. install helm unittest plugin:
    ```bash
    helm plugin install https://github.com/helm-unittest/helm-unittest.git
    ```
2. run tests:
    ```bash
    helm unittest .
    ```

## Setting Up Your Build Pipeline

To enable the build pipeline in your forked project, you'll need to configure a runner token and add build environment variables.

### Step 1: Create a Runner Token

1. Navigate to Project > Settings > CI/CD > Runners
2. Select Create a new runner
3. Copy the generated token (beginning with `glrt-`)

### Step 2: Add Authentication Variables

1. Go to Project > Settings > CI/CD > Variables
2. Create a new variable with either `TOKEN` or `AUTHENTICATION_TOKEN` as the key
3. Paste your runner token as the value
4. Check the Masked checkbox to protect the token in logs
5. Leave Protected unchecked (unless you need environment-specific restrictions)

### Result
Your pipeline is now ready to run smoke tests with valid runner token.
