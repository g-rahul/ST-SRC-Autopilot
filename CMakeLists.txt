cmake_minimum_required(VERSION 3.2...3.15)

set(PLAT_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" CACHE FILEPATH "PLAT source directory" FORCE)
set(PLAT_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}" CACHE FILEPATH "PLAT binary directory" FORCE)

set(vendor "holybro" CACHE FILEPATH "PLAT source directory" FORCE)
set(model  "kakuteh7v2" CACHE FILEPATH "PLAT binary directory" FORCE)
set(PX4_PLATFORM  "nuttx" CACHE FILEPATH "PLAT binary directory" FORCE)


project(ST-PX4-DevPlat CXX C ASM
        VERSION 1.0
        DESCRIPTION "Board bring-up dev platform"
)

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

include(cmake/plat_config.cmake)


#=============================================================================
# build flags
#
include(px4_add_common_flags)
px4_add_common_flags()
px4_os_add_flags()


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