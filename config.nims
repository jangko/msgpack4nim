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

task codecTests, "Run codec test":
  --r
  --verbosity:0
  --path:"."
  setCommand "c", "tests/test_codec"

task jsonTests, "Run json test":
  --r
  --verbosity:0
  --path:"."
  setCommand "c", "tests/test_json"

task anyTests, "Run any test":
  --r
  --verbosity:0
  --path:"."
  setCommand "c", "tests/test_any"

task examplesTests, "Run example test":
  --r
  --verbosity:0
  --path:"."
  setCommand "c", "examples/test"
