task tests, "Run all tests":
  --r
  --verbosity:0
  setCommand "c", "test/tests"

task cpecTests, "Run spec tests":
  --r
  --verbosity:0
  setCommand "c", "tests/test_spec"

task codecTests, "Run codec":
  --r
  --verbosity:0
  setCommand "c", "tests/test_codec"
