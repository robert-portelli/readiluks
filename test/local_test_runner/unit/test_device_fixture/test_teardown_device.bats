# shellcheck disable=SC2119

function setup {
    load '../../../lib/_common_setup'
    _common_setup
    source "test/local_test_runner/lib/_device_fixture.bash"
    create_device
    setup_luks
    setup_lvm
    format_filesystem
}

function teardown {
    teardown_device
}

@test "BATS smoke test AND teardown_device produces correct output" {
    run true
    assert_success
    mkdir '/tmp/test'
    assert [ -e "/tmp/test" ]
    assert [ -d "/tmp/test" ]
    refute [ -f "/tmp/test" ]
    rm -d /tmp/test

    # Run teardown and capture output
    run teardown_device
    assert_success
    assert_output --partial "Starting explicit teardown of device fixture..."
    assert_output --partial "Unmounting ${DEVCONFIG[MOUNT_POINT]}"
    assert_output --partial "Deactivating logical volume ${DEVCONFIG[MAPPED_LVM]}"
    assert_output --partial "Deactivating volume group ${DEVCONFIG[VG_NAME]}"
    assert_output --partial "Removing physical volume ${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "Closing LUKS container ${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "Removing loop device ${DEVCONFIG[TEST_DEVICE]}"
    assert_output --partial "Deleting image file ${DEVCONFIG[IMG_FILE]}"
    assert_output --partial "Teardown complete."
}

#@test "teardown_device cleans up all created resources" {
# shellcheck disable=SC2317
hold() {
    teardown_device
    sync && sleep 1
    # Check that the mount point is unmounted
    run findmnt -rn "${DEVCONFIG[MOUNT_POINT]}"
    assert_failure  # Expect failure because it should no longer be mounted

    # Check that the LVM components are removed
    run vgs "${DEVCONFIG[VG_NAME]}"
    assert_failure  # Expect failure because VG should be removed

    run lvs "${DEVCONFIG[MAPPED_LVM]}"
    assert_failure  # Expect failure because LV should be removed

    run pvs "${DEVCONFIG[MAPPED_DEVICE]}"
    assert_failure  # Expect failure because PV should be removed

    # Check that the LUKS container is closed
    run cryptsetup status "${DEVCONFIG[MAPPED_DEVICE]}"
    assert_failure  # Expect failure because LUKS container should be closed

    # Check that the loop device is removed
    refute [ -b "${DEVCONFIG[TEST_DEVICE]}" ]

    # Check that the image file is removed
    refute [ -e "${DEVCONFIG[IMG_FILE]}" ]

    # Check that the registry file is removed
    refute [ -e "${DEVCONFIG[REG_FILE]}" ]
}

#@test "teardown_device can be safely called multiple times" {
# shellcheck disable=SC2317
hold() {
    teardown_device
    sync && sleep 1  # Allow any pending operations to settle

    run teardown_device
    assert_success
    assert_output --partial "Teardown complete."
}
