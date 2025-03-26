build-inner-systemd:
	docker buildx build --load \
		-t robertportelli/readiluks-systemd-inner:latest \
		-f docker/test/Dockerfile.inner-harness-harness-systemd .

# 🌳 Show project structure
tree:
	@tree --prune -a -I "*~|*.bak|.git"

# Find references to a given string in the project directory.
# Usage:
#     make find-refs SEARCH=<string> [START=<directory>]
# Arguments:
#     SEARCH  - The string to search for in file names and file contents.
#     START   - (Optional) The directory to start searching from. Defaults to the current directory.
# Behavior:
#     - Searches for files with names matching *SEARCH*.
#     - Searches for occurrences of SEARCH within files, excluding .git, venv, and .cache directories.
#     - Prints matching file paths and line numbers.
find-refs:
	@find $${START:-.} -type f \
		! -path "*/.git/*" \
		! -path "*/venv/*" \
		! -path "*/.cache/*" \
		! -name "*~" \
		! -name "*.bak" \
		-name "*$(SEARCH)*"
	@grep -Rni --binary-files=without-match \
		--exclude-dir={.git,venv,.cache} \
		--exclude='*~' \
		--exclude='*.bak' \
		"$(SEARCH)" $${START:-.} | cut -d: -f1,2

# Replace references to a given string in file names and file contents.
# Usage:
#     make replace-refs SEARCH=<string> REPLACE=<string> [START=<directory>]
# Arguments:
#     SEARCH  - The string to search for and replace.
#     REPLACE - The string to replace SEARCH with.
#     START   - (Optional) The directory to start replacing from. Defaults to the current directory.
# Behavior:
#     - Replaces occurrences of SEARCH with REPLACE in file contents.
#     - Renames files containing SEARCH in their names to use REPLACE instead.
#     - Excludes .git, venv, and .cache directories.
replace-refs:
	@grep -Rl --binary-files=without-match --exclude-dir={.git,venv,.cache} --exclude='*~' --exclude='*.bak' "$(SEARCH)" $${START:-.} | xargs -d '\n' sed -i "s/$(SEARCH)/$(REPLACE)/g"
	@find $${START:-.} -type f \
		! -path "*/.git/*" \
		! -path "*/venv/*" \
		! -path "*/.cache/*" \
		! -name "*~" \
		! -name "*.bak" \
		-name "*$(SEARCH)*" \
		-exec bash -c 'mv "$$0" "$${0//$(SEARCH)/$(REPLACE)}"' {} \;
