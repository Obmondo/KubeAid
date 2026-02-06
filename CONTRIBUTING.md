# Contributing to KubeAid

First off, thank you for considering contributing to KubeAid! It's people like you that make Obmondo's open-source tools such a great ecosystem.

##  Legal: Developer Certificate of Origin (DCO)
To legally protect the project and its users, we require all contributions to be "signed off". By signing off your commits, you certify that you wrote the patch or have the right to pass it on as an open-source patch.

- You can sign your commit automatically with Git:
  `git commit -s -m "feat: add new provider"`

##  How to Contribute

### 1. Reporting Bugs
- **Search existing issues** to avoid duplicates.
- **Open a new Issue** using the "Bug Report" template.
- Include the **KubeAid version**, **Kubernetes version**, and **steps to reproduce**.

### 2. Pull Request (PR) Process
1.  **Fork** the repository to your own GitHub account.
2.  **Clone** the project to your machine.
3.  **Create a branch** locally with a succinct name (e.g., `feat/add-azure-support`).
4.  **Commit changes** to your own branch.
5.  **Push** your work back up to your fork.
6.  Submit a **Pull Request** to the `main` branch.

### 3. Style Guide & Standards
- **Go Code:** Must be formatted with `gofmt`.
- **Commit Messages:** We follow [Conventional Commits](https://www.conventionalcommits.org/).
  - `fix:` for bug fixes
  - `feat:` for new features
  - `docs:` for documentation changes
  - `chore:` for maintenance (dependencies, etc.)

##  Development Setup

### Prerequisites
- **Go**: Version 1.22 or newer.
- **Docker**: For running local container tests.

### Build & Test Commands
```bash
# Clone the repo
git clone [https://github.com/Obmondo/KubeAid.git](https://github.com/Obmondo/KubeAid.git)
cd KubeAid

# Install dependencies
go mod tidy

# Build all binaries
go build ./...

# Run the full test suite
go test ./...
