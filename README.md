# Readiluks - Automated LUKS Management and Testing Suite

## 💜 Overview
**Readiluks** is a Bash-based utility designed to manage **LUKS-encrypted containers** given a block device identifier (UUID or label). It prioritizes **security, automation, and reproducibility**, ensuring encrypted storage can be **reliably** and **efficiently** accessed, tested, and deployed.

Readiluks is thoroughly tested using an **isolated Docker-in-Docker (DinD) environment**, which provides a clean and reproducible sandbox for validating complex storage workflows without impacting the host system.

---

## 🛠️ Features

- 🔐 **Automated LUKS Management**
  - Works with **user-supplied** LUKS containers (no destructive actions on host devices).
  - Handles LUKS2 container setup, opening, and management.

- 🏗️ **Dynamic Loopback Device & LVM Management**
  - Creates loopback devices, sets up LUKS, configures LVM (PV/VG/LV), and formats with Btrfs (or custom filesystems).
  - Idempotent **setup and teardown** via a resource registry file.

- 🐳 **Fully Isolated Test Environment (Docker-in-Docker)**
  - Outer DinD container manages inner nested test containers.
  - Completely decouples testing from the host environment.

- 🧪 **Comprehensive Test Suite**
  - Unit tests for each core function (e.g., `setup_luks()`, `teardown_device()`).
  - Integration tests for combined workflows.
  - Workflow tests simulate GitHub Actions via `act`.
  - `pytest-cov` style coverage reporting for Bash scripts:

    ```
    # bash test/local_test_runner/runner.bash --test test_device_fixture --coverage
    🔍 Running test_device_fixture_register_test_device...
    ✅ test_device_fixture_register_test_device completed in:                          2.917s
    🔍 Running test_device_fixture_setup_luks...
    ✅ test_device_fixture_setup_luks completed in:                                    3.310s
    🔍 Running test_device_fixture_setup_lvm...
    ✅ test_device_fixture_setup_lvm completed in:                                    20.963s
    🔍 Running test_device_fixture_format_filesystem...
    ✅ test_device_fixture_format_filesystem completed in:                            23.426s
    🔍 Running test_device_fixture_teardown_device...
    ✅ test_device_fixture_teardown_device completed in:                              26.018s

    ⏱️  Total Runtime:                                                               76.671s

    📊 Final Coverage Report:

    Name                            Stmts   Miss  Cover Missing
    ------------------------------ ------ ------ ------ ----------------
    _device_fixture.bash              178      1  99.44% 229
    ------------------------------ ------ ------ ------ ----------------
    ✅ No test container to clean up.
    ```

- 📊 **Code Coverage Support**
  - Integrated with `kcov` for coverage reports in SonarQube XML format.

- ⚙️ **Flexible CI/CD Ready**
  - GitHub Actions ready.
  - Workflow simulations with `act` before merging.

---

## 🚀 Getting Started

### 📌 Prerequisites
Ensure the following tools are installed on your **Linux** host (tested on Arch Linux):
- **Docker** (with DinD support)

The inner container includes:
- **BATS** (unit/integration testing)
- **kcov** (coverage analysis)
- **act** (optional: simulate GitHub Actions locally)

---

### 🏠 Installation
#### Clone the repository
```bash
git clone https://github.com/robert-portelli/readiluks.git
cd readiluks
```

#### Build and start the outer DinD container
```bash
docker buildx build --load -t test-readiluks-outer -f docker/test/Dockerfile.outer .
```

#### Build the inner test container
```bash
docker buildx build --load -t robertportelli/test-readiluks-inner:latest -f docker/test/Dockerfile.inner .
```
---
## 🧪 Running Tests
All tests are executed inside a Docker-in-Docker environment for isolation.

