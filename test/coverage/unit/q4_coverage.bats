function setup {
    load '../../lib/_common_setup'
    source test/coverage/lib/_coverage_fixture.bash
    _common_setup
}

@test "BATS is setup correctly - smoke test" {
    run true
    assert_success
    mkdir '/tmp/test'
    assert [ -e "/tmp/test" ]
    assert [ -d "/tmp/test" ]
    refute [ -f "/tmp/test" ]
    rm -d /tmp/test
}

@test "Q4" {
    run assign_statements void
    assert_output "Invalid statement key: void"

    assign_statements s7 s8
    assert_equal "${STATEMENTS[s7]}" "Statement 7 executed"
    assert_equal "${STATEMENTS[s8]}" "Statement 8 executed"
}
