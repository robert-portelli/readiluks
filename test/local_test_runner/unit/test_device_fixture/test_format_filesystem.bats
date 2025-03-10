# shellcheck disable=SC2119,SC2030,SC2031

function setup {
    load '../../../lib/_common_setup'
    _common_setup
    source "test/local_test_runner/lib/_device_fixture.bash"
    register_test_device
    setup_luks
    setup_lvm
}

function teardown {
    teardown_device
}

@test "format_filesystem fails if LVM is not setup" {
    DEVCONFIG[MAPPED_LVM]=""
    run format_filesystem
    assert_failure
    assert_output -p "Error: No LVM volume found. Cannot format filesystem."
}

@test "format_filesystem fails if unsupported filesystem type passed" {
    DEVCONFIG[FS_TYPE]=""
    run format_filesystem
    assert_failure
    assert_output -p "Failed to format ${DEVCONFIG[MAPPED_LVM]} as ${DEVCONFIG[FS_TYPE]}"
}

@test "format_filesystem() fails if mountpoint creation fails" {
    DEVCONFIG[MOUNT_POINT]="/dev/null/invalid"
    run format_filesystem
    assert_failure
    assert_output -p "Failed to create mountpoint: ${DEVCONFIG[MOUNT_POINT]}"
}

@test "format_filesystem fails when mount fails" {
    # Create a temporary directory for our mock binaries
    MOCK_BIN_DIR="$(mktemp -d)"
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Mock `mount` to always fail
    cat <<'EOF' > "$MOCK_BIN_DIR/mount"
#!/usr/bin/env bash
echo "mount: failed to mount $2 on $3" >&2
exit 1  # Simulate mount failure
EOF
    chmod +x "$MOCK_BIN_DIR/mount"

    # Ensure `DEVCONFIG[MAPPED_LVM]` is set to prevent early failures
    #DEVCONFIG[MAPPED_LVM]="/dev/mapper/${DEVCONFIG[VG_NAME]}-${DEVCONFIG[LV_NAME]}"

    # Run `format_filesystem()` expecting failure
    run format_filesystem
    assert_failure
    assert_output --partial "Failed to mount ${DEVCONFIG[MAPPED_LVM]} at ${DEVCONFIG[MOUNT_POINT]}"

    # Cleanup: remove the mock
    rm -rf "$MOCK_BIN_DIR"
}



@test "Smoke test BATS setup" {
    run true
    assert_success

    # Test basic filesystem operations
    mkdir '/tmp/test'
    assert [ -e "/tmp/test" ]
    assert [ -d "/tmp/test" ]
    refute [ -f "/tmp/test" ]
    rm -d /tmp/test
}

@test "DEVCONFIG was correctly prepared for format_filesystem()" {
    declare -A expected_config=(
        [TEST_DEVICE]="$TEST_DEVICE"
        [LUKS_PW]="password"
        [LUKS_LABEL]="TEST_LUKS"
        [MAPPED_DEVICE]="/dev/mapper/TEST_LUKS"
        [VG_NAME]="vgtest"
        [LV_NAME]="lvtest"
        [MAPPED_LVM]="/dev/mapper/vgtest-lvtest"
        [FS_TYPE]="btrfs"
        [MOUNT_POINT]="/mnt/target"
    )

    # ✅ Validate DEVCONFIG Initialization
    for key in "${!expected_config[@]}"; do
        assert [ -v "DEVCONFIG[$key]" ] # Check key existence
        assert_equal "${DEVCONFIG[$key]}" "${expected_config[$key]}" "Expected ${expected_config[$key]} but got ${DEVCONFIG[$key]} for key $key"
    done

    # 🗃️ Check REG_FILE existence and contents
    assert_file_exists "${DEVCONFIG[REG_FILE]}"
    assert_file_not_empty "${DEVCONFIG[REG_FILE]}"

    run cat "${DEVCONFIG[REG_FILE]}"
    assert_success
    assert_output --partial "LOOPBACK ${DEVCONFIG[TEST_DEVICE]}"
    assert_output --partial "LUKS ${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "LVM_PV ${DEVCONFIG[MAPPED_DEVICE]}"
    assert_output --partial "LVM_VG ${DEVCONFIG[VG_NAME]}"
    assert_output --partial "LVM_LV ${DEVCONFIG[MAPPED_LVM]}"
}

