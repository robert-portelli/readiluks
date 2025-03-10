# shellcheck disable=SC2119

function setup {
    load '../../../lib/_common_setup'
    _common_setup
    source "test/local_test_runner/lib/_device_fixture.bash"
    register_test_device
    setup_luks
    setup_lvm
    format_filesystem
}

function teardown {
    teardown_device
}


@test "BATS smoke test" {
    run true
    assert_success
    mkdir '/tmp/test'
    assert [ -e "/tmp/test" ]
    assert [ -d "/tmp/test" ]
    refute [ -f "/tmp/test" ]
    rm -d /tmp/test
}





@test "teardown_device case: MOUNT detects and kills processes using a mount" {
    # Create a dummy file inside the mount
    echo "Blocking device" > "${DEVCONFIG[MOUNT_POINT]}/dummyfile"

    # Start a background process that keeps the mount busy
    tail -f "${DEVCONFIG[MOUNT_POINT]}/dummyfile" >/dev/null 2>&1 &

    run teardown_device
    # Ensure `teardown_device()` detects and kills the process
    assert_success
    assert_output --partial "Killing processes using ${DEVCONFIG[MOUNT_POINT]}..."
}

@test "teardown_device produces correct output" {
    # Run teardown and capture output
    run teardown_device
    assert_success

    assert_output --partial "Starting explicit teardown of device fixture..."

    # case: MOUNT
    assert_output --partial "Unmounting ${DEVCONFIG[MOUNT_POINT]} and wiping filesystem signatures..."
    assert_output --partial "No blocking processes on ${DEVCONFIG[MOUNT_POINT]}"
    refute_output --partial "Failed to unmount ${DEVCONFIG[MOUNT_POINT]}"
    refute_output --partial "Failed to wipe filesystem signatures on ${DEVCONFIG[MOUNT_POINT]}"
    assert_output --partial "Finished unmounting ${DEVCONFIG[MOUNT_POINT]} and wiping filesystem signatures"

    # case: LVM_LV
    assert_output --partial "Deactivating and removing logical volume ${DEVCONFIG[MAPPED_LVM]}..."
    refute_output --partial "Failed to deactivate ${DEVCONFIG[MAPPED_LVM]}"
    refute_output --partial "Failed to remove ${DEVCONFIG[MAPPED_LVM]}"
    assert_output --partial "Removing device-mapper entry for ${DEVCONFIG[MAPPED_LVM]}..."
    refute_output --partial "Failed to remove device-mapper entry for ${DEVCONFIG[MAPPED_LVM]}"
    assert_output --partial "Removing device-mapper entry for ${DEVCONFIG[MAPPED_LVM]}..."
    assert_output --partial "Finished deactivating and removing logical volume ${DEVCONFIG[MAPPED_LVM]}"

    # case: LVM_VG
    assert_output --partial "Deactivating and removing volume group ${DEVCONFIG[VG_NAME]}..."
    refute_output --partial "Failed to deactivate ${DEVCONFIG[VG_NAME]}"
    refute_output --partial "Failed to remove ${DEVCONFIG[VG_NAME]}"
    assert_output --partial "Finished deactivating and removing volume group ${DEVCONFIG[VG_NAME]}"

    # case: LVM_PV
    assert_output --partial "Wiping and removing physical volume ${DEVCONFIG[MAPPED_DEVICE]}..."
    refute_output --partial "Failed to remove ${DEVCONFIG[MAPPED_DEVICE]}"
    refute_output --partial "Failed to wipe filesystem signatures on ${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "Finished wiping and removing physical volume ${DEVCONFIG[MAPPED_DEVICE]}"

    # case: LUKS
    assert_output --partial "Closing LUKS container ${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "Erasing LUKS header from ${DEVCONFIG[MAPPED_DEVICE]}..."
    refute_output --partial "Failed to wipe LUKS header on ${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "LUKS metadata successfully removed from ${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "Finished closing LUKS container ${DEVCONFIG[MAPPED_DEVICE]}"

    # case: LOOPBACK
    assert_output --partial "Resetting loop device ${DEVCONFIG[TEST_DEVICE]}..."
    assert_output --partial "Zeroing out the start of ${DEVCONFIG[TEST_DEVICE]}"
    refute_output --partial "ERROR: ${DEVCONFIG[TEST_DEVICE]} still contains LUKS metadata"
    assert_output --partial "Loopback device ${DEVCONFIG[TEST_DEVICE]} reset to initial state"
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
