.PHONY: all setup configure build compile run restart clean distclean rebuild

BUILD_DIR ?= build
MESON ?= meson

all: build

setup configure:
	$(MESON) setup $(BUILD_DIR)

build compile:
	@if [ ! -d "$(BUILD_DIR)" ]; then $(MESON) setup $(BUILD_DIR); fi
	$(MESON) compile -C $(BUILD_DIR)

run: build
	./$(BUILD_DIR)/src/sidewing

restart: build
	@if systemctl --user list-unit-files sidewing.service >/dev/null 2>&1 && \
	    systemctl --user cat sidewing.service >/dev/null 2>&1; then \
	    echo "Restarting sidewing.service via systemd --user"; \
	    systemctl --user restart sidewing.service; \
	else \
	    echo "Restarting sidewing by pkill + background launch"; \
	    pkill -x sidewing || true; \
	    sleep 0.2; \
	    nohup ./$(BUILD_DIR)/src/sidewing >/dev/null 2>&1 & \
	fi

clean:
	@if [ -d "$(BUILD_DIR)" ]; then $(MESON) compile -C $(BUILD_DIR) --clean; fi

distclean:
	rm -rf $(BUILD_DIR)

rebuild: distclean build
