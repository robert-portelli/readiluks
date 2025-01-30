# Filename: test/unit/test_parser.bats

function setup {
    load '../lib/_common_setup'
    # Load the argument parser
    source src/lib/parse_prod_args.bash

    _common_setup

    # Mock log levels to prevent undefined key errors
    declare -gA LOG_LEVELS=(
        [DEBUG]=1
        [INFO]=2
        [WARNING]=3
        [ERROR]=4
    )

    # Declare a fresh config array before each test
    declare -gA config=(
        [LOG_LEVEL]="INFO"
        [LOG_TO_CONSOLE]=false
    )
}

function teardown {
    declare -gA config=(
        [LOG_LEVEL]="INFO"
        [LOG_TO_CONSOLE]=false
    )
}

@test "smoke test" {
    run true
    assert_success
}

@test "Valid --log-to-console sets config[LOG_TO_CONSOLE]=true" {
    parse_arguments --log-to-console
    assert_equal "${config[LOG_TO_CONSOLE]}" "true"
}

@test "Valid parse_arguments doesn't mutate default values" {
    parse_arguments
    assert_equal "${config[LOG_TO_CONSOLE]}" "false"
    assert_equal "${config[LOG_LEVEL]}" "INFO"
}

@test "Valid --log-level <valid key> sets config[LOG_LEVEL]=<valid key>" {
    parse_arguments --log-level DEBUG
    assert_equal "${config[LOG_LEVEL]}" "DEBUG"

    parse_arguments --log-level INFO
    assert_equal "${config[LOG_LEVEL]}" "INFO"

    parse_arguments --log-level WARNING
    assert_equal "${config[LOG_LEVEL]}" "WARNING"

    parse_arguments --log-level ERROR
    assert_equal "${config[LOG_LEVEL]}" "ERROR"
}

@test "Missing argument after --log-level should fail" {
    run parse_arguments --log-level
    assert_failure
    assert_output -p "Invalid log level: "
}

@test "Invalid --log-level value should fail" {
    run parse_arguments --log-level INVALID
    assert_failure
    assert_output -p "Invalid log level: INVALID"
}

@test "Unknown flag should fail" {
    run parse_arguments --unknown-flag
    assert_failure
    assert_output -p "Unknown option: --unknown-flag"
}

@test "Passing multiple valid arguments should succeed" {
    parse_arguments --log-level WARNING --log-to-console
    assert_equal "${config[LOG_LEVEL]}" "WARNING"
    assert_equal "${config[LOG_TO_CONSOLE]}" "true"
}

@test "Passing multiple valid log levels should fail" {
    run parse_arguments --log-level WARNING ERROR
    assert_failure
    assert_output -p "Unknown option: ERROR"
}

@test "Valid --help prints usage and exits successfully" {
    run parse_arguments --help
    assert_success
    assert_output -p "Usage: "
}
