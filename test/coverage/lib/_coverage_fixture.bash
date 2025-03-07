#!/usr/bin/env bash
# shellcheck disable=SC2034

# Declare a global associative array
declare -gA STATEMENTS

# Function to assign values based on input arguments
assign_statements() {
    for arg in "$@"; do
        case "$arg" in
            s1) STATEMENTS[s1]="Statement 1 executed" ;;
            s2) STATEMENTS[s2]="Statement 2 executed" ;;
            s3) STATEMENTS[s3]="Statement 3 executed" ;;
            s4) STATEMENTS[s4]="Statement 4 executed" ;;
            s5) STATEMENTS[s5]="Statement 5 executed" ;;
            s6) STATEMENTS[s6]="Statement 6 executed" ;;
            s7) STATEMENTS[s7]="Statement 7 executed" ;;
            s8) STATEMENTS[s8]="Statement 8 executed" ;;
            *) echo "Invalid statement key: $arg" >&2 ;;
        esac
    done
}
