# ==============================================================================
# Filename: test/local_test_runner/lib/_coverage.bash
# ------------------------------------------------------------------------------
# Description:
#   Provides functions for collecting and reporting line coverage in Bash scripts
#   tested via BATS and analyzed with kcov. Produces `pytest-cov` style reports
#   summarizing coverage results for source files and individual lines.
#
# Purpose:
#   - Encapsulates coverage analysis logic for reuse across test runners.
#   - Automates collection of line execution data from kcov output.
#   - Formats reports to display total, missed, and covered statements with line ranges.
#   - Presents timing information for test executions.
#
# Functions:
#   - print_timing_line:
#       Prints a formatted line showing a test label and its elapsed time.
#
#   - collect_coverage_data:
#       Executes a list of test functions, gathers coverage data, and invokes
#       `format_coverage_report` to summarize results.
#
#   - format_missing_lines:
#       Formats uncovered line numbers into a compact human-readable string
#       (e.g., 5-7,10,12-14).
#
#   - calculate_coverage:
#       Computes the coverage percentage based on missed and total statement counts.
#
#   - format_coverage_report:
#       Generates a tabular report showing file name, statement counts, coverage
#       percentage, and missing lines. Outputs `pytest-cov` style coverage tables.
#
# Usage:
#   1. Source this file in the test runner:
#        source "$BASEDIR/test/local_test_runner/lib/_coverage.bash"
#
#   2. Call `collect_coverage_data` with test functions as arguments:
#        collect_coverage_data test_function_1 test_function_2 ...
#
#   3. Example coverage report will be printed after execution.
#
# Example:
#   collect_coverage_data \
#       test_device_fixture_register_test_device \
#       test_device_fixture_setup_luks \
#       test_device_fixture_setup_lvm
#
#   Output:
#     ✅ test_device_fixture_register_test_device completed in:                3.120s
#     ✅ test_device_fixture_setup_luks completed in:                         15.870s
#     ...
#     📊 Final Coverage Report:
#
#     Name                            Stmts   Miss  Cover Missing
#     ------------------------------ ------ ------ ------ ----------------
#     _device_fixture.bash              178      1  99.44% 229
#     ------------------------------ ------ ------ ------ ----------------
#
# Requirements:
#   - Bash 4.x or higher
#   - BATS for executing tests
#   - kcov for coverage collection
#
# Dependencies:
#   - Functions assume `run_test` handles test execution and kcov output generation.
#
# Author:
#   Robert Portelli
#   Repository: https://github.com/robert-portelli/readiluks
#
# License:
#   MIT License. See LICENSE.md and repository commit history (`git log`).
# ==============================================================================

