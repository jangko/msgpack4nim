import ../msgpack4nim, streams

type
  #lets try with a many members with different types object
  CustomType = object
    count: int
    content: seq[int]
    name: string
    ratio: float
    attr: array[0..5, int]
    ok: bool

proc initCustomType(): CustomType =
  result.count = -1
  result.content = @[1,2,3]
  result.name = "custom"
  result.ratio = 1.0
  for i in 0..5: result.attr[i] = i
  result.ok = false

var x = initCustomType()
var s = newStringStream()
s.pack(x) #here the magic happened

s.setPosition(0)
var xx: CustomType
s.unpack(xx) #and here too

assert xx == x
echo "OK ", xx.name