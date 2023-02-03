# Copyright (c) 2022-2023 kounch
# SPDX-License-Identifier: BSD-2-Clause

cmake_minimum_required(VERSION 3.24)
project("Spider-SG-21")
set(ALT_NAME "SpaceMission-SM-11")

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

set(WAV_FILES
    ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/click.wav
    ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/dead.wav
    ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/extra.wav
    ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/gameover.wav
    ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/hand.wav
    )

# Check module availability
find_package(pdc)

add_custom_target("Spider-SG-21" ALL
    DEPENDS ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    )
add_custom_command(
    OUTPUT ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    DEPENDS ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/main.lua
    COMMAND ${PDC_BINARY} -k ${PROJECT_SOURCE_DIR}/${PROJECT_NAME} ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/positions.json ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    COMMENT "Build playdate Binary (Spider)"
    )

add_custom_target("SpaceMission-SM-11" ALL
    DEPENDS ${OUTPUT_DIR}/${ALT_NAME}.pdx
    )
add_custom_command(
    OUTPUT ${PROJECT_SOURCE_DIR}/${ALT_NAME}/main.lua
    DEPENDS ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/main.lua
    COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/main.lua ${PROJECT_SOURCE_DIR}/${ALT_NAME}/main.lua
    COMMAND ${CMAKE_COMMAND} -E copy ${WAV_FILES} ${PROJECT_SOURCE_DIR}/${ALT_NAME}
    MAIN_DEPENDENCY ${PROJECT_SOURCE_DIR}/${PROJECT_NAME}/main.lua
    COMMENT "Prepare Source (Space Mission)"
)   
add_custom_command(
    OUTPUT ${OUTPUT_DIR}/${ALT_NAME}.pdx
    DEPENDS ${PROJECT_SOURCE_DIR}/${ALT_NAME}/main.lua
    COMMAND ${PDC_BINARY} -k ${PROJECT_SOURCE_DIR}/${ALT_NAME} ${OUTPUT_DIR}/${ALT_NAME}.pdx
    COMMAND ${CMAKE_COMMAND} -E copy ${PROJECT_SOURCE_DIR}/${ALT_NAME}/positions.json ${OUTPUT_DIR}/${ALT_NAME}.pdx
    MAIN_DEPENDENCY ${PROJECT_SOURCE_DIR}/${ALT_NAME}/main.lua
    COMMENT "Build playdate Binary (Space Mission)"
)

add_custom_target("simulator-Spider"
    DEPENDS ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    )
add_custom_command(TARGET "simulator-Spider" POST_BUILD
    DEPENDS ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    COMMAND ${SIMULATOR_BIN} ${OUTPUT_DIR}/${PROJECT_NAME}.pdx
    COMMENT "Run Spider on simulator"
    )

add_custom_target("simulator-SpaceMission"
    DEPENDS ${OUTPUT_DIR}/${ALT_NAME}.pdx
    )
add_custom_command(TARGET "simulator-SpaceMission" POST_BUILD
    DEPENDS ${OUTPUT_DIR}/${ALT_NAME}.pdx
    COMMAND ${SIMULATOR_BIN} ${OUTPUT_DIR}/${ALT_NAME}.pdx
    COMMENT "Run Space Mission on simulator"
    )
