############################################################################
#
# Copyright (c) 2015 - 2020 PX4 Development Team. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
# 3. Neither the name PX4 nor the names of its contributors may be
#    used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
# FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
# ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
############################################################################

# Enforce the presence of the GIT repository
#
# We depend on our submodules, so we have to prevent attempts to
# compile without it being present.
ifeq ($(wildcard .git),)
    $(error YOU HAVE TO USE GIT TO DOWNLOAD THIS REPOSITORY. ABORTING.)
endif


# explicity set default build target
all: 
# define a space character to be able to explicitly find it in strings
space := $(subst ,, )

# Parsing
# --------------------------------------------------------------------
# assume 1st argument passed is the main target, the
# rest are arguments to pass to the makefile generated
# by cmake in the subdirectory
FIRST_ARG := $(firstword $(MAKECMDGOALS))
ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))

# Get -j or --jobs argument as suggested in:
# https://stackoverflow.com/a/33616144/8548472
MAKE_PID := $(shell echo $$PPID)
j := $(shell ps T | sed -n 's|.*$(MAKE_PID).*$(MAKE).* \(-j\|--jobs\) *\([0-9][0-9]*\).*|\2|p')

# Default j for clang-tidy
j_clang_tidy := $(or $(j),4)

NINJA_BIN := ninja
ifndef NO_NINJA_BUILD
	NINJA_BUILD := $(shell $(NINJA_BIN) --version 2>/dev/null)

	ifndef NINJA_BUILD
		NINJA_BIN := ninja-build
		NINJA_BUILD := $(shell $(NINJA_BIN) --version 2>/dev/null)
	endif
endif

ifdef NINJA_BUILD
	PLAT_CMAKE_GENERATOR := Ninja
	PLAT_MAKE := $(NINJA_BIN)

	ifdef VERBOSE
		PLAT_MAKE_ARGS := -v
	else
		PLAT_MAKE_ARGS :=
	endif

	# Only override ninja default if -j is set.
	ifneq ($(j),)
		PLAT_MAKE_ARGS := $(PLAT_MAKE_ARGS) -j$(j)
	endif
else
	ifdef SYSTEMROOT
		# Windows
		PLAT_CMAKE_GENERATOR := "MSYS\ Makefiles"
	else
		PLAT_CMAKE_GENERATOR := "Unix\ Makefiles"
	endif

	# For non-ninja builds we default to -j4
	j := $(or $(j),4)
	PLAT_MAKE = $(MAKE)
	PLAT_MAKE_ARGS = -j$(j) --no-print-directory
endif

SRC_DIR := $(shell dirname "$(realpath $(lastword $(MAKEFILE_LIST)))")

# check if replay env variable is set & set build dir accordingly
ifdef replay
	BUILD_DIR_SUFFIX := _replay
else
	BUILD_DIR_SUFFIX :=
endif

CMAKE_ARGS ?=

# additional config parameters passed to cmake
ifdef EXTERNAL_MODULES_LOCATION
	override CMAKE_ARGS += -DEXTERNAL_MODULES_LOCATION:STRING=$(EXTERNAL_MODULES_LOCATION)
endif

ifdef PX4_CMAKE_BUILD_TYPE
	override CMAKE_ARGS += -DCMAKE_BUILD_TYPE=${PX4_CMAKE_BUILD_TYPE}
endif

# Pick up specific Python path if set
ifdef PYTHON_EXECUTABLE
	override CMAKE_ARGS += -DPYTHON_EXECUTABLE=${PYTHON_EXECUTABLE}
endif

# Functions
# --------------------------------------------------------------------
# describe how to build a cmake config
define cmake-build
	$(eval override CMAKE_ARGS += -DCONFIG=$(1))
	@$(eval BUILD_DIR = "$(SRC_DIR)/build/$(1)")
	@# check if the desired cmake configuration matches the cache then CMAKE_CACHE_CHECK stays empty
	@$(call cmake-cache-check)
	@# make sure to start from scratch when switching from GNU Make to Ninja
	@if [ $(PLAT_CMAKE_GENERATOR) = "Ninja" ] && [ -e $(BUILD_DIR)/Makefile ]; then rm -rf $(BUILD_DIR); fi
	@# make sure to start from scratch if ninja build file is missing
	@if [ $(PLAT_CMAKE_GENERATOR) = "Ninja" ] && [ ! -f $(BUILD_DIR)/build.ninja ]; then rm -rf $(BUILD_DIR); fi
	@# only excplicitly configure the first build, if cache file already exists the makefile will rerun cmake automatically if necessary
	@if [ ! -e $(BUILD_DIR)/CMakeCache.txt ] || [ $(CMAKE_CACHE_CHECK) ]; then \
		mkdir -p $(BUILD_DIR) \
		&& cd $(BUILD_DIR) \
		&& cmake "$(SRC_DIR)" -G"$(PLAT_CMAKE_GENERATOR)" $(CMAKE_ARGS) \
		|| (rm -rf $(BUILD_DIR)); \
	fi
	@# run the build for the specified target
	@cmake --build $(BUILD_DIR) -- $(PLAT_MAKE_ARGS) $(ARGS)
endef

