run_test() {
    local test_name="${FUNCNAME[1]}"
    local source_file="$1"
    local test_file="$2"
    local workflow_event="$3"
    local workflow_job="$4"

    echo "📢 Running test: $test_name"

    # Ensure BASE_DIR is set
    if [[ -z "${CONFIG[BASE_DIR]}" ]]; then
        echo "❌ ERROR: CONFIG[BASE_DIR] is empty. Aborting."
        exit 1
    fi

    # Run unit tests if neither --coverage nor --workflow were passed
    if [[ "${CONFIG[COVERAGE]}" == "false" && "${CONFIG[WORKFLOW]}" == "false" ]]; then
        echo "🧪 Running BATS tests: ${test_file}"
        run_in_docker "bats '${CONFIG[BATS_FLAGS]}' '${test_file}'"
    fi

    # Run kcov if --coverage was passed
    if [[ "${CONFIG[COVERAGE]}" == "true" ]]; then
        echo "📊 Running coverage analysis..."
        run_in_docker "kcov_dir=\$(mktemp -d) && \
                       echo '📂 Temporary kcov directory: \$kcov_dir' && \
                       kcov --clean --include-path='${source_file}' \"\$kcov_dir\" bats '${test_file}' && \
                       echo '📝 Uncovered lines:' && \
                       grep 'covered=\"false\"' \"\$kcov_dir/bats/sonarqube.xml\" || echo '✅ All lines covered.' && \
                       rm -rf \"\$kcov_dir\""
    fi

    # Run workflow tests if --workflow was passed
    if [[ "${CONFIG[WORKFLOW]}" == "true" ]]; then
        echo "🚀 Running workflow tests for job: ${workflow_job}"
        run_in_docker "act \
                        '${workflow_event}' \
                        -P ${CONFIG[DOCKERIMAGE]} \
                        --pull=false \
                        -j '${workflow_job}' \
                        --input bats-flags=${CONFIG[BATS_FLAGS]}"
    fi

    echo "✅ $test_name completed."
}
