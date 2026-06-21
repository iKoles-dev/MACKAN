.SHELL := /bin/bash

APP_NAME ?= MACKAN
BUILD_ROOT ?= $(CURDIR)/.build/mackan-app
APP_PATH ?= $(BUILD_ROOT)/$(APP_NAME).app
AUTO_CLEAN_SERVICE_PUBLISH ?= true
SERVICE_PUBLISH_DIR := $(BUILD_ROOT)/service-publish
SERVICE_PUBLISH_CLEAN_CMD = \
	if [ "$(AUTO_CLEAN_SERVICE_PUBLISH)" = "true" ] && [ -d "$(SERVICE_PUBLISH_DIR)" ]; then \
		rm -rf "$(SERVICE_PUBLISH_DIR)"; \
	fi

SCRIPTS_DIR := macosx/MACKAN/scripts
BUILD_APP := $(SCRIPTS_DIR)/build-dev-app.sh
BUILD_DMG := $(SCRIPTS_DIR)/package-dmg.sh

.PHONY: app app-universal run run-universal dmg dmg-universal clean clean-staging path launcher run-gui run-gui-universal

LAUNCHER_SCRIPT := macosx/MACKAN/scripts/launch-no-console.applescript
LAUNCHER_DIR := $(BUILD_ROOT)/launchers
LAUNCHER_APP := $(LAUNCHER_DIR)/MACKAN-Launcher.app

app:
	BUILD_ROOT="$(BUILD_ROOT)" $(BUILD_APP)
	@$(SERVICE_PUBLISH_CLEAN_CMD)

app-universal:
	BUILD_ROOT="$(BUILD_ROOT)" $(BUILD_APP) --universal
	@$(SERVICE_PUBLISH_CLEAN_CMD)

run:
	@app_path="$$( BUILD_ROOT="$(BUILD_ROOT)" $(BUILD_APP))"; open "$$app_path"
	@$(SERVICE_PUBLISH_CLEAN_CMD)

run-universal:
	@app_path="$$( BUILD_ROOT="$(BUILD_ROOT)" $(BUILD_APP) --universal)"; open "$$app_path"
	@$(SERVICE_PUBLISH_CLEAN_CMD)

$(LAUNCHER_APP): $(LAUNCHER_SCRIPT)
	mkdir -p "$(LAUNCHER_DIR)"
	osacompile -o "$(LAUNCHER_APP)" "$(LAUNCHER_SCRIPT)"

launcher: $(LAUNCHER_APP)
	@:

run-gui: launcher
	@open "$(LAUNCHER_APP)" --args --build-root "$(BUILD_ROOT)"

run-gui-universal: launcher
	@open "$(LAUNCHER_APP)" --args --build-root "$(BUILD_ROOT)" --universal

dmg:
	@dmg_path="$$( BUILD_ROOT="$(BUILD_ROOT)" $(BUILD_DMG) )"; open "$$dmg_path"
	@$(SERVICE_PUBLISH_CLEAN_CMD)

dmg-universal:
	@dmg_path="$$( BUILD_ROOT="$(BUILD_ROOT)" $(BUILD_DMG) --universal)"; open "$$dmg_path"
	@$(SERVICE_PUBLISH_CLEAN_CMD)

clean:
	rm -rf "$(BUILD_ROOT)"

clean-staging:
	@$(SERVICE_PUBLISH_CLEAN_CMD)

path:
	@echo "$(APP_PATH)"
