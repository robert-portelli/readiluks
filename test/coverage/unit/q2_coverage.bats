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

@test "Q2" {
    run assign_statements
    assert_success

    assign_statements s3 s4
    assert_equal "${STATEMENTS[s3]}" "Statement 3 executed"
    assert_equal "${STATEMENTS[s4]}" "Statement 4 executed"
}
