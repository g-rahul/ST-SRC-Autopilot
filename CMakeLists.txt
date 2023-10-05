#=============================================================================
# Initial Configuration
#======================

cmake_minimum_required(VERSION 3.2...3.15)

# Platform Path Config
set(PLAT_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE FILEPATH "PLAT source directory" FORCE)
set(PLAT_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}" CACHE FILEPATH "PLAT binary directory" FORCE)
set(PX4_SOURCE_DIR ${PLAT_SOURCE_DIR}/ST-PX4-Autopilot-Fork/ CACHE FILEPATH "PX4 source directory" FORCE)

# Platform Include Paths
list(APPEND CMAKE_MODULE_PATH ${PLAT_SOURCE_DIR}/cmake)

# Find Python
find_package(PythonInterp 3)
# We have a custom error message to tell users how to install python3.
if(NOT PYTHONINTERP_FOUND)
	message(FATAL_ERROR "Python 3 not found. Please install Python 3:\n"
		"    Ubuntu: sudo apt install python3 python3-dev python3-pip\n"
		"    macOS: brew install python")
endif()

#Include PX4 Board parser config and initial PX4 Config files
include(px4_config)
include(kconfig)
message(STATUS "PX4 config: ${PX4_CONFIG}")
message(STATUS "PX4 platform: ${PX4_PLATFORM}")

include(px4_impl_os.cmake)
#list(APPEND CMAKE_MODULE_PATH ${PX4_SOURCE_DIR}/platforms/${PX4_PLATFORM}/cmake)
include(init)

#=============================================================================
# Project Specific
#==================
project(ST-PX4-BUPLAT CXX C ASM)

# CMake build type (Debug Release RelWithDebInfo MinSizeRel Coverage)
if(NOT CMAKE_BUILD_TYPE)
	if(${PX4_PLATFORM} STREQUAL "nuttx")
		set(PX4_BUILD_TYPE "MinSizeRel")
	else()
		set(PX4_BUILD_TYPE "RelWithDebInfo")
	endif()

	set(CMAKE_BUILD_TYPE ${PX4_BUILD_TYPE} CACHE STRING "Build type" FORCE)
endif()

set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS "Debug;Release;RelWithDebInfo;MinSizeRel;Coverage;AddressSanitizer;UndefinedBehaviorSanitizer")
message(STATUS "cmake build type: ${CMAKE_BUILD_TYPE}")

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
# set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${PLAT_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${PLAT_BINARY_DIR})
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${PLAT_BINARY_DIR})



#=============================================================================
# get chip and chip manufacturer
#
px4_os_determine_build_chip()
if(NOT PX4_CHIP_MANUFACTURER)
	message(FATAL_ERROR "px4_os_determine_build_chip() needs to set PX4_CHIP_MANUFACTURER")
endif()
if(NOT PX4_CHIP)
	message(FATAL_ERROR "px4_os_determine_build_chip() needs to set PX4_CHIP")
endif()


#=============================================================================
# build flags
##===========
include(px4_add_common_flags)
px4_add_common_flags()
px4_os_add_flags()

#=============================================================================
# Nuttx Kernel Build Hooks
##========================
# firmware added last to generate the builtin for included modules
add_subdirectory(platforms/${PX4_PLATFORM})

#[[
#=============================================================================
# Test Platform Config
##===========

include_directories(
        src
        ${NUTTX_PATH}/include
        ${NUTTX_PATH}/include/libcxx
        ${NUTTX_PATH}/arch/chip
)

set(EXE_NAME hellocpp)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} ${AC_HW_FLAGS} ${AC_DEFINES}")
set(CMAKE_CXX_FLAGS     "${AC_HW_FLAGS} ${AC_DEFINES} ${AC_COMMON_FLAGS} ${AC_CXX_EXTRA_FLAGS}")
if (PARAM_DEBUG)
    set(CMAKE_CXX_FLAGS     "${CMAKE_CXX_FLAGS} -g")
endif()

set(CMAKE_SKIP_RPATH ON)
set(CMAKE_CXX_LINK_EXECUTABLE "${CMAKE_LINKER} ${AC_LINKER_FLAGS} -o ${EXE_NAME}.elf <OBJECTS> <LINK_LIBRARIES>")
set(BUILD_SHARED_LIBS OFF)
add_subdirectory(src)
]]