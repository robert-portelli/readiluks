# shellcheck disable=SC2119,SC2030,SC2031

function setup {
    load '../../../lib/_common_setup'
    _common_setup
    source "test/local_test_runner/lib/_device_fixture.bash"
    register_test_device
    setup_luks
}

function teardown {
    teardown_device
}

@test "BATS smoke test AND setup_lvm produces correct mutations" {
    # save on creating luks by smoke testing here
    run true
    assert_success
    mkdir '/tmp/test'
    assert [ -e "/tmp/test" ]
    assert [ -d "/tmp/test" ]
    refute [ -f "/tmp/test" ]
    rm -d /tmp/test

    # Expected keys and their default values
    declare -A expected_config=(
        [TEST_DEVICE]="$TEST_DEVICE"
        [LUKS_PW]="password"
        [LUKS_LABEL]="TEST_LUKS"
        [MAPPED_DEVICE]="/dev/mapper/TEST_LUKS"
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
    assert_output --partial "LUKS ${DEVCONFIG[MAPPED_DEVICE]}"

    setup_lvm

    ## correctly assigns value to DEVCONFIG[MAPPED_DEVICE]
    assert_equal "${DEVCONFIG[MAPPED_LVM]}" "/dev/mapper/${DEVCONFIG[VG_NAME]}-${DEVCONFIG[LV_NAME]}"

    ## correctly appends to REG_FILE:
    run cat "${DEVCONFIG[REG_FILE]}"
    assert_success
    assert_output --partial "LVM_PV ${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "LVM_VG ${DEVCONFIG[VG_NAME]}"
    assert_output --partial "LVM_LV ${DEVCONFIG[MAPPED_LVM]}"

    ## actually sets up lvm
    run vgs
    assert_output --partial "${DEVCONFIG[VG_NAME]}"
}

@test "setup_lvm() produces expected output" {
    # test setup_lvm output
    run setup_lvm
    assert_success
    assert_output --partial "LVM setup complete: ${DEVCONFIG[MAPPED_LVM]}"
}

@test "setup_lvm() fails when MAPPED_DEVICE is not a valid block device" {
    DEVCONFIG[MAPPED_DEVICE]="/dev/invaliddevice"
    run setup_lvm
    assert_failure
    assert_output --partial "ERROR: ${DEVCONFIG[MAPPED_DEVICE]} is not a valid block device"
}

@test "setup_lvm() fails if VG_NAME already exists" {
    setup_lvm
    run setup_lvm
    assert_failure
    assert_output --partial "Volume group ${DEVCONFIG[VG_NAME]} already exists."
}

@test "teardown_device() effective on setup_lvm" {
    setup_lvm

    # verify that the volume is recognized lvm
    run vgs
    assert_success
    assert_output --partial "${DEVCONFIG[VG_NAME]}"

    run teardown_device
    assert_success

    # verify that the volume is no longer recognized
    run vgs
    refute_output --partial "${DEVCONFIG[VG_NAME]}"

    run lvs "${DEVCONFIG[MAPPED_LVM]}"
    refute_output --partial "${DEVCONFIG[MAPPED_LVM]}"

    run pvs "${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "Cannot use ${DEVCONFIG[MAPPED_DEVICE]}: device not found"

    # Verify no residual device-mapper entries
    run dmsetup ls
    refute_output --partial "${DEVCONFIG[VG_NAME]}-${DEVCONFIG[LV_NAME]}"

    # Verify no stale mappings via lsblk
    run lsblk
    refute_output --partial "${DEVCONFIG[MAPPED_LVM]}"
}
