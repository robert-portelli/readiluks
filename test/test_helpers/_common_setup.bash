#!/usr/bin/env bash
# Filename: test/test_helpers/_common_setup.bash

_common_setup() {
    load '/usr/lib/bats/bats-support/load.bash'
    load '/usr/lib/bats/bats-assert/load.bash'
    load '/usr/lib/bats/bats-file/load.bash'
    # Set LANG to C for consistent behavior across environments
    export LANG=C
    # get the containing directory of this file
    # use $BATS_TEST_FILENAME instead of ${BASH_SOURCE[0]} or $0,
    # as those will point to the bats executable's location or the preprocessed file respectively
    PROJECT_ROOT="$( cd "$( dirname "$BATS_TEST_FILENAME" )/.." >/dev/null 2>&1 && pwd )"
    # make executables in src/ visible to PATH
    PATH="$PROJECT_ROOT/src:$PATH"
}
