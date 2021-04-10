cmake_policy(SET CMP0091 NEW)

find_package(Git)
if(NOT GIT_FOUND)
  message(FATAL_ERROR "git command not found.")
endif()

#
# hack for static library builds
#
if(WIN32)
  if("${MSVC_CONFIG}" STREQUAL "static" OR "${VCPKG_TARGET_TRIPLET}" MATCHES ".+-static$")
    message("NOTE: Building static (/MT or /MTd) library.")
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    set(vcpkg_triplet_suffix "-static")
    set(VCPKG_LIB_MTMD "MD") # vcpkg bug (libexpatdMD.lib for "static")
  elseif("${MSVC_CONFIG}" SDREQUAL "static-md" OR "${VCPKG_TARGET_TRIPLET}" MATCHES ".+-static-md$")
    message("NOTE: Building msvcrt-static (/MD or /MDd) library.")
    set(vcpkg_triplet_suffix "-static-md")
    set(VCPKG_LIB_MTMD "MD")
  else()
    message("NOTE: Building dynamic (/MD or /MDd) library.")
  endif()
endif()

string(TOLOWER ${CMAKE_SYSTEM_NAME} vcpkg_platform)
if(vcpkg_platform STREQUAL "linux")
  set(LINUX TRUE)
elseif(vcpkg_platform STREQUAL "darwin")
  set(vcpkg_platform "osx")
endif()

if(CMAKE_SIZEOF_VOID_P STREQUAL 8)
  set(vcpkg_arch "x64")
else()
  set(vcpkg_arch "x86")
endif()

#
# VCPKG_TARGET_TRIPLET
#
if("${VCPKG_TARGET_TRIPLET}" STREQUAL "")
  set(VCPKG_TARGET_TRIPLET "${vcpkg_arch}-${vcpkg_platform}${vcpkg_triplet_suffix}")
  message("VCPKG_TARGET_TRIPLET is not explicitly specified; assuming ${VCPKG_TARGET_TRIPLET}")
endif()

#
# By default, CMAKE_BUILD_TYPE=Debug
#
if(CMAKE_BUILD_TYPE STREQUAL "")
  set(CMAKE_BUILD_TYPE "Debug")
endif()

#
# _SOBAR_DEBUG_ definition
#
if(CMAKE_BUILD_TYPE STREQUAL "Release" OR CMAKE_BUILD_TYPE STREQUAL "MinSizeRel")
  message("CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} to SOBAR_DEBUG=0")
  set(SOBAR_DEBUG "0")
else()
  message("CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} to SOBAR_DEBUG=1")
  set(SOBAR_DEBUG "1")
endif()

#
# Installing/initializing vcpkg
#
if(WIN32)
  set(VCPKG_BOOTSTRAP "./bootstrap-vcpkg.bat")
  set(VCPKG_EXENAME "vcpkg.exe")
else()
  set(VCPKG_BOOTSTRAP "./bootstrap-vcpkg.sh")
  set(VCPKG_EXENAME "vcpkg")
endif()
set (VCPKG_INSTALLATION_ROOT ${CMAKE_SOURCE_DIR}/vcpkg)
set (VCPKG_EXECUTABLE ${VCPKG_INSTALLATION_ROOT}/${VCPKG_EXENAME})

#
# vcpkg include/lib directory
#
set(VCPKG_INST_DIR ${VCPKG_INSTALLATION_ROOT}/installed/${VCPKG_TARGET_TRIPLET})
set(VCPKG_INCLUDE_DIR ${VCPKG_INST_DIR}/include)
if(CMAKE_BUILD_TYPE MATCHES ".*Rel.*")
  set(VCPKG_LIB_DIR ${VCPKG_INST_DIR}/lib)
else()
  set(VCPKG_LIB_DIR ${VCPKG_INST_DIR}/debug/lib)
endif()

message("************************************************************")
message("MSVC_CONFIG=${MSVC_CONFIG}")
message("CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}")
message("VCPKG_TARGET_TRIPLET=${VCPKG_TARGET_TRIPLET}")
message("VCPKG_INSTALLATION_ROOT=${VCPKG_INSTALLATION_ROOT}")
message("VCPKG_INCLUDE_DIR=${VCPKG_INCLUDE_DIR}")
message("VCPKG_LIB_DIR=${VCPKG_LIB_DIR}")
message("************************************************************")

#
# vcpkg library name rules; prefix, suffix, extension
#
set(VCPKG_LIBCURL_SUFFIX_D "")
set(VCPKG_SUFFIX_D "")

if(WIN32)
  set(VCPKG_LIB_PREF "")
  set(VCPKG_LIB_EXT ".lib")
  set(VCPKG_ZLIB_NAME "zlib")
  set(VCPKG_SCRIPT_EXT ".bat")
else()
  set(VCPKG_LIB_PREF "lib")
  set(VCPKG_LIB_EXT ".a")
  set(VCPKG_ZLIB_NAME "libz")
  set(VCPKG_SCRIPT_EXT ".sh")
endif()

if(WIN32)
  # Release, Debug, RelWithDebInfo, MinSizeRel
  if(NOT CMAKE_BUILD_TYPE MATCHES ".*Rel.*")
    set(VCPKG_LIBCURL_SUFFIX_D "-d")
    set(VCPKG_SUFFIX_D "d")
  endif()
