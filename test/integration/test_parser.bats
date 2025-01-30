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
