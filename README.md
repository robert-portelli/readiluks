# Readiluks - Automated LUKS Management

## 💜 Overview
**Readiluks** is a Bash-based utility designed to manage **LUKS-encrypted containers** given a block device identifier (UUID or label). It is built with **security, automation, and reproducibility** in mind, ensuring encrypted storage can be **reliably** and **efficiently** accessed and tested.

This project is rigorously tested using **Docker-in-Docker (DinD)** to provide a controlled testing environment that eliminates dependencies on the host system.

## 🛠️ Features
- 🔐 **Automated LUKS Management** → Works with **user-supplied** LUKS containers (no destructive actions).
- 🏠 **Modular & Maintainable Codebase** → Each function has **dedicated unit tests**.
- 💪 **Containerized Test Environment** → Ensures isolated and reproducible test runs using **Docker-in-Docker**.
- 🧪 **Comprehensive Testing Suite** → Supports **unit, integration, and workflow testing** using **BATS**.
- 📊 **Function-Level Testing** → Each core function (e.g., `create_device()`, `setup_luks()`) has **independent tests**.
- 💪 **Continuous Integration** → Designed for automation via **GitHub Actions**.

---

## 🚀 Getting Started

### 📌 Prerequisites
Ensure the following dependencies are installed:
- **Linux** (Tested on Arch Linux, but should be adaptable)
- **Docker** (With support for Docker-in-Docker)
- **BATS** (For running unit and integration tests)

---

### 🏠 Installation
#### Clone the repository
```bash
git clone https://github.com/robert-portelli/readiluks.git
cd readiluks
```

#### Build the test container
```bash
docker buildx build --load -t robertportelli/test-readiluks:latest -f docker/test/Dockerfile .
```

#### (Optional) Build the DinD container
```bash
docker buildx build --load -t test-readiluks-dind -f docker/test/Dockerfile.dind .
```
---
## 🧪 Running Tests
All tests are executed inside a Docker-in-Docker environment for isolation.

### 💮 Run a Unit Test
```bash
bash test/local_test_runner/runner.bash --test test_device_fixture/test_create_device
```

### 💮 Run All `test_device_fixture/` Tests
```bash
for test in test/local_test_runner/unit/test_device_fixture/*.bats; do
    bash test/local_test_runner/runner.bash --test "$test"
done
```

### 💮 Run an Integration Test
```bash
bash test/local_test_runner/runner.bash --test integration_test_parser
```

### 💮 Run a Test with Code Coverage
```bash
bash test/local_test_runner/runner.bash --test test_device_fixture/test_setup_luks --coverage
```

### 💮 Run a Workflow Test (GitHub Actions Simulation)
```bash
bash test/local_test_runner/runner.bash --test test_device_fixture/test_teardown_device --workflow
```

---

## 🏠 Project Structure

```bash
.
├── docker
│   └── test
│       ├── Dockerfile          # Defines the test container environment (Arch Linux + test dependencies)
│       └── Dockerfile.dind     # Defines the Docker-in-Docker (DinD) container for isolated testing
├── src
│   ├── lib
│   │   ├── _log_levels.bash    # Defines logging severity levels for standardized log output
│   │   ├── _logger.bash        # Implements logging functions for debugging and structured output
│   │   ├── _main_config.bash   # Holds main configuration settings for Readiluks execution
│   │   └── _parser.bash        # Parses command-line arguments and extracts LUKS device details
│   └── main.bash               # Main entry point for Readiluks, handling encryption setup and execution
└── test
    ├── integration
    │   └── test_parser.bats     # Integration test for argument parsing and validation
    ├── lib
    │   └── _common_setup.bash   # Shared setup functions for test environments
    ├── local_test_runner
    │   ├── lib
    │   │   ├── _device_fixture.bash       # Core device management functions
    │   │   ├── _docker-in-docker.bash     # Manages DinD container lifecycle
    │   │   ├── _nested-docker-cleanup.bash # Ensures cleanup of test containers
    │   │   ├── _parser.bash               # Parses test runner arguments
    │   │   ├── _run-in-docker.bash        # Executes requested tests inside nested test containers
    │   │   ├── _run-test.bash             # Manages execution flow for unit and integration tests
    │   │   └── _runner-config.bash        # Defines test environment settings and configurations
    │   ├── runner.bash            # Main test runner script, coordinating execution across test types
    │   └── unit
    │       └── test_device_fixture # Each function in `_device_fixture.bash` has **dedicated tests**
    │           ├── test_create_device.bats
    │           ├── test_format_filesystem.bats
    │           ├── test_setup_luks.bats
    │           ├── test_setup_lvm.bats
    │           ├── test_teardown_device.bats
    └── unit
        ├── test_common_setup.bats # Unit test for shared test setup functions
        └── test_parser.bats       # Unit test for parser functionality and argument validation
```

---

## 🛠️ Development Workflow

💮 Standard Test Execution
1) Each function in `_device_fixture.bash` has its **own test file**.
2) Run function-specific tests individually or all at once.
3) **Tests must pass before merging PRs.**

💮 GitHub Actions Integration
- The project runs workflow-based testing using **act**.
- PRs should pass all function tests before merging.

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