# check if the options we want to build with in CMAKE_ARGS match the ones which are already configured in the cache inside BUILD_DIR
define cmake-cache-check
	@# change to build folder which fails if it doesn't exist and CACHED_CMAKE_OPTIONS stays empty
	@# fetch all previously configured and cached options from the build folder and transform them into the OPTION=VALUE format without type (e.g. :BOOL)
	@$(eval CACHED_CMAKE_OPTIONS = $(shell cd $(BUILD_DIR) 2>/dev/null && cmake -L 2>/dev/null | sed -n 's|\([^[:blank:]]*\):[^[:blank:]]*\(=[^[:blank:]]*\)|\1\2|gp' ))
	@# transform the options in CMAKE_ARGS into the OPTION=VALUE format without -D
	@$(eval DESIRED_CMAKE_OPTIONS = $(shell echo $(CMAKE_ARGS) | sed -n 's|-D\([^[:blank:]]*=[^[:blank:]]*\)|\1|gp' ))
	@# find each currently desired option in the already cached ones making sure the complete configured string value is the same
	@$(eval VERIFIED_CMAKE_OPTIONS = $(foreach option,$(DESIRED_CMAKE_OPTIONS),$(strip $(findstring $(option)$(space),$(CACHED_CMAKE_OPTIONS)))))
	@# if the complete list of desired options is found in the list of verified options we don't need to reconfigure and CMAKE_CACHE_CHECK stays empty
	@$(eval CMAKE_CACHE_CHECK = $(if $(findstring $(DESIRED_CMAKE_OPTIONS),$(VERIFIED_CMAKE_OPTIONS)),,y))
endef

COLOR_BLUE = \033[0;94m
NO_COLOR   = \033[m

define colorecho
+@echo -e '${COLOR_BLUE}${1} ${NO_COLOR}'
endef

# Get a list of all config targets boards/*/*.px4board
ALL_CONFIG_TARGETS := $(shell find ST-PX4-Autopilot-Fork/boards -maxdepth 3 -mindepth 3 -name '*.px4board' -print | sed -e 's|ST-PX4-Autopilot-Fork/boards\/||' | sed -e 's|\.px4board||' | sed -e 's|\/|_|g' | sort)

# ADD CONFIGS HERE
# --------------------------------------------------------------------
#  Do not put any spaces between function arguments.

# All targets.
$(ALL_CONFIG_TARGETS):
	@$(call cmake-build,$@$(BUILD_DIR_SUFFIX))

# Filter for only default targets to allow omiting the "_default" postfix
CONFIG_TARGETS_DEFAULT := $(patsubst %_default,%,$(filter %_default,$(ALL_CONFIG_TARGETS)))
$(CONFIG_TARGETS_DEFAULT):
	@$(call cmake-build,$@_default$(BUILD_DIR_SUFFIX))

all_config_targets: $(ALL_CONFIG_TARGETS)
all_default_targets: $(CONFIG_TARGETS_DEFAULT)

# Cleanup
# --------------------------------------------------------------------
.PHONY: clean submodulesclean submodulesupdate distclean

clean:
	@[ ! -d "$(SRC_DIR)/build" ] || find "$(SRC_DIR)/build" -mindepth 1 -maxdepth 1 -type d -exec sh -c "echo {}; cmake --build {} -- clean || rm -rf {}" \; # use generated build system to clean, wipe build directory if it fails
	@git submodule foreach git clean -dX --force # some submodules generate build artifacts in source
	@rm -rf "$(SRC_DIR)/build"

submodulesclean:
	@git submodule foreach --quiet --recursive git clean -ff -x -d
	@git submodule update --quiet --init --recursive --force || true
	@git submodule sync --recursive
	@git submodule update --init --recursive --force --jobs 4

submodulesupdate:
	@git submodule update --quiet --init --recursive --jobs 4 || true
	@git submodule sync --recursive
	@git submodule update --init --recursive --jobs 4
	@git fetch --all --tags --recurse-submodules=yes --jobs=4

distclean:
	@git submodule deinit --force $(SRC_DIR)
	@rm -rf "$(SRC_DIR)/build"
	@git clean --force -X "$(SRC_DIR)/msg/" "$(SRC_DIR)/platforms/" "$(SRC_DIR)/posix-configs/" "$(SRC_DIR)/ROMFS/" "$(SRC_DIR)/src/" "$(SRC_DIR)/test/" "$(SRC_DIR)/Tools/"

# Help / Error / Misc
# --------------------------------------------------------------------

# All other targets are handled by PX4_MAKE. Add a rule here to avoid printing an error.
%:
	$(if $(filter $(FIRST_ARG),$@), \
		$(error "Make target $@ not found. It either does not exist or $@ cannot be the first argument. Use '$(MAKE) help|list_config_targets' to get a list of all possible [configuration] targets."),@#)

# Print a list of non-config targets (based on http://stackoverflow.com/a/26339924/1487069)
help:
	@echo "Usage: $(MAKE) <target>"
	@echo "Where <target> is one of:"
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | \
		awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | \
		egrep -v -e '^[^[:alnum:]]' -e '^($(subst $(space),|,$(ALL_CONFIG_TARGETS)))$$' -e '_default$$' -e '^(Makefile)'
	@echo
	@echo "Or, $(MAKE) <config_target> [<make_target(s)>]"
	@echo "Use '$(MAKE) list_config_targets' for a list of configuration targets."

# Print a list of all config targets.
list_config_targets:
	@for targ in $(patsubst %_default,%[_default],$(ALL_CONFIG_TARGETS)); do echo $$targ; done
    





