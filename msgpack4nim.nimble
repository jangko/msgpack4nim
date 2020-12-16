# Package
version       = "0.3.1"
author        = "Andri Lim"
description   = "MessagePack serializer/deserializer implementation in nim"
license       = "MIT"

# Dependencies
requires "nim >= 0.18.0"

installFiles = @["msgpack4nim.nim", "msgpack4collection.nim", "msgpack2any.nim", "msgpack2json.nim"]

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
  # because uses `getAppDir()`, see https://github.com/nim-lang/Nim/pull/13382
  test "-d:debug --outdir:tests", "tests/test_json"
  test "-d:debug", "tests/test_codec"
  test "-d:debug", "tests/test_spec"
  test "-d:debug", "tests/test_suite"

  test "-d:release", "examples/test"
  test "-d:release -d:msgpack_obj_to_map", "tests/test_any"
  # ditto
  test "-d:release --outdir:tests", "tests/test_json"

  test "-d:release", "tests/test_codec"
  test "-d:release", "tests/test_spec"
  test "-d:release", "tests/test_suite"
