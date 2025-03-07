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

@test "Q3" {
    run assign_statements void
    assert_success
    assert_output -p "Invalid statement key: void"

    assign_statements s5 s6
    assert_equal "${STATEMENTS[s5]}" "Statement 5 executed"
    assert_equal "${STATEMENTS[s6]}" "Statement 6 executed"
}
