# shellcheck disable=SC2119

function setup {
    load '../../../lib/_common_setup'
    _common_setup
    source "test/local_test_runner/lib/_device_fixture.bash"
    create_device
    setup_luks
}

function teardown {
    teardown_device
}

@test "BATS smoke test AND setup_lvm produces correct output" {
    # save on creating luks by smoke testing here
    run true
    assert_success
    mkdir '/tmp/test'
    assert [ -e "/tmp/test" ]
    assert [ -d "/tmp/test" ]
    refute [ -f "/tmp/test" ]
    rm -d /tmp/test

    # test setup_lvm output
    run setup_lvm
    assert_success
    assert_output --partial "LVM setup complete: ${DEVCONFIG[MAPPED_LVM]}"
}

@test "setup_lvm performs correct operations" {
    setup_lvm

    # test the DEVCONFIG
    assert_equal "${DEVCONFIG[IMG_SIZE]}" "1024M"
    assert_equal "${DEVCONFIG[LUKS_PW]}" "password"
    assert_equal "${DEVCONFIG[LUKS_LABEL]}" "TEST_LUKS"
    assert_equal "${DEVCONFIG[VG_NAME]}" "vgtest"
    assert_equal "${DEVCONFIG[LV_NAME]}" "lvtest"
    assert_equal "${DEVCONFIG[FS_TYPE]}" "btrfs"
    assert_equal "${DEVCONFIG[MOUNT_POINT]}" "/mnt/target"
    assert_equal "${DEVCONFIG[MAPPED_DEVICE]}" "/dev/mapper/TEST_LUKS"
    assert_equal "${DEVCONFIG[MAPPED_LVM]}" "/dev/mapper/vgtest-lvtest"
    assert_file_exist "${DEVCONFIG[IMG_FILE]}"
    run echo "${DEVCONFIG[IMG_FILE]}"
    assert_output --regexp "^/tmp/device-[a-zA-Z0-9]+\\.img$"
    assert [ -b "${DEVCONFIG[TEST_DEVICE]}" ]
    assert_file_exist "${DEVCONFIG[REG_FILE]}"

    # is it actually lvm
    # TODO
    run vgs
    assert_output --partial "${DEVCONFIG[VG_NAME]}"


}
