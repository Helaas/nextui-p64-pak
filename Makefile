###########################################################
# NextUI P64 Pak — parallel-n64 (mupen64plus) libretro core
###########################################################

# Core source
P64_REPO    := https://github.com/libretro/parallel-n64.git
P64_HASH    := 1da824e13e725a7144f3245324f43d59623974f8
CORE_SONAME := parallel_n64_libretro.so

# Pak metadata
PAK_NAME := P64

# Directories
BUILD_DIR   := build
DIST_DIR    := $(BUILD_DIR)/release
STAGING_DIR := $(BUILD_DIR)/staging
CACHE_DIR   := .cache/parallel-n64
SENTINEL    := .cache/.p64-$(P64_HASH)

# Toolchain images
TG5040_TOOLCHAIN := ghcr.io/loveretro/tg5040-toolchain:latest
TG5050_TOOLCHAIN := ghcr.io/loveretro/tg5050-toolchain:latest
MY355_TOOLCHAIN  := ghcr.io/loveretro/my355-toolchain:latest

# Platform-specific CPU tuning flags
TG5040_CPU := -mcpu=cortex-a53 -mtune=cortex-a53
TG5050_CPU := -mcpu=cortex-a55 -mtune=cortex-a55
MY355_CPU  := -mcpu=cortex-a55 -mtune=cortex-a55

# ARM64 architecture defines required by the N64 dynarec/CPU code.
# These must be passed via CPUFLAGS= since the generic unix platform
# path in parallel-n64's Makefile does not set them automatically.
P64_CPUFLAGS := -DNO_ASM -DARM -DARM_ASM -DDONT_WANT_ARM_OPTIMIZATIONS \
                -DARM_FIX -DARM64

# Common build flags passed to the parallel-n64 Makefile.
# FORCE_GLES=1 enables GPU-accelerated rendering via OpenGL ES
# (glide64, gln64, rice plugins) instead of software-only angrylion.
COMMON_FLAGS := platform=unix \
                WITH_DYNAREC=aarch64 \
                HAVE_PARALLEL=0 \
                HAVE_NEON=0 \
                FORCE_GLES=1

# Sysroot fixups for tg5050/my355 toolchains:
# - Missing KHR/khrplatform.h (required by GLES2/gl2.h)
# - libGLESv2.so is an empty stub (no GL symbols exported)
# We provide the header via sysroot-fix/ and tell the linker to
# allow unresolved GL symbols (resolved at runtime by the device
# GPU driver — Mali on both tg5050 and my355).
SYSROOT_FIX_CFLAGS := -I/workspace/sysroot-fix
SYSROOT_FIX_GL     := GL_LIB="-lGLESv2 -Wl,--unresolved-symbols=ignore-all"

# Parallel jobs inside container (auto-detect)
JOBS := $$(nproc)

###########################################################
# Phony targets
###########################################################

.PHONY: all package package-tg5040 package-tg5050 package-my355 \
        tg5040 tg5050 my355 checkout clean distclean help

all: package

help:
	@echo "NextUI P64 Pak build system"
	@echo ""
	@echo "Targets:"
	@echo "  make package          Build all platforms and create .pakz"
	@echo "  make tg5040           Build core for TG5040 only"
	@echo "  make tg5050           Build core for TG5050 only"
	@echo "  make my355            Build core for MY355 only"
	@echo "  make package-tg5040   Build + package .pak for TG5040"
	@echo "  make package-tg5050   Build + package .pak for TG5050"
	@echo "  make package-my355    Build + package .pak for MY355"
	@echo "  make checkout         Clone/update parallel-n64 source"
	@echo "  make clean            Remove build artifacts"
	@echo "  make distclean        Remove build artifacts and cached source"

###########################################################
# Source checkout — pinned to P64_HASH for reproducibility
###########################################################

checkout: $(SENTINEL)