@test "format_filesystem() produces correct output" {
    # 💾 Run format_filesystem and validate output
    run format_filesystem
    assert_success

    assert_output --partial "Success: ${DEVCONFIG[MAPPED_LVM]} formatted as ${DEVCONFIG[FS_TYPE]}"
    assert_output --partial "Success: mount point created at ${DEVCONFIG[MOUNT_POINT]}"
    assert_output --partial "Success: ${DEVCONFIG[MOUNT_POINT]} mounted at ${DEVCONFIG[MAPPED_LVM]} as ${DEVCONFIG[FS_TYPE]}"
    refute_output --partial "Error: No LVM volume found. Cannot format filesystem."

    # 📦 Validate DEVCONFIG[MOUNT_POINT] assignment
    assert_equal "${DEVCONFIG[MOUNT_POINT]}" "/mnt/target"

    # 📄 Check REG_FILE for MOUNT entry
    run cat "${DEVCONFIG[REG_FILE]}"
    assert_success
    assert_output --partial "MOUNT ${DEVCONFIG[MOUNT_POINT]}"

    # 🔍 Validate Btrfs filesystem setup
    run blkid "${DEVCONFIG[MAPPED_LVM]}"
    assert_success
    assert_output --partial "TYPE=\"btrfs\""

    # 📁 Validate mount status
    run findmnt --source "${DEVCONFIG[MAPPED_LVM]}"
    assert_success

    # 🧪 Test file persistence
    local test_file="${DEVCONFIG[MOUNT_POINT]}/testfile"
    echo "Test text" > "$test_file"
    sync  # Ensure data is flushed to disk

    # Verify file existence before unmount
    run stat "$test_file"
    assert_success

    # 🧹 Unmount and remount, then verify persistence
    umount "${DEVCONFIG[MOUNT_POINT]}"
    mount -t "${DEVCONFIG[FS_TYPE]}" "${DEVCONFIG[MAPPED_LVM]}" "${DEVCONFIG[MOUNT_POINT]}"

    # Verify file persistence after remount
    run stat "$test_file"
    assert_success
}

@test "format_filesystem performs correct operations and validates teardown" {
    format_filesystem

    # Check that the filesystem was created
    run blkid "${DEVCONFIG[MAPPED_LVM]}"
    assert_success
    assert_output --partial "TYPE=\"btrfs\""

    # Verify that it's mounted correctly
    run findmnt --source "${DEVCONFIG[MAPPED_LVM]}"
    assert_success

    # Test file persistence
    test_file="${DEVCONFIG[MOUNT_POINT]}/testfile"
    echo "Test text" > "$test_file"
    sync  # Ensure data is flushed to disk
    run stat "$test_file"
    assert_success

    # Unmount and remount, then verify
    umount "${DEVCONFIG[MOUNT_POINT]}"
    mount -t "${DEVCONFIG[FS_TYPE]}" "${DEVCONFIG[MAPPED_LVM]}" "${DEVCONFIG[MOUNT_POINT]}"

    run stat "$test_file"
    assert_success

    # Invoke teardown
    run teardown_device
    assert_success
    assert_output --partial "Teardown complete."

    # Verify that the mount point is no longer mounted
    run findmnt --source "${DEVCONFIG[MAPPED_LVM]}"
    assert_failure
    refute_output --partial "${DEVCONFIG[MOUNT_POINT]}"

    # Check that the filesystem is no longer detected
    run blkid "${DEVCONFIG[MAPPED_LVM]}"
    assert_failure

    # Verify that the mount point is either removed or empty
    if [ -e "${DEVCONFIG[MOUNT_POINT]}" ]; then
        assert [ -z "$(ls -A "${DEVCONFIG[MOUNT_POINT]}")" ] \
            "Mount point ${DEVCONFIG[MOUNT_POINT]} should be empty"
    fi

    # Check that the loopback device is clean but still available
    run losetup -j "${DEVCONFIG[TEST_DEVICE]}"
    assert_success

    # Verify that the loopback device is not LUKS or has a filesystem
    run cryptsetup isLuks "${DEVCONFIG[TEST_DEVICE]}"
    assert_failure

    run blkid "${DEVCONFIG[TEST_DEVICE]}"
    assert_failure
}
