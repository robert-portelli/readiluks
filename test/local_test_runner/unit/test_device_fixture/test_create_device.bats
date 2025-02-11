# shellcheck disable=SC2119

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

@test "DEVCONFIG default values are correctly set" {
    run print_devconfig
    assert_success
    assert_output --partial 'IMG_SIZE=1024M'
    assert_output --partial 'LUKS_PW=password'
    assert_output --partial 'LUKS_LABEL=TEST_LUKS'
    assert_output --partial 'VG_NAME=vgtest'
    assert_output --partial 'LV_NAME=lvtest'
    assert_output --partial 'FS_TYPE=btrfs'
    assert_output --partial 'MOUNT_POINT=/mnt/target'
    refute_output --partial 'MAPPED_LVM=*'
    refute_output --partial 'MAPPED_DEVICE=*'
    refute_output --partial 'REG_FILE=*'
    refute_output --partial 'TEST_DEVICE=*'

}

@test "create_device can be safely called multiple times" {
    export DEVICE_FIXTURE_NO_TRAP=1
    create_device
    first_device="${DEVCONFIG[TEST_DEVICE]}"
    first_image="${DEVCONFIG[IMG_FILE]}"

    # Capture values after the first run for debugging
    echo "First Device: $first_device" >&2
    echo "First Image: $first_image" >&2

    # Ensure first device creation succeeded
    assert_file_exist "$first_image"
    assert [ -b "$first_device" ] || fail "First loop device is missing"

    # Clean up the first device before calling create_device again
    #losetup -d "$first_device" || echo "Warning: Failed to detach loop device $first_device" >&2
    #rm -f "$first_image"

    create_device
    second_device="${DEVCONFIG[TEST_DEVICE]}"
    second_image="${DEVCONFIG[IMG_FILE]}"

    echo "Second Device: $second_device" >&2
    echo "Second Image: $second_image" >&2

    assert_file_exist "$second_image"
    assert [ -b "$second_device" ] || fail "Second loop device is missing"
    #[[ "$first_device" != "$second_device" ]]
    #assert [ "$first_device" != "$second_device" ]
    #assert [ "$first_image" != "$second_image" ]
}


@test "function create_device produces expected output" {
    run create_device
    assert_success
    refute_output --partial "Failed to create loop device for ${DEVCONFIG[IMG_FILE]}"
    assert_output --partial "Created loop device: ${DEVCONFIG[TEST_DEVICE]}"
    assert_output --partial "backed by ${DEVCONFIG[IMG_FILE]}"
}

@test "function create_device creates the image file" {
    create_device

    # The image file was created
    assert_file_exist "${DEVCONFIG[IMG_FILE]}"

    # The image file is the size defined by DEVCONFIG[IMG_SIZE]
    #### Get the actual file size in bytes
    run stat -c "%s" "${DEVCONFIG[IMG_FILE]}" # avoid false positive or misleading errors
    actual_size="$output"

    #### Convert DEVCONFIG[IMG_SIZE] to bytes (assuming it ends in M for megabytes)
    expected_size=$(( ${DEVCONFIG[IMG_SIZE]%M} * 1024 * 1024 ))

    assert_equal "$actual_size" "$expected_size"

    # The correct filename was given to the image file
    run echo "${DEVCONFIG[IMG_FILE]}"
    assert_output --regexp "^/tmp/device-[a-zA-Z0-9]+\\.img$"
}

@test "function create_device creates a loopback device from the image file" {
    create_device

    # The loopback block device was created
    assert [ -b "${DEVCONFIG[TEST_DEVICE]}" ]
}

@test "function create_device creates a registry file" {
    create_device

    # Ensure the registry file exists
    assert_file_exist "${DEVCONFIG[REG_FILE]}"

    # Wait to ensure file system sync
    sync && sleep 0.1

    # Explicitly read and print the file contents for debugging
    run cat "${DEVCONFIG[REG_FILE]}"
    assert_success

    # Debugging: Check registry contents before assertion
    echo "Registry Contents: $output" >&2

    # Verify expected contents
    assert_output --partial "LOOPBACK ${DEVCONFIG[TEST_DEVICE]}"
    assert_output --partial "IMAGE ${DEVCONFIG[IMG_FILE]}"

    # Ensure registry filename follows expected pattern
    run basename "${DEVCONFIG[REG_FILE]}"
    assert_success
    assert_output --regexp "^device_fixture_registry-[a-zA-Z0-9]+\\.log$"
}
