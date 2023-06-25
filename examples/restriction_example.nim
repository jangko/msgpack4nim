import std/[streams,unittest]

import msgpack4nim

type
  TA = object of RootObj
  TB = object of TA
    f: int

var
  a: ref TA
  b: ref TB

new(b)
a = b

test "restriction":
  #produces "[ ]", not "[ 0 ]" or '{ "f" : 0 }'
  check stringify(pack(a)) == "[  ] "
