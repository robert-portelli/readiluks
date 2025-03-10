# shellcheck disable=SC2119,SC2030,SC2031

function setup {
    load '../../../lib/_common_setup'
    source "test/local_test_runner/lib/_device_fixture.bash"
    _common_setup
}

function teardown {
    teardown_device
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

@test "DEVCONFIG is initialized correctly" {
    # Expected keys and their default values
    declare -A expected_config=(
        [TEST_DEVICE]=""
        [LUKS_PW]="password"
        [LUKS_LABEL]="TEST_LUKS"
        [MAPPED_DEVICE]=""
        [VG_NAME]="vgtest"
        [LV_NAME]="lvtest"
        [MAPPED_LVM]=""
        [FS_TYPE]="btrfs"
        [MOUNT_POINT]="/mnt/target"
    )

    # Check that all expected keys exist in DEVCONFIG
    for key in "${!expected_config[@]}"; do
        assert [ -v "DEVCONFIG[$key]" ] # Check key existence
        assert_equal "${DEVCONFIG[$key]}" "${expected_config[$key]}" "Expected ${expected_config[$key]} but got ${DEVCONFIG[$key]} for key $key"
    done

    # Check that REG_FILE exists and is empty
    assert_exists "${DEVCONFIG[REG_FILE]}"
    assert_file_empty "${DEVCONFIG[REG_FILE]}"
}

@test "environment variable 'TEST_DEVICE' is a block device" {
    assert [ -b "$TEST_DEVICE" ]
}

@test "register_test_device() produces expected output" {
    run register_test_device
    assert_success
    refute_output -p "ERROR: $TEST_DEVICE is not a block device"
    assert_output -p "Found and registered loop device: ${DEVCONFIG[TEST_DEVICE]}"
}

@test "register_test_device() assigns env var TEST_DEVICE to array DEVCONFIG[TEST_DEVICE]" {
    register_test_device
    assert_equal "${DEVCONFIG[TEST_DEVICE]}" "$TEST_DEVICE"
}

@test "register_test_device() writes DEVCONFIG[TEST_DEVICE] to REG_FILE" {
    register_test_device
    assert_file_exists "${DEVCONFIG[REG_FILE]}"

    # Explicitly read and print the file contents for debugging
    run cat "${DEVCONFIG[REG_FILE]}"
    assert_success

    # Debugging: Check registry contents before assertion
    echo "Registry Contents: $output" >&2

    # Verify expected contents
    assert_output --partial "LOOPBACK ${DEVCONFIG[TEST_DEVICE]}"

    # Ensure registry filename follows expected pattern
    run basename "${DEVCONFIG[REG_FILE]}"
    assert_success
    assert_output --regexp "^device_fixture_registry-[a-zA-Z0-9]+\\.log$"
}

@test "register_test_device() handles non-block devices gracefully" {
    TEST_DEVICE="/dev/null"  # Intentionally use a non-block device
    run register_test_device
    assert_failure
    assert_output --partial "ERROR: /dev/null is not a block device"
}

@test "Full device lifecycle from registration to teardown" {
    run register_test_device
    assert_success
    assert_output --partial "Found and registered loop device: ${DEVCONFIG[TEST_DEVICE]}"

    # Check that the device is registered in the REG_FILE
    assert_file_exists "${DEVCONFIG[REG_FILE]}"
    run cat "${DEVCONFIG[REG_FILE]}"
    assert_output --partial "LOOPBACK ${DEVCONFIG[TEST_DEVICE]}"

    # Now test teardown
    run teardown_device
    assert_success
    assert_file_not_exists "${DEVCONFIG[REG_FILE]}"

    # Re-assign TEST_DEVICE to DEVCONFIG array to avoid subshell scoping issues
    DEVCONFIG[TEST_DEVICE]="$TEST_DEVICE"
}
