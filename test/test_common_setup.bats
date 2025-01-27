#!/usr/bin/env bash
# Filename: test/test_common_setup.bats

function setup {
    load 'test_helpers/_common_setup'
    _common_setup
}

@test "test case 1a: always passes && bats-core working" {
    run true
    [[ "$status" -eq 0 ]]
}

@test "test case 1b: always passes && bats-core+bats-assert" {
    run true
    assert_success
}

@test "test case 2: always passes in a subshell" {
    (
        run true
        assert_success
    )
}

@test "test case 3: subshell cleanup" {
    export TMPVAR="this"
    (
        # shellcheck disable=SC2030
        export TMPVAR="that"
        assert_equal "$TMPVAR" "that"
    )
    # shellcheck disable=SC2031
    assert_equal "$TMPVAR" "this"
}

@test "test case 4: bats-file" {
    TESTDIR="$(mktemp -d)"
    assert_exists "$TESTDIR"
    rm -dr "$TESTDIR"
    assert_not_exists "$TESTDIR"
}
