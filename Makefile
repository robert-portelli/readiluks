# 🌳 Show project structure
tree:
	@tree --prune -I "*~|*.bak"

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