$(SENTINEL):
	@echo "==> Checking out parallel-n64 @ $(P64_HASH)"
	@mkdir -p .cache
	@if [ ! -d "$(CACHE_DIR)/.git" ]; then \
		git clone --depth 1 $(P64_REPO) $(CACHE_DIR); \
	fi
	@cd $(CACHE_DIR) && \
		git fetch --depth=1 origin $(P64_HASH) && \
		git checkout $(P64_HASH) && \
		git submodule update --init --recursive
	@echo "==> Applying patches"
	@cd $(CACHE_DIR) && \
		for p in $(CURDIR)/patches/*.patch; do \
			echo "  Applying $$(basename $$p)"; \
			git apply --whitespace=nowarn "$$p" || exit 1; \
		done
	@touch $(SENTINEL)

###########################################################
# Platform builds — cross-compile inside Docker
###########################################################

# Usage: $(call docker_build,<toolchain-image>,<cpu-flags>,<output-dir>,<extra-cflags>,<extra-make-args>)
define docker_build
	@echo "==> Building $(CORE_SONAME) for $(3)"
	@mkdir -p $(BUILD_DIR)/$(3)
	docker run --rm \
		-v "$(CURDIR)":/workspace \
		-w /workspace/$(CACHE_DIR) \
		$(1) \
		/bin/bash -c '\
			make clean && \
			make \
				$(COMMON_FLAGS) \
				CPUFLAGS="$(P64_CPUFLAGS) $(2) $(4) -fomit-frame-pointer -ffast-math" \
				$(5) \
				-j$(JOBS) && \
			$${CROSS_COMPILE}strip $(CORE_SONAME) \
		'
	@cp $(CACHE_DIR)/$(CORE_SONAME) $(BUILD_DIR)/$(3)/$(CORE_SONAME)
	@echo "==> Built: $(BUILD_DIR)/$(3)/$(CORE_SONAME)"
endef

# tg5040: full GLES sysroot — no fixups needed
tg5040: $(SENTINEL)
	$(call docker_build,$(TG5040_TOOLCHAIN),$(TG5040_CPU),tg5040,,)

# tg5050/my355: need KHR header fix + linker override for empty GLES stubs
tg5050: $(SENTINEL)
	$(call docker_build,$(TG5050_TOOLCHAIN),$(TG5050_CPU),tg5050,$(SYSROOT_FIX_CFLAGS),$(SYSROOT_FIX_GL))

my355: $(SENTINEL)
	$(call docker_build,$(MY355_TOOLCHAIN),$(MY355_CPU),my355,$(SYSROOT_FIX_CFLAGS),$(SYSROOT_FIX_GL))

###########################################################
# Packaging — assemble .pak directories
###########################################################

# Usage: $(call assemble_pak,<platform>)
define assemble_pak
	@echo "==> Assembling $(PAK_NAME).pak for $(1)"
	@rm -rf "$(BUILD_DIR)/$(1)/$(PAK_NAME).pak"
	@mkdir -p "$(BUILD_DIR)/$(1)/$(PAK_NAME).pak"
	@cp launch.sh      "$(BUILD_DIR)/$(1)/$(PAK_NAME).pak/"
	@cp default.cfg    "$(BUILD_DIR)/$(1)/$(PAK_NAME).pak/"
	@cp "$(BUILD_DIR)/$(1)/$(CORE_SONAME)" "$(BUILD_DIR)/$(1)/$(PAK_NAME).pak/"
	@if [ -f LICENSE ]; then cp LICENSE "$(BUILD_DIR)/$(1)/$(PAK_NAME).pak/"; fi
endef

package-tg5040: tg5040
	$(call assemble_pak,tg5040)

package-tg5050: tg5050
	$(call assemble_pak,tg5050)

package-my355: my355
	$(call assemble_pak,my355)

###########################################################
# Final .pakz — multi-platform archive
###########################################################

package: package-tg5040 package-tg5050 package-my355
	@echo "==> Creating $(PAK_NAME).pakz"
	@rm -rf $(STAGING_DIR)
	@mkdir -p $(STAGING_DIR)/Emus/tg5040
	@mkdir -p $(STAGING_DIR)/Emus/tg5050
	@mkdir -p $(STAGING_DIR)/Emus/my355
	@cp -a "$(BUILD_DIR)/tg5040/$(PAK_NAME).pak" $(STAGING_DIR)/Emus/tg5040/
	@cp -a "$(BUILD_DIR)/tg5050/$(PAK_NAME).pak" $(STAGING_DIR)/Emus/tg5050/
	@cp -a "$(BUILD_DIR)/my355/$(PAK_NAME).pak"  $(STAGING_DIR)/Emus/my355/
	@mkdir -p $(DIST_DIR)
	@cd $(STAGING_DIR) && zip -9 -r "$(CURDIR)/$(DIST_DIR)/$(PAK_NAME).pakz" . \
		-x '.DS_Store' '**/.DS_Store'
	@echo "==> Done: $(DIST_DIR)/$(PAK_NAME).pakz"

###########################################################
# Cleanup
###########################################################

clean:
	rm -rf $(BUILD_DIR)

distclean: clean
	rm -rf .cache
