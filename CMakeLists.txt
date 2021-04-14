cmake_minimum_required(VERSION 3.8)
cmake_policy(SET CMP0091 NEW)
project("sobar")

find_package(Git)
if (NOT GIT_FOUND)
  message(FATAL_ERROR "git command not found.")
endif()

if ("${CMAKE_BUILD_TYPE}" STREQUAL "")
message(FATAL_ERROR "CMAKE_BUILD_TYPE is not defined. It should be either one of Relase, Debug, ...")
endif()

if ("${SOBAR_TARGET_STR}" STREQUAL "")
message(FATAL_ERROR "SOBAR_TARGET_STR is not defined; it should be something like x64-windows or...")
endif()

string(REPLACE "-" ";" Str ${SOBAR_TARGET_STR})
list(GET Str 0 SOBAR_PLATFORM)
list(GET Str 1 SOBAR_ARCH)
message("SOBAR_ARCH=${SOBAR_ARCH},SOBAR_PLATFORM=${SOBAR_PLATFORM}")

if(SOBAR_PLATFORM STREQUAL "linux")
  set(LINUX TRUE)
endif()

if(WIN32)
  if("${SOBAR_TARGET_STR}" MATCHES ".+-static$")
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
  endif()
elseif(LINUX)
  if(SOBAR_ARCH STREQUAL "x86")
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -m32")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -m32")
  endif()
endif()

#
# By default, CMAKE_BUILD_TYPE=Debug
#
if(CMAKE_BUILD_TYPE STREQUAL "")
  set(CMAKE_BUILD_TYPE "Debug")
endif()

message("************************************************************")
message("CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
message("SOBAR_TARGET_STR=${SOBAR_TARGET_STR}")
message("************************************************************")

add_subdirectory(src)
