# Filename: test/unit/test_parser.bats

function setup {
    load '../lib/_common_setup'
    # Load the argument parser
    source src/lib/_parser.bash
    # Load the log levels
    source src/lib/_log_levels.bash
    # Log the config
    source src/lib/_main_config.bash

    _common_setup
}

@test "smoke test" {
    run true
    assert_success
}

@test "--log-format sets valid value in _main_config" {
    run parse_arguments --log-format human
    assert_success
    assert_output -p "LOG_FORMAT=human"
}

@test "--log-format prevents invalid values in _main_config" {
    run parse_arguments --log-format invalid
    assert_failure
    assert_output -p "Invalid value for --log-format: 'invalid'"
}

@test "--log-format requires valid value if passed" {
    run parse_arguments --log-format
    assert_failure
    assert_output -p "Invalid value for --log-format"
}

@test "--log-format normalizes valid values" {
    run parse_arguments --log-format hUmAN
    assert_success
    assert_output -p "LOG_FORMAT=human"

    run parse_arguments --log-format JSon
    assert_success
    assert_output -p "LOG_FORMAT=json"
}

@test "--log-format does not normalize invalid values" {
    run parse_arguments --log-format iNVAliD
    assert_failure
    assert_output -p "ERROR: Invalid value for --log-format: 'iNVAliD'."
}

@test "--log-format can be passed with other valid flags" {
    run parse_arguments --log-format human --log-to-console --log-level WARNING
    assert_success
    assert_output -p "LOG_FORMAT=human"
    assert_output -p "LOG_TO_CONSOLE=true"
    assert_output -p "LOG_LEVEL=WARNING"
}

@test "--log-format uses last provided value" {
    run parse_arguments --log-format human --log-format json
    assert_success
    assert_output -p "LOG_FORMAT=json"
}

@test "--log-to-console sets config[LOG_TO_CONSOLE]=true" {
    parse_arguments --log-to-console
    assert_equal "${config[LOG_TO_CONSOLE]}" "true"
}

@test "Valid parse_arguments doesn't mutate default values" {
    parse_arguments
    assert_equal "${config[LOG_TO_CONSOLE]}" "false"
    assert_equal "${config[LOG_LEVEL]}" "INFO"
    assert_equal "${config[LOG_FORMAT]}" "json"
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
