# shellcheck disable=SC2119

function setup {
    load '../../../lib/_common_setup'
    _common_setup
    source "test/local_test_runner/lib/_device_fixture.bash"
    register_test_device
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

@test "DEVCONFIG and REG_FILE have been correctly prepared for setup_luks()" {
    # Expected keys and their default values
    declare -A expected_config=(
        [TEST_DEVICE]="$TEST_DEVICE"
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

    # Check that REG_FILE exists and contains expected entries
    assert_exists "${DEVCONFIG[REG_FILE]}"
    assert_file_not_empty "${DEVCONFIG[REG_FILE]}"

    run cat "${DEVCONFIG[REG_FILE]}"
    assert_success

    # Verify expected contents
    assert_output --partial "LOOPBACK ${DEVCONFIG[TEST_DEVICE]}"
}

@test "setup_luks() produces correct output" {
    run setup_luks
    assert_success
    assert_output --partial "LUKS container created and opened at ${DEVCONFIG[MAPPED_DEVICE]}"
    refute_output --partial "ERROR: ${DEVCONFIG[TEST_DEVICE]} is not a valid block device."
}

@test "setup_luks() correctly mutates array: DEVCONFIG and file: REG_FILE" {
    setup_luks

    # correctly assigns value to DEVCONFIG[MAPPED_DEVICE]
    assert_equal "${DEVCONFIG[MAPPED_DEVICE]}" "/dev/mapper/${DEVCONFIG[LUKS_LABEL]}"

    # correctly writes DEVCONFIG[MAPPED_DEVICE] to REG_FILE
    assert_file_exists "${DEVCONFIG[REG_FILE]}"

    run cat "${DEVCONFIG[REG_FILE]}"

    ## verify contents added by setup_luks()
    assert_output --partial "LUKS ${DEVCONFIG[MAPPED_DEVICE]}"
}

@test "LUKS metadata is removed by teardown_device()" {
    setup_luks

    # Verify that the device is initially a LUKS container
    run cryptsetup isLuks "$TEST_DEVICE"
    # Expected $TEST_DEVICE to be a LUKS container before teardown
    assert_success

    # Run teardown and verify LUKS metadata is removed
    run teardown_device
    assert_success

    # Verify that the device is no longer recognized as a LUKS container
    run cryptsetup isLuks "$TEST_DEVICE"
    # Expected $TEST_DEVICE to no longer be a LUKS container after teardown
    assert_failure
}
