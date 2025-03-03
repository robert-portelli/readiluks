# 🌳 Show project structure
tree:
	@tree --prune -I "*~|*.bak"

find-refs:
	@grep -Rni --binary-files=without-match --exclude-dir={.git,venv,.cache} --exclude='*~' --exclude='*.bak' "$(SEARCH)" $${START:-.} | cut -d: -f1,2

replace-refs:
	@grep -Rl --binary-files=without-match --exclude-dir={.git,venv,.cache} --exclude='*~' --exclude='*.bak' "$(SEARCH)" $${START:-.} | xargs -d '\n' sed -i "s/$(SEARCH)/$(REPLACE)/g"
