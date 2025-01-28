# Filename: test/lib/log_test_output.bash

# Resolve BASE_DIR relative to this script
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Source the production logger
source "${BASE_DIR}/src/lib/log_prod_output.bash"
