# ==============================================================================
# Filename: test/local_test_runner/lib/_runner-config.bash
# ------------------------------------------------------------------------------
# Description:
#   Defines global configuration variables for the local test runner, ensuring
#   consistent paths, image names, and test execution settings.
#
# Purpose:
#   - Centralizes key environment variables used across test execution scripts.
#   - Standardizes test execution options (unit, integration, workflow, coverage).
#   - Manages Docker-in-Docker (DinD) setup for isolated testing.
#   - Provides a single source of truth for image and container names.
#   - Defines the **inner test container** (`robertportelli/readiluks-inner-harness:latest`)
#     built from `docker/test/Dockerfile.inner-harness-harness`.
#   - Defines the **outer DinD container** (`test-readiluks-outer`) with customizations
#     from `docker/test/Dockerfile.outer`.
#
# Options:
#   This script does not accept command-line options. It is sourced by the test
#   runner and its functions.
#
# Usage:
#   Source this script in test execution scripts to access global configuration:
#   source "$BASEDIR/test/local_test_runner/lib/_runner-config.bash"
#
# Example(s):
#   # Access the base directory of the repository
#   echo "Repo Base Directory: ${CONFIG[BASE_DIR]}"
#
#   # Retrieve the test image name
#   echo "Using Docker image: ${CONFIG[HARNESS_IMAGE]}"
#
#   # Check if workflow mode is enabled
#   if [[ "${CONFIG[WORKFLOW]}" == "true" ]]; then
#       echo "Executing workflow test..."
#   fi
#
# Requirements:
#   - Must be sourced by other scripts (not executable).
#   - Assumes a Docker-based testing environment.
#
# Author:
#   Robert Portelli
#   Repository: https://github.com/robert-portelli/readiluks
#
# Version:
#   See repository tags or release notes.
#
# License:
#   See repository license file (e.g., LICENSE.md).
#   See repository commit history (e.g., `git log`).
# ==============================================================================


declare -gA CONFIG=(
    [BASE_DIR]="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
    [HARNESS_IMAGE]="robertportelli/readiluks-inner-harness:latest"
    [SYSTEMD_IMAGE]="robertportelli/readiluks-inner-systemd:latest"
    [SYSTEMD_CONTAINER]="inner-sysd"
    [ACT_MAPPING]="ubuntu-latest=${CONFIG[HARNESS_IMAGE]}"
    [TEST]=""
    [COVERAGE]=false
    [WORKFLOW]=false
    [BATS_FLAGS]=""
    [OUTER_DOCKERFILE]="docker/test/Dockerfile.outer"
    [OUTER_IMAGE]="test-readiluks-outer"
    [OUTER_CONTAINER]="test-readiluks-outer-container"
)

#    [TEST_FILE_SIZE]="1024M"
#    [TEST_FILE]="" # set by _run-inner-harness.bash
#    [TEST_DEVICE]="" # set by _run-inner-harness.bash
