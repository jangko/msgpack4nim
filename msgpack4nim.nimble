# Package
version       = "0.4.0"
author        = "Andri Lim"
description   = "MessagePack serializer/deserializer implementation in nim"
license       = "MIT"

# Dependencies
requires "nim >= 1.6.0"

srcDir        = "src"

# Examples and Tests
skipDirs = @["examples", "tests"]

template exec(cmd) =
  echo cmd
  system.exec(cmd)

### Helper functions
proc test(env, path: string) =
  # Compilation language is controlled by TEST_LANG
  var lang = "c"
  if existsEnv"TEST_LANG":
    lang = getEnv"TEST_LANG"

  when defined(macosx):
    let specific = if lang == "cpp":
                     " --passC:\"-Wno-c++11-narrowing\" "
                   else:
                     ""
  else:
    const specific = ""

  if not dirExists "build":
    mkDir "build"
  exec "nim " & lang & " " & env & specific &
    " -r --hints:off --warnings:off " & path

task test, "Run all tests":
  test "-d:debug", "examples/test"
  test "-d:msgpack_obj_to_map", "tests/test_any"
  test "-d:debug", "tests/test_json"
  test "-d:debug", "tests/test_codec"
  test "-d:debug", "tests/test_spec"
  test "-d:debug", "tests/test_suite"

  test "-d:release", "examples/test"
  test "-d:release -d:msgpack_obj_to_map", "tests/test_any"
  test "-d:release", "tests/test_json"

  test "-d:release", "tests/test_codec"
  test "-d:release", "tests/test_spec"
  test "-d:release", "tests/test_suite"
