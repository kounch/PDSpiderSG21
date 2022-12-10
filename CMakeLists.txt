# Copyright (c) 2022 kounch
# SPDX-License-Identifier: BSD-2-Clause

cmake_minimum_required(VERSION 3.24)
project("Spider-SG-21")

if ( ${CMAKE_SOURCE_DIR} STREQUAL ${CMAKE_BINARY_DIR} )
    message(FATAL_ERROR "In-source builds not allowed. Please make a new directory (called a build directory) and run CMake from there. You may need to remove CMakeCache.txt.")
endif()

list(APPEND CMAKE_MODULE_PATH "${PROJECT_SOURCE_DIR}/CMake/Find")

if (APPLE)
    execute_process(
            COMMAND bash -c "egrep '^\\s*SDKRoot' $HOME/.Playdate/config"
            COMMAND head -n 1
            COMMAND cut -c9-
            OUTPUT_VARIABLE SDK
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    set (SIMULATOR_BIN open)
else()
    set(SDK $ENV{PLAYDATE_SDK_PATH})
    set (SIMULATOR_BIN "${SDK}\bin\Playdate Simulator.exe")
endif()

set(BASENAME ${PROJECT_NAME})
set(OUTPUT_DIR ${CMAKE_BINARY_DIR})

set(CMAKE_PREFIX_PATH
        ${SDK}/bin
        )

# Check module availability
find_package(pdc)

add_custom_target("Spider-SG-21" ALL
    DEPENDS ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    )
add_custom_command(OUTPUT ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    DEPENDS ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/main.lua
    COMMAND ${PDC_BINARY} -k ${PROJECT_SOURCE_DIR}/${PROJECT_NAME} ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    COMMENT "Build playdate Binary"
    )

add_custom_target("simulator"
    DEPENDS ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    )
add_custom_command(TARGET "simulator" POST_BUILD
    DEPENDS ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    COMMAND ${SIMULATOR_BIN} ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    COMMENT "Run on simulator"
    )
