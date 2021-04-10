# Building pdfium
# See the following document for more info.
# https://pdfium.googlesource.com/pdfium/
cmake_minimum_required(VERSION 3.8)
cmake_policy(SET CMP0091 NEW)

set(depot_tools_zip ${CMAKE_CURRENT_BINARY_DIR}/depot_tools.zip)
set(depot_tools_dir ${CMAKE_CURRENT_BINARY_DIR}/depot_tools)

if(CMAKE_SIZEOF_VOID_P STREQUAL 8)
  set(pdfium_arch "x64")
else()
  set(pdfium_arch "x86")
endif()

if("${MSVC_CONFIG}" STREQUAL "static" OR "${VCPKG_TARGET_TRIPLET}" MATCHES ".+-static$")
  message("NOTE: Building static (/MT or /MTd) library.")
  set(pdfium_config "static")
else()
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
      WORKING_DIRECTORY ${depot_tools_dir}
      RESULT_VARIABLE CMD_RESULT)
    if(NOT CMD_RESULT EQUAL "0")
      message(FATAL_ERROR "Unzipping ${depot_tools_zip} failed.")
    endif()
endif()

  execute_process(
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/depot_init.bat ${VCPKG_TARGET_TRIPLET} ${pdfium_arch} ${pdfium_config} ${pdfium_reldbg} ${depot_tools_dir}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    RESULT_VARIABLE CMD_RESULT)
  if(NOT CMD_RESULT EQUAL "0")
    message(FATAL_ERROR "Executing scripts/depot_init.bat failed.")
  endif()
else()
  #
  # UNIX
  #
  if(NOT EXISTS ${depot_tools_dir})
    execute_process(
      COMMAND git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      RESULT_VARIABLE CMD_RESULT)
    if(NOT CMD_RESULT EQUAL "0")
      message(FATAL_ERROR "Cloning depot_tools failed.")
    endif()
  endif()

  execute_process(
    COMMAND ${CMAKE_CURRENT_SOURCE_DIR}/scripts/build.sh ${VCPKG_TARGET_TRIPLET} ${pdfium_arch} ${pdfium_config} ${pdfium_reldbg} ${depot_tools_dir}
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
    RESULT_VARIABLE CMD_RESULT)
  if(NOT CMD_RESULT EQUAL "0")
    message(FATAL_ERROR "Executing scripts/depot_init failed.")
  endif()
endif()
