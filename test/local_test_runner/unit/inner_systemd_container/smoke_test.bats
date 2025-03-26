function setup {
    load '../../../lib/_common_setup'
    _common_setup
    source "test/local_test_runner/lib/_runner-config.bash"
    source "test/local_test_runner/lib/_manage_outer_docker.bash"
}

@test "smoke test systemd container" {
    run start_outer_container
    assert_success
}

@test "systemd is running" {
    start_outer_container

    run docker exec -it "${CONFIG[OUTER_CONTAINER]}" \
        docker exec -it "${CONFIG[SYSTEMD_CONTAINER]}" \
        systemctl is-system-running

    assert_success
    assert_output -p "running"
}
