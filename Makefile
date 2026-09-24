PLUGIN_NAME := java-home
PLUGIN_PATH := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))
GIT_REMOTE := $(git remote get-url origin)

.PHONY: install dev-install uninstall test lint

install:
	mise plugins install --force $(PLUGIN_NAME) "$(GIT_REMOTE)"

dev-install:
	mise plugin link --force $(PLUGIN_NAME) "$(PLUGIN_PATH)"

uninstall:
	mise plugins uninstall $(PLUGIN_NAME)

test:
	bats test/

lint:
	ec
