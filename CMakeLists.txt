cmake_minimum_required (VERSION 3.12)
include(ExternalProject)

project (emf2svg)

# Project version (sematic versionning)
set(emf2svg_VERSION_MAJOR 1)
set(emf2svg_VERSION_MINOR 1)
set(emf2svg_VERSION_PATCH 0)
set(emf2svg_VERSION ${emf2svg_VERSION_MAJOR}.${emf2svg_VERSION_MINOR}.${emf2svg_VERSION_PATCH})

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/")

find_package(PNG REQUIRED)
find_package(Freetype REQUIRED)
find_package(Fontconfig REQUIRED)

set(DEPS ${CMAKE_CURRENT_SOURCE_DIR}/deps)

set(DEPS_UEMF ${DEPS}/libUEMF-0.2.5)
set(DEPS_MEMSTREAM ${DEPS}/memstream-0.1)


add_custom_target(tag
    COMMAND git tag -a ${emf2svg_VERSION} -m "tagging version ${emf2svg_VERSION}"
    COMMAND git push origin ${emf2svg_VERSION}
)


# set version as a definition
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DE2S_VERSION='\"${emf2svg_VERSION}\"'")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DE2S_VERSION=${emf2svg_VERSION}")


# Options
option(GCOV      "compile with gcov support"    OFF)
option(UNITTEST  "compile unit tests"           OFF)
option(INDEX     "print record indexes"         OFF)
option(STATIC    "compile statically"           OFF)
option(FORCELE   "force little endian architecture"   OFF)

if(GCOV)
  SET(UNITTEST ON)
  SET(CMAKE_BUILD_TYPE "Debug")
endif(GCOV)

if(INDEX)
    set(CMAKE_C_FLAGS "${CMAKE_CXX_FLAGS} -DRECORD_INDEX='true'")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DRECORD_INDEX='true'")
endif(INDEX)

if(CMAKE_BUILD_TYPE STREQUAL "Debug")
  if(MSVC)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Od -Zi")
  else(MSVC)
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O0 -g")
  endif(MSVC)
    set(CMAKE_BUILD_TYPE Debug)
endif()

if(STATIC)
    set(SHARED "")
    set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
    set(BUILD_SHARED_LIBRARIES OFF)
    set(CMAKE_EXE_LINKER_FLAGS "-static")
else(STATIC)
    set(SHARED "SHARED")
endif(STATIC)

if(UNIX)
  link_libraries(m)
endif(UNIX)

if(NOT FORCELE)
    include(TestBigEndian)
    TEST_BIG_ENDIAN(BIGENDIAN)
    IF(${BIGENDIAN})
        add_definitions(-DWORDS_BIGENDIAN)
    ENDIF(${BIGENDIAN})
endif(NOT FORCELE)

# Build external dependancies if we are on OSX
if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
   # Mac OS X specific code
   set(EXTERNAL_ICONV "iconv")
   set(EXTERNAL_ARGP "argp")
   add_definitions(-DDARWIN)
endif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")

# Build external dependancies if it is Microsoft Visual Studio build
IF(MSVC)
   find_package(Iconv REQUIRED)
   set(EXTERNAL_ICONV ${Iconv_LIBRARY})

   ExternalProject_Add(argp-standalone
     PREFIX ${DEPS}/argp
     GIT_REPOSITORY https://github.com/tom42/argp-standalone.git
     INSTALL_COMMAND ""
   )
   ExternalProject_Get_property(argp-standalone SOURCE_DIR)
   set(ARGP_INCLUDE_DIRS ${SOURCE_DIR}/include/argp-standalone)
   ExternalProject_Get_property(argp-standalone BINARY_DIR)
   set(EXTERNAL_ARGP ${BINARY_DIR}/src/argp-standalone.lib)
ENDIF(MSVC)


# linking directories
#link_directories(
#    ${CMAKE_BINARY_DIR}/
#    /usr/local/lib
#    /usr/lib/
#)


# headers directories
if(MSVC)
  include_directories(
    ./inc
    ${PNG_INCLUDE_DIRS}
    ${FREETYPE_INCLUDE_DIRS}
    ${FONTCONFIG_INCLUDE_DIRS}
    ${ARGP_INCLUDE_DIRS}
    ${DEPS_UEMF}
    ${DEPS_MEMSTREAM}
  )
