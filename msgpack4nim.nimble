# Package
version       = "0.2.7"
author        = "Andri Lim"
description   = "MessagePack serializer/deserializer implementation in nim"
license       = "MIT"

# Dependencies
requires "nim >= 0.18.0"

# Examples and Tests
skipDirs = @["examples", "tests"]

task test, "Run all tests":
  exec "nim c -r examples/test"
  exec "nim c -r tests/test_any"
  exec "nim c -r tests/test_json"
  exec "nim c -r tests/test_codec"
  exec "nim c -r tests/test_spec"

  when defined(cpu64):
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 examples/test"
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 tests/test_any"
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 tests/test_json"
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 tests/test_codec"
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 tests/test_spec"

  exec "nim c -d:release -r examples/test"
  exec "nim c -d:release -r tests/test_any"
  exec "nim c -d:release -r tests/test_json"
  exec "nim c -d:release -r tests/test_codec"
  exec "nim c -d:release -r tests/test_spec"

  when defined(cpu64):
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 -d:release examples/test"
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 -d:release tests/test_any"
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 -d:release tests/test_json"
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 -d:release tests/test_codec"
    exec "nim c -r --cpu:i386 --passL:-m32 --passC:-m32 -d:release tests/test_spec"
