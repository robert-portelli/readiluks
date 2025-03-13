# shellcheck disable=SC2119,SC2030,SC2031

function setup {
    load '../../../lib/_common_setup'
    _common_setup
    ORIGINAL_PATH="$PATH"
    source "test/local_test_runner/lib/_device_fixture.bash"
    register_test_device
    setup_luks
}

function teardown {
    PATH="$ORIGINAL_PATH"
    [[ -d "$MOCK_BIN_DIR" ]] && rm -rf "$MOCK_BIN_DIR"
    REAL_DMSETUP="$(command -v dmsetup)"
    teardown_device
}

# this test needs to be first to pass
@test "setup_lvm fails when dmsetup info returns no major/minor numbers" {
    MOCK_BIN_DIR="$(mktemp -d)"
    export PATH="$MOCK_BIN_DIR:$PATH"

    cat <<EOF > "$MOCK_BIN_DIR/dmsetup"
#!/usr/bin/env bash
if [[ "\$1" == "info" && "\$2" == "${DEVCONFIG[VG_NAME]}-${DEVCONFIG[LV_NAME]}" ]]; then
    # Simulate dm_info being empty
    echo ""
    exit 0
else
    exec "$REAL_DMSETUP" "\$@"
fi
EOF
    chmod +x "$MOCK_BIN_DIR/dmsetup"

    run setup_lvm
    assert_failure
    assert_output --partial "Failed to retrieve major/minor numbers for ${DEVCONFIG[MAPPED_LVM]}"
    teardown_device
}

@test "BATS smoke test" {
    # save on creating luks by smoke testing here
    run true
    assert_success
    mkdir '/tmp/test'
    assert [ -e "/tmp/test" ]
    assert [ -d "/tmp/test" ]
    refute [ -f "/tmp/test" ]
    rm -d /tmp/test
}

hold1() {
    # @test "setup_lvm() correctly mutates DEVCONFIG"
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

@test "setup_lvm fails if volume group creation fails" {
    MOCK_BIN_DIR="$(mktemp -d)"
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Mock `vgcreate` to simulate a failure
    cat <<'EOF' > "$MOCK_BIN_DIR/vgcreate"
#!/usr/bin/env bash
echo "Simulated vgcreate failure" >&2
exit 1
EOF
    chmod +x "$MOCK_BIN_DIR/vgcreate"

    run setup_lvm
    assert_failure
    assert_output --partial "Failed to create VG"

    # Cleanup
    rm -rf "$MOCK_BIN_DIR"
}

@test "setup_lvm fails if volume group activation fails" {
    MOCK_BIN_DIR="$(mktemp -d)"
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Mock `vgchange` to simulate activation failure
    cat <<'EOF' > "$MOCK_BIN_DIR/vgchange"
#!/usr/bin/env bash
if [[ "$1" == "-ay" ]]; then
    echo "Simulated vgchange activation failure" >&2
    exit 1
fi
EOF
    chmod +x "$MOCK_BIN_DIR/vgchange"

    run setup_lvm
    assert_failure
    assert_output --partial "Failed to activate VG"

    # Restore and clean up
    rm -rf "$MOCK_BIN_DIR"
}


@test "setup_lvm fails if logical volume activation fails" {
    MOCK_BIN_DIR="$(mktemp -d)"
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Mock `lvchange` to simulate logical volume activation failure
    cat <<'EOF' > "$MOCK_BIN_DIR/lvchange"
#!/usr/bin/env bash
if [[ "$1" == "-ay" ]]; then
    echo "Simulated lvchange activation failure" >&2
    exit 1
fi
EOF
    chmod +x "$MOCK_BIN_DIR/lvchange"

    run setup_lvm
    assert_failure
    assert_output --partial "Failed to activate LV"

    # Restore and clean up
    rm -rf "$MOCK_BIN_DIR"
}


@test "setup_lvm fails if logical volume creation fails" {
    DEVCONFIG[LV_NAME]=""
    run setup_lvm
    assert_failure
    assert_output -p "Failed to create LV"
}

@test "setup_lvm fails when LV_NAME already exists" {
    # Create a temporary directory for our mock binaries
    MOCK_BIN_DIR="$(mktemp -d)"
    export PATH="$MOCK_BIN_DIR:$PATH"

    # Mock `lvs` to return an error (simulate LV already existing)
    cat <<'EOF' > "$MOCK_BIN_DIR/lvs"
#!/usr/bin/env bash
echo "  Logical volume \"${DEVCONFIG[LV_NAME]}\" already exists." >&2
exit 0  # Simulate success so the check in setup_lvm() passes
EOF
    chmod +x "$MOCK_BIN_DIR/lvs"

    # Run setup_lvm with the mocked `lvs`
    run setup_lvm
    assert_failure
    assert_output --partial "ERROR: Logical volume ${DEVCONFIG[MAPPED_LVM]} already exists."

    # Cleanup: remove the mock after the test
    rm -rf "$MOCK_BIN_DIR"
}

@test "setup_lvm() produces expected output" {
    # test setup_lvm output
    run setup_lvm
    assert_success
    assert_output --partial "LVM setup complete: ${DEVCONFIG[MAPPED_LVM]}"
    refute_output --partial "Failed to retrieve major/minor numbers for ${DEVCONFIG[MAPPED_LVM]}"
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
