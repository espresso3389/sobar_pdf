cmake_minimum_required(VERSION 3.21)
cmake_policy(SET CMP0091 NEW)

##########################################################################
# Building pdfium
# See the following document for more info.
# https://pdfium.googlesource.com/pdfium/

set(depot_tools_zip ${SOBAR_TMP_DIR}/depot_tools.zip)
set(depot_tools_dir ${SOBAR_CACHE_DIR}/depot_tools)
set(work_dir ${SOBAR_CACHE_DIR})

if(WIN32)
  set(pdfium_lib_filename "pdfium.lib")
else()
  set(pdfium_lib_filename "libpdfium.a")
endif()

add_library(pdfium STATIC IMPORTED)
set_target_properties(pdfium PROPERTIES IMPORTED_LOCATION ${work_dir}/pdfium/out/${SOBAR_TARGET_STR}${DEBUG_DIR_SUFFIX}/obj/${pdfium_lib_filename})
set_target_properties(pdfium PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${work_dir}/pdfium;${work_dir}/pdfium/third_party/abseil-cpp")
if(APPLE)
  target_link_libraries(pdfium INTERFACE "-framework CoreFoundation")
  target_link_libraries(pdfium INTERFACE "-framework CoreGraphics")
endif()

if("${MSVC_CONFIG}" STREQUAL "static" OR "${SOBAR_TARGET_STR}" MATCHES ".+-static$")
  message("NOTE: Building static (but either /MT or /MTd) library.")
  set(pdfium_config "static")
else()
  # static-md
  set(pdfium_config "dll")
endif()

set(pdfium_reldbg ${CMAKE_BUILD_TYPE})

if(WIN32)
  #
  # Windows
  #
  if(NOT EXISTS ${depot_tools_dir})
    if(NOT EXISTS ${depot_tools_zip})
      message("Downloading depot_tools.zip (Windows) to ${depot_tools_zip}")
      file(DOWNLOAD https://storage.googleapis.com/chrome-infra/depot_tools.zip ${depot_tools_zip})
    endif()
    message("Extracting depot_tools (Windows) to ${depot_tools_dir}")
    execute_process(
      COMMAND powershell -command "Expand-Archive -Path ${depot_tools_zip} -Destination ${depot_tools_dir} -Force"
      RESULT_VARIABLE CMD_RESULT)
    if(NOT CMD_RESULT EQUAL "0")
      message(FATAL_ERROR "Unzipping ${depot_tools_zip} failed.")
    endif()
  endif()

  execute_process(
    COMMAND powershell -command "${CMAKE_CURRENT_SOURCE_DIR}/../scripts/build_pdfium.ps1" ${SOBAR_TARGET_STR} ${SOBAR_ARCH} ${pdfium_config} ${pdfium_reldbg} ${depot_tools_dir} ${work_dir}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    RESULT_VARIABLE CMD_RESULT)
  if(NOT CMD_RESULT EQUAL "0")
    message(FATAL_ERROR "Executing scripts/build_pdfium.ps1 failed.")
  endif()
else()
  #
  # UNIX
  #
  if(NOT EXISTS ${depot_tools_dir})
    execute_process(
      COMMAND git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
      WORKING_DIRECTORY ${SOBAR_CACHE_DIR}
      RESULT_VARIABLE CMD_RESULT)
    if(NOT CMD_RESULT EQUAL "0")
      message(FATAL_ERROR "Cloning depot_tools failed.")
    endif()
  endif()

  execute_process(
    COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/../scripts/build_pdfium.sh" ${SOBAR_TARGET_STR} ${SOBAR_ARCH} ${pdfium_config} ${pdfium_reldbg} ${depot_tools_dir} ${work_dir} ${SOBAR_PLATFORM}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    RESULT_VARIABLE CMD_RESULT)
  if(NOT CMD_RESULT EQUAL "0")
    message(FATAL_ERROR "Executing scripts/build_pdfium.sh failed.")
  endif()
endif()

# For Android build, we should use Android toolchains inside pdfium
if(SOBAR_PLATFORM STREQUAL "android")
  if(SOBAR_ARCH STREQUAL "arm64")
    set(ANDROID_ABI "arm64-v8a")
  elseif(SOBAR_ARCH STREQUAL "arm")
    set(ANDROID_ABI "armeabi-v7a")
  elseif(SOBAR_ARCH STREQUAL "x86")
    set(ANDROID_ABI "x86")
  elseif(SOBAR_ARCH STREQUAL "x64")
    set(ANDROID_ABI "x86_64")
  endif()
  set(ANDROID_LD "LLD")
  set(ANDROID_CPP_FEATURES "rtti exceptions")

  set(CMAKE_TOOLCHAIN_FILE ${work_dir}/pdfium/third_party/android_ndk/build/cmake/android.toolchain.cmake)
  include(${CMAKE_TOOLCHAIN_FILE})

  message("************************************************************")
  message("ANDROID_ABI=${ANDROID_ABI}")
  message("ANDROID_PLATFORM_LEVEL=${ANDROID_PLATFORM_LEVEL}")
  message("ANDROID_TOOLCHAIN_NAME=${ANDROID_LLVM_TRIPLE}")
  message("ANDROID_CXX_COMPILER=${ANDROID_CXX_COMPILER}")
  message("ANDROID_STL=${ANDROID_STL}")
  message("ANDROID_COMPILER_FLAGS_CXX=${ANDROID_COMPILER_FLAGS_CXX}")
  message("ANDROID_CXX_STANDARD_LIBRARIES=${ANDROID_CXX_STANDARD_LIBRARIES}")
  message("ANDROID_LINKER_FLAGS=${ANDROID_LINKER_FLAGS}")
  message("ANDROID_TOOLCHAIN_ROOT=${ANDROID_TOOLCHAIN_ROOT}")
  message("ANDROID_TOOLCHAIN_PREFIX=${ANDROID_TOOLCHAIN_PREFIX}")
  message("CMAKE_SYSROOT=${CMAKE_SYSROOT}")
  message("************************************************************")

endif()

if(SOBAR_PLATFORM STREQUAL "ios")
  unset(CMAKE_INSTALL_NAME_TOOL)
  unset(IOS_PLATFORM CACHE)
  if(SOBAR_ARCH STREQUAL "x64")
    set(IOS_PLATFORM SIMULATOR)
  endif()
  unset(BUILD_ARM64 CACHE)
  unset(CMAKE_IOS_DEVELOPER_ROOT CACHE)
  unset(CMAKE_IOS_SDK_ROOT CACHE)
  unset(CMAKE_OSX_SYSROOT CACHE)
  set(CMAKE_TOOLCHAIN_FILE ${CMAKE_CURRENT_SOURCE_DIR}/../scripts/ios-cmake/toolchain/iOS.cmake)
  include(${CMAKE_TOOLCHAIN_FILE})
endif()

##########################################################################
set(SOBAR_SOURCES
  sobar.cpp
)

if(WIN32)
  set(SOBAR_SOURCES ${SOBAR_SOURCES}
    sobar.def
  )
endif()

if(NOT DEFINED SOBAR_REVISION)
  set(SOBAR_REVISION 0)
endif()
if(SOBAR_COMMIT STREQUAL "")
  set(SOBAR_COMMIT "unknown")
endif()
if(NOT DEFINED SOBAR_FILE_VERSION)
  set(SOBAR_FILE_VERSION "1.0.${SOBAR_REVISION}.0")
endif()
if(NOT DEFINED SOBAR_PRODUCT_VERSION)
  set(SOBAR_PRODUCT_VERSION "1.0.${SOBAR_REVISION}.0")
endif()

configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/version.rc.in
  ${CMAKE_CURRENT_BINARY_DIR}/version.rc
  @ONLY)

add_library(sobar SHARED ${SOBAR_SOURCES} "${CMAKE_CURRENT_BINARY_DIR}/version.rc")

target_include_directories(sobar PUBLIC ${PROJECT_SOURCE_DIR}/include)
target_include_directories(sobar PRIVATE
  .
)

if(UNIX)
  target_compile_options(sobar PRIVATE $<$<COMPILE_LANGUAGE:CXX>:-std=c++14>)
endif()

# setup_def_build_opts_with_dep(sobar dependency)
#target_link_libraries(sobar pdfium -static-libgcc -static-libstdc++)
target_link_libraries(sobar pdfium)

if(UNIX)
  target_link_libraries(sobar)
endif()
