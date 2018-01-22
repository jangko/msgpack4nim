task tests, "Run all tests":
  --r
  --verbosity:0
  --path:"."
  setCommand "c", "tests/tests"

task specTests, "Run spec tests":
  --r
  --verbosity:0
  --path:"."
  setCommand "c", "tests/test_spec"

task codecTests, "Run codec":
  --r
  --verbosity:0
  --path:"."
  setCommand "c", "tests/test_codec"