else(MSVC)
  include_directories(
    ./inc
    ${PNG_INCLUDE_DIRS}
    ${FREETYPE_INCLUDE_DIRS}
    ${FONTCONFIG_INCLUDE_DIRS}
    ${DEPS_UEMF}
    ${DEPS_MEMSTREAM}
    /usr/local/include 
    /usr/include 
    /sw/include
  )
endif(MSVC)

# Compile the library
add_library(emf2svg
    ${SHARED}
    src/lib/pmf2svg.c
    src/lib/pmf2svg_print.c
    ${DEPS_UEMF}/uemf_utf.c
    ${DEPS_UEMF}/uemf_endian.c
    ${DEPS_UEMF}/uemf.c
    ${DEPS_UEMF}/upmf.c
#    ${DEPS_MEMSTREAM}/memstream.c
    src/lib/emf2svg_utils.c
    src/lib/emf2svg_img_utils.c
    src/lib/emf2svg_clip_utils.c
    src/lib/emf2svg_rec_control.c
    src/lib/emf2svg_rec_object_creation.c
    src/lib/emf2svg_rec_path.c
    src/lib/emf2svg_rec_clipping.c
    src/lib/emf2svg_rec_drawing.c
    src/lib/emf2svg_rec_bitmap.c
    src/lib/emf2svg_rec_object_manipulation.c
    src/lib/emf2svg_rec_comment.c
    src/lib/emf2svg_rec_transform.c
    src/lib/emf2svg_rec_state_record.c
    src/lib/emf2svg_print.c
    src/lib/emf2svg.c
)

set_target_properties(emf2svg 
    PROPERTIES 
    VERSION ${emf2svg_VERSION} 
    SOVERSION ${emf2svg_VERSION_MAJOR}
)

# Compile the executable
add_executable(emf2svg-conv src/conv/emf2svg.cpp)
target_link_libraries(emf2svg
    ${PNG_LIBRARIES}
    ${EXTERNAL_ICONV}
    ${FREETYPE_LIBRARIES}
    ${FONTCONFIG_LIBRARIES}
) 

target_link_libraries(emf2svg-conv
    emf2svg
    ${EXTERNAL_ARGP}
)

if(MSVC)
  add_dependencies(emf2svg-conv argp-standalone)
endif(MSVC)

if(GCOV)
  Set(COVERAGE_EXCLUDES '*conv*' '*uemf*' '*upmf*' '*tests*' '*c++*')
  include(CodeCoverage)
  setup_target_for_coverage(NAME coverage
    EXECUTABLE emf2svg-test ./tests/resources/emf*/*
    DEPENDENCIES emf2svg-test
    )
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -g -O0 -fprofile-arcs -ftest-coverage")
  SET(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -g -O0 -fprofile-arcs -ftest-coverage")
endif(GCOV)

if(UNITTEST)
  add_executable(emf2svg-test tests/test.c)

  target_link_libraries(emf2svg-test
    emf2svg
  )
endif(UNITTEST)

if (MSVC)
# x64: suppress mostly harmless warnings about 64 to 32 bit conversion (4244, 4267).
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std:c++14 -W3 -D_CRT_SECURE_NO_WARNINGS -wd4244 -wd4267 -wd4305")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std:c11 -W3 -D_CRT_SECURE_NO_WARNINGS -wd4244 -wd4267 -wd4305")
else(MSVC)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14 -Wall")
  set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -std=c11 -Wall")
endif (MSVC)

if (NOT LIB_INSTALL_DIR)
    set(LIB_INSTALL_DIR lib)
endif ()

if (NOT BIN_INSTALL_DIR)
    set(BIN_INSTALL_DIR bin)
endif ()

if (NOT INCLUDE_INSTALL_DIR)
    set(INCLUDE_INSTALL_DIR include)
endif ()


# install binaries and library
INSTALL(TARGETS emf2svg emf2svg-conv
  RUNTIME DESTINATION ${BIN_INSTALL_DIR}
  LIBRARY DESTINATION ${LIB_INSTALL_DIR}
  ARCHIVE DESTINATION ${LIB_INSTALL_DIR}
)

# install header file
INSTALL(FILES inc/emf2svg.h DESTINATION ${INCLUDE_INSTALL_DIR})