else()
  if(NOT CMAKE_BUILD_TYPE MATCHES ".*Rel.*")
    set(VCPKG_LIBCURL_SUFFIX_D "-d")
  endif()
endif()

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  set(VCPKG_TARGET_TRIPLET_WITH_CONFIG "${VCPKG_TARGET_TRIPLET}-dbg")
else()
  set(VCPKG_TARGET_TRIPLET_WITH_CONFIG "${VCPKG_TARGET_TRIPLET}-rel")
endif()

if (NOT EXISTS ${VCPKG_INSTALLATION_ROOT}/.git)
  message("Installing vcpkg under ${VCPKG_INSTALLATION_ROOT}...")
  execute_process(
    COMMAND ${GIT_EXECUTABLE} clone https://github.com/microsoft/vcpkg/
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    RESULT_VARIABLE CMD_RESULT)
  if(NOT CMD_RESULT EQUAL "0")
    message(FATAL_ERROR "Cloing vcpkg failed with ${CMD_RESULT}.")
  endif()
endif()
if (NOT EXISTS ${VCPKG_EXECUTABLE})
  execute_process(
    COMMAND ${VCPKG_BOOTSTRAP}
    WORKING_DIRECTORY ${VCPKG_INSTALLATION_ROOT}
    RESULT_VARIABLE CMD_RESULT)
  if(NOT CMD_RESULT EQUAL "0")
    message(FATAL_ERROR "bootstrap-vcpkg failed with ${CMD_RESULT}.")
  endif()
endif()

set (VCPKG_COMMUNITY_TRIPLETS_ROOT ${VCPKG_INSTALLATION_ROOT}/triplets/community)
set (TRIPLETS_SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/vcpkg_triplets)
file(GLOB triplets RELATIVE ${TRIPLETS_SOURCE_DIR} ${TRIPLETS_SOURCE_DIR}/*.cmake)
foreach(t ${triplets})
  if(NOT EXISTS "${VCPKG_COMMUNITY_TRIPLETS_ROOT}/${t}")
    message("Copying ${t} to ${VCPKG_COMMUNITY_TRIPLETS_ROOT}...")
    file(COPY "${TRIPLETS_SOURCE_DIR}/${t}" DESTINATION ${VCPKG_COMMUNITY_TRIPLETS_ROOT})
  endif()
endforeach()

#
# install package using vcpkg
#
function(VCPKG_INSTALL PACKAGE)
  if (NOT ${VCPKG_TARGET_TRIPLET} STREQUAL "")
    set(VCPKG_PACKAGE_FQ "${PACKAGE}:${VCPKG_TARGET_TRIPLET}")
  else()
    set(VCPKG_PACKAGE_FQ "${PACKAGE}")
  endif()
  message("vcpkg: building ${VCPKG_PACKAGE_FQ}...")
  execute_process(
    COMMAND ${VCPKG_EXECUTABLE} install ${VCPKG_PACKAGE_FQ}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    RESULT_VARIABLE CMD_RESULT)
  if(NOT CMD_RESULT EQUAL "0")
    message(FATAL_ERROR "VCPKG_INSTALL ${PACKAGE} failed with ${CMD_RESULT}.")
  endif()
endfunction()

#
# setup module with a dependency
#
function(SETUP_DEF_BUILD_OPTS_WITH_DEP MODULE DEP)
  message("Configuring ${MODULE}...")
  if(WIN32)
    if("${CMAKE_SIZEOF_VOID_P}" STREQUAL "4")
      set(WIN32_ARCH _M_IX86)
    else()
      set(WIN32_ARCH _M_X64)
    endif()

    target_compile_options(${MODULE} PRIVATE
      /DUNICODE /D_UNICODE /D${WIN32_ARCH}
      /D_CRT_SECURE_NO_DEPRECATE /D_CRT_SECURE_CPP_OVERLOAD_STANDARD_NAMES=1
      /EHsc /Zc:wchar_t /Zc:forScope /GR
      $<$<CONFIG:Debug>:/Od /Ob0 /Zi /RTC1 /DDEBUG /D_DEBUG /D_SOBAR_DEBUG_=1>
      $<$<CONFIG:RelWithDebInfo>:/Ox /DNDEBUG /D_SOBAR_DEBUG_=1>
      $<$<CONFIG:Release>:/Ox /DNDEBUG /D_SOBAR_DEBUG_=${SOBAR_DEBUG}>
    )

  elseif(UNIX)
    target_compile_options(${MODULE} PRIVATE
      -fPIC
      $<$<CONFIG:Debug>:-O0 -D_SOBAR_DEBUG_=1>
      $<$<CONFIG:RelWithDebInfo>:-O2 -D_SOBAR_DEBUG_=1>
      $<$<CONFIG:Release>:-O2 -D_SOBAR_DEBUG_=${SOBAR_DEBUG}>
    )
    target_compile_options(${MODULE} PRIVATE $<$<COMPILE_LANGUAGE:CXX>:-std=c++14>)
  endif()

  if (${DEP} STREQUAL "")
    set(DEP sobar)
  endif()

  target_link_libraries(${MODULE} ${DEP})
endfunction()

#
# Installs modules
#
# if (LINUX)
#   vcpkg_install(curl)
#   vcpkg_install(openssl)
# endif()
# vcpkg_install(expat)
# vcpkg_install(oniguruma)
# vcpkg_install(zlib)
