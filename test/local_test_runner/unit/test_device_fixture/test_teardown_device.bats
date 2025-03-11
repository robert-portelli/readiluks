# shellcheck disable=SC2119,SC2030,SC2031

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

@test "teardown_device fails when blkid detects remaining data on loopback" {
    MOCK_BIN_DIR="$(mktemp -d)"
    ORIGINAL_PATH="$PATH"

    # Create the blkid mock
    cat <<'EOF' > "$MOCK_BIN_DIR/blkid"
#!/usr/bin/env bash
exit 0  # Simulate that data is present
EOF
    chmod +x "$MOCK_BIN_DIR/blkid"

    # Don't delay PATH modification, mock blkid from the start
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Run teardown_device directly and capture both output and status
    run teardown_device

    # Assertions
    assert_failure
    assert_output --partial "ERROR: ${DEVCONFIG[TEST_DEVICE]} still contains data or LUKS metadata after reset."

    # Cleanup
    PATH="$ORIGINAL_PATH"
    rm -rf "$MOCK_BIN_DIR"
}



@test "teardown_device logs error when cryptsetup erase fails" {
    # Create a temporary directory for mock binaries
    MOCK_BIN_DIR="$(mktemp -d)"
    ORIGINAL_PATH="$PATH"
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Mock `cryptsetup`
    cat <<'EOF' > "$MOCK_BIN_DIR/cryptsetup"
#!/usr/bin/env bash
if [[ "$1" == "close" ]]; then
    exit 0  # success
elif [[ "$1" == "erase" ]]; then
    exit 0  # simulate erase failure
elif [[ "$1" == "isLuks" ]]; then
    exit 0  # simulate NOT a luks container (erase worked)
fi
EOF
    chmod +x "$MOCK_BIN_DIR/cryptsetup"

    # Run teardown_device which will invoke the mocked `cryptsetup erase`
    run teardown_device

    assert_failure

    # Confirm we hit the error message
    assert_output --partial "ERROR: ${DEVCONFIG[MAPPED_DEVICE]} is still a LUKS container after wipe."

    # Restore the original path
    PATH="$ORIGINAL_PATH"

    # Clean up the mock path
    rm -rf "$MOCK_BIN_DIR"


}

@test "wait_for_removal times out on a persistent condition" {
    # Mock command that always returns true (simulate always busy)
    run wait_for_removal "true" "persistent condition" 2 0.1 "Test timeout message"

    assert_failure
    assert_output --partial "ERROR: Test timeout message"
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
