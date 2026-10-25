LUA_FILES := $(shell find lua plugin -name '*.lua')
TEST_FILES := $(wildcard tests/*.lua)

.PHONY: fmt fmt-check lint test check

fmt:
	stylua $(LUA_FILES) $(TEST_FILES)

fmt-check:
	stylua --check $(LUA_FILES) $(TEST_FILES)

lint:
	selene $(LUA_FILES)

test:
	nvim --clean --headless -u NONE --cmd 'set rtp^=.' -l tests/autosave.lua

check: fmt-check lint test
