.PHONY: all setup configure build compile run clean distclean rebuild

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

clean:
	@if [ -d "$(BUILD_DIR)" ]; then $(MESON) compile -C $(BUILD_DIR) --clean; fi

distclean:
	rm -rf $(BUILD_DIR)

rebuild: distclean build
