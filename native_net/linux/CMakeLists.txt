# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "native_net")
project(${PROJECT_NAME} LANGUAGES C)

# Invoke the shared CMakeLists.txt from src/ which handles
# finding or building libcurl automatically.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# Make the shared library discoverable by the Flutter app.
set(native_net_bundled_libraries
  "$<TARGET_FILE:native_net>"
  PARENT_SCOPE
)
