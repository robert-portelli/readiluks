declare -gA CONFIG=(
    [BASE_DIR]="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
    [IMAGENAME]="robertportelli/test-readiluks:latest"
    [DOCKERIMAGE]="ubuntu-latest=${CONFIG[IMAGENAME]}"
    [TEST]=""
    [COVERAGE]=false
    [WORKFLOW]=false
    [BATS_FLAGS]=""
    [DIND_FILE]="docker/test/Docker.dind"
    [DIND_IMAGE]="test-readiluks-dind"
    [DIND_CONTAINER]="test-readiluks-dind-container"
)
