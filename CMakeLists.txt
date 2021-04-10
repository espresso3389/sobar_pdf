cmake_minimum_required(VERSION 3.8)
cmake_policy(SET CMP0091 NEW)
project("sobar")

if ("${CMAKE_BUILD_TYPE}" STREQUAL "")
message(FATAL_ERROR "CMAKE_BUILD_TYPE is not defined. It should be either one of Relase, Debug, ...")
endif()

find_package(Git)
if (NOT GIT_FOUND)
  message(FATAL_ERROR "git command not found.")
endif()

include(scripts/common.cmake)

function(SETUP_DEF_BUILD_OPTS_ACPLIB MODULE)
  setup_def_build_opts_with_dep(${MODULE} sobar)
endfunction()

add_subdirectory(build_pdfium)
add_subdirectory(src)