print_timing_line() {
    local label="$1"  # e.g. "✅ test_device_fixture_setup_luks completed in:"
    local time="$2"   # e.g. "50.673"

    local total_width=88  # Target column where 's' ends (tweak this number as needed)
    local label_length=${#label}
    local time_length=${#time}

    local spaces=$((total_width - label_length - time_length - 1))  # 1 for 's'

    # Safety check to prevent negative spacing
    [[ $spaces -lt 1 ]] && spaces=1

    # Build the padding
    local padding
    padding=$(printf '%*s' "$spaces" "")

    # Print the result
    printf "%s%s%s\n" "$label" "$padding" "$time"s
}

collect_coverage_data() {
    local test_functions=("$@")
    local all_lines_file
    local covered_lines_file
    local uncovered_lines_file
    all_lines_file="$(mktemp)"
    covered_lines_file="$(mktemp)"
    uncovered_lines_file="$(mktemp)"

    local source_file="UNKNOWN"

    # Start the total timer
    local start_total
    start_total=$(date +%s%3N)

    #echo -e "\nCoverage Report:\n"

    # Step 1: Collect coverage output and data per test (single run!)
    for test_function in "${test_functions[@]}"; do
        echo "🔍 Running $test_function..."

        local start_time
        start_time=$(date +%s%3N)

        local coverage_output
        coverage_output="$($test_function)"

        local end_time
        end_time=$(date +%s%3N)
        local elapsed_ms
        elapsed_ms=$((end_time - start_time))
        local elapsed_sec
        elapsed_sec="$((elapsed_ms / 1000)).$(printf "%03d" $((elapsed_ms % 1000)))"

        print_timing_line "✅ $test_function completed in:" "$elapsed_sec"

        # Extract source file if not already done
        if [[ "$source_file" == "UNKNOWN" ]]; then
            source_file=$(echo "$coverage_output" | grep -oP '(?<=<file path=")[^"]+' | head -n 1)
            source_file=$(basename "$source_file")
        fi

        # Collect all lines needing coverage
        echo "$coverage_output" | grep 'lineNumber="' | awk -F'"' '{print $2}' >> "$all_lines_file"

        # Collect covered lines
        echo "$coverage_output" | grep 'covered="true"' | awk -F'"' '{print $2}' >> "$covered_lines_file"
    done

    # Remove duplicates
    sort -u "$all_lines_file" -o "$all_lines_file"
    sort -u "$covered_lines_file" -o "$covered_lines_file"

    # Compute uncovered lines
    comm -23 "$all_lines_file" "$covered_lines_file" > "$uncovered_lines_file"

    # End the total timer
    local end_total
    end_total=$(date +%s%3N)
    local total_elapsed_ms
    total_elapsed_ms=$((end_total - start_total))
    local total_elapsed_sec
     total_elapsed_sec="$((total_elapsed_ms / 1000)).$(printf "%03d" $((total_elapsed_ms % 1000)))"

    echo ""
    print_timing_line "⏱️  Total Runtime:" "$total_elapsed_sec"

    format_coverage_report "$source_file" "$all_lines_file" "$covered_lines_file" "$uncovered_lines_file"

    rm -f "$all_lines_file" "$covered_lines_file" "$uncovered_lines_file"
}



format_missing_lines() {
    # shellcheck disable=SC2207
    local sorted_lines=($(echo "$1" | tr ',' '\n' | sort -n | uniq))
    local formatted=""
    local start=-1
    local prev=-1

    for line in "${sorted_lines[@]}"; do
        if [[ $start -eq -1 ]]; then
            start=$line
        elif [[ $((prev + 1)) -ne $line ]]; then
            if [[ $start -eq $prev ]]; then
                formatted+="${start},"
            else
                formatted+="${start}-${prev},"
            fi
            start=$line
        fi
        prev=$line
    done

    if [[ $start -eq $prev ]]; then
        formatted+="${start}"
    else
        formatted+="${start}-${prev}"
    fi

    echo "$formatted"
}

calculate_coverage() {
    local missed="$1"
    local total="$2"
    awk -v missed="$missed" -v total="$total" 'BEGIN {
        if (total > 0)
            printf "%.2f", 100 - (missed * 100 / total);
        else
            printf "100.00";
    }'
}

format_coverage_report() {
    local source_file="$1"
    local all_lines_file="$2"
    local covered_lines_file="$3"
    local uncovered_lines_file="$4"
    local report_tmp
    report_tmp="$(mktemp)"

    # Compute statistics
    local total_statements
    total_statements=$(wc -l < "$all_lines_file")

    local missed_statements
    missed_statements=$(wc -l < "$uncovered_lines_file")

    local coverage
    if [[ "$total_statements" -gt 0 ]]; then
        coverage=$(calculate_coverage "$missed_statements" "$total_statements")
    else
        coverage="100"
    fi

    # Format missing lines
    local missing_lines
    missing_lines=$(format_missing_lines "$(tr '\n' ',' < "$uncovered_lines_file" | sed 's/,$//')")

    # Store report
    printf "%-30s %6d %6d %6.2f%% %s\n" \
        "$source_file" "$total_statements" "$missed_statements" "$coverage" \
        "${missing_lines:-None}" >> "$report_tmp"

    # Print report
    echo -e "\n📊 Final Coverage Report:\n"
    printf "%-30s %6s %6s %6s %s\n" "Name" "Stmts" "Miss" "Cover" "Missing"
    printf "%-30s %6s %6s %6s %s\n" "------------------------------" "------" "------" "------" "----------------"
    cat "$report_tmp"
    printf "%-30s %6s %6s %6s %s\n" "------------------------------" "------" "------" "------" "----------------"

    rm -f "$report_tmp"
}
