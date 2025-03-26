# test/local_test_runner/unit/inner_systemd_container/smoke_test.bats

function setup {
    load '../../../lib/_common_setup'
    _common_setup
}

@test "systemd is running" {
    run systemctl is-system-running
    assert_success
    assert_output -p "running"
}

@test "create hello.service unit file" {
    bash -c 'cat <<EOF > /etc/systemd/system/hello.service
[Unit]
Description=Hello World Service

[Service]
ExecStart=/bin/echo "Hello from systemd"

[Install]
WantedBy=multi-user.target
EOF'
    run test -f /etc/systemd/system/hello.service
    assert_success
}

@test "reload systemd units" {
    run systemctl daemon-reload
    assert_success
}

@test "enable hello.service" {
    run systemctl enable hello.service
    assert_success
    assert_output -p "Created symlink"
}

@test "start hello.service" {
    run systemctl start hello.service
    assert_success
}

@test "hello.service is inactive after exit" {
    run systemctl is-active hello.service
    assert_failure
    assert_output -p "inactive" # echo is not a persistent process
}


@test "hello.service is enabled" {
    run systemctl is-enabled hello.service
    assert_success
    assert_output -p "enabled"
}

@test "journal contains hello output" {
    run journalctl -u hello.service --no-pager
    assert_success
    assert_output -p "Hello from systemd"
}
