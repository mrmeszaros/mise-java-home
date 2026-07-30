PLUGIN_NAME := java-home
PLUGIN_PATH := $(dir $(realpath $(lastword $(MAKEFILE_LIST))))

.PHONY: install uninstall test

install:
	mise plugins install $(PLUGIN_NAME) "file://$(PLUGIN_PATH)"

uninstall:
	mise plugins uninstall $(PLUGIN_NAME)

test:
	bats test/
