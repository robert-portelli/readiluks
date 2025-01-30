# Filename: test/integration/test_parser.bats

function setup {
    load '../lib/_common_setup'

    # Ensure we test the actual script
    SCRIPT_PATH="src/main.bash"

    _common_setup
}

@test "smoke test" {
    run true
    assert_success
}

@test "Valid --log-to-console sets config[LOG_TO_CONSOLE]=true" {
    run bash "$SCRIPT_PATH" --log-to-console
    assert_success
    assert_output -p "LOG_TO_CONSOLE=true"
}

#@test "Valid parse_arguments doesn't mutate default values" {
    # calling parser without args to parse skips the parser
    # so the parser can't return the default values set in src/main.bash
#}

@test "Valid --log-level <valid key> sets config[LOG_LEVEL]=<valid key>" {
    run bash "$SCRIPT_PATH" --log-level DEBUG
    assert_success
    assert_output -p "LOG_LEVEL=DEBUG"

    run bash "$SCRIPT_PATH" --log-level INFO
    assert_success
    assert_output -p "LOG_LEVEL=INFO"


    run bash "$SCRIPT_PATH" --log-level WARNING
    assert_success
    assert_output -p "LOG_LEVEL=WARNING"

    run bash "$SCRIPT_PATH" --log-level ERROR
    assert_success
    assert_output -p "LOG_LEVEL=ERROR"
}

@test "Missing argument after --log-level should fail" {
    run bash "$SCRIPT_PATH" --log-level
    assert_failure
    assert_output -p "Invalid log level: "
}

@test "Invalid --log-level value should fail" {
    run bash "$SCRIPT_PATH" --log-level INVALID
    assert_failure
    assert_output -p "Invalid log level: INVALID"
}

@test "Unknown flag should fail" {
    run bash "$SCRIPT_PATH" --unknown-flag
    assert_failure
    assert_output -p "Unknown option: --unknown-flag"
}

@test "Passing multiple valid arguments should succeed" {
    run bash "$SCRIPT_PATH" --log-level WARNING --log-to-console
    assert_success
    assert_output -p "LOG_LEVEL=WARNING"
    assert_output -p "LOG_TO_CONSOLE=true"
}

@test "Passing multiple valid log levels should fail" {
    run bash "$SCRIPT_PATH" --log-level WARNING ERROR
    assert_failure
    assert_output -p "Unknown option: ERROR"
}

@test "Valid --help prints usage and exits successfully" {
    run bash "$SCRIPT_PATH" --help
    assert_success
    assert_output -p "Usage: "
}