### 💮 Run a Unit Test
```bash
bash test/local_test_runner/runner.bash --test test_device_fixture_/test_register_test_device
````

### 💮 Run an Integration Test
```bash
bash test/local_test_runner/runner.bash --test integration_test_parser
```

### 💮 Run a Test with Code Coverage
```bash
bash test/local_test_runner/runner.bash --test test_device_fixture --coverage
```

### 💮 Run a Workflow Test (GitHub Actions Simulation)
```bash
bash test/local_test_runner/runner.bash --test test_parser --workflow
```

### 💮 Start an interactive nested container:
```
bash test/local_test_runner/runner.bash --test manual_nested_container
```

- note: manual container cleanup may be required


---

## 🏠 Project Structure

```bash
.
├── .github
│   └── workflows
│       ├── default-branch-protection.yaml    # Enforces branch protection on default branch
│       ├── non-default-branch-protection.yaml # Protects non-default branches
│       ├── solo-dev-pr-approve.yaml          # Approves PRs targeting solo-dev branches
│       ├── super-linter.yaml                 # Runs Super-Linter for code quality checks
│       ├── test_parser.yaml                  # CI for parser unit/integration tests
│       └── test_test_environment.yaml        # CI for test environment validation
├── .gitignore
├── .pre-commit-config.yaml
├── Makefile
├── README.md
├── docker
│   └── test
│       ├── Dockerfile.inner                  # Inner test container (Arch Linux + BATS + kcov + act)
│       └── Dockerfile.outer                  # Outer DinD container managing nested Docker
├── src
│   ├── lib
│   │   ├── _log_levels.bash                  # Log level definitions (DEBUG, INFO, etc.)
│   │   ├── _logger.bash                      # Logging functions
│   │   ├── _main_config.bash                 # Configuration file loader
│   │   └── _parser.bash                      # CLI argument parser for device identifiers
│   └── main.bash                             # Program entry point
└── test
    ├── coverage
    │   ├── lib
    │   │   └── _coverage_fixture.bash        # Helpers for coverage setup
    │   └── unit
    │       ├── q1_coverage.bats              # Coverage validation for Q1
    │       ├── q2_coverage.bats              # Coverage validation for Q2
    │       ├── q3_coverage.bats              # Coverage validation for Q3
    │       └── q4_coverage.bats              # Coverage validation for Q4
    ├── integration
    │   └── test_parser.bats                  # Parser integration test
    ├── lib
    │   └── _common_setup.bash                # Shared setup helpers
    ├── local_test_runner
    │   ├── lib
    │   │   ├── _device_fixture.bash         # Device lifecycle: loop -> LUKS -> LVM -> FS
    │   │   ├── _manage_outer_docker.bash    # Starts outer DinD container and loads test images
    │   │   ├── _nested-docker-cleanup.bash  # Cleans up nested containers inside DinD
    │   │   ├── _parser.bash                 # Parses test runner flags
    │   │   ├── _run-in-docker.bash          # Runs individual tests inside nested Docker
    │   │   ├── _run-test.bash               # Manages which tests run (unit, integration, workflow)
    │   │   └── _runner-config.bash          # Global CONFIG for tests
    │   ├── runner.bash                      # Orchestrates test executions
    │   └── unit
    │       └── test_device_fixture          # Dedicated tests for device fixture lifecycle
    │           ├── test_format_filesystem.bats
    │           ├── test_register_test_device.bats
    │           ├── test_setup_luks.bats
    │           ├── test_setup_lvm.bats
    │           └── test_teardown_device.bats
    └── unit
        ├── test_common_setup.bats           # Tests for _common_setup.bash
        └── test_parser.bats                 # Unit tests for parser logic
```

---

## 🛠️ Development Workflow

✅ Testing Strategy
- Every core function has dedicated BATS tests.
- Integration tests validate combined workflows (e.g., parser behavior with test devices).
- Code coverage is tracked using kcov.
- Workflow simulations via act for CI/CD compatibility.

✅ CI/CD
- GitHub Actions workflows run full test suites before PRs can be merged.
- Local workflow simulation (act) allows for pre-flight checks on CI jobs.

---

## 🤝 Contributing
Want to help improve Readiluks? Follow these steps:
1. Fork the repository on GitHub.
2. Create a feature branch:
```bash
git checkout -b feature/my-awesome-feature
```
3. Commit your changes:
```bash
git commit -m "feat: add new feature"
```
4. Push and open a pull request.

---

## 📄 License
This project is licensed under the MIT License. See LICENSE.md for details.

---

👤 Author
**Robert Portelli**
🔗 GitHub: [robert-portelli](https://github.com/robert-portelli)
