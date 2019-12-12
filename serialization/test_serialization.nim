import
  strutils, unittest,
  serialization/object_serialization,
  serialization/testing/generic_suite,
  msgpack_serialization


type
  Foo = object
    i: int
    b {.dontSerialize.}: Bar
    s: string

  Bar = object
    sf: seq[Foo]
    z: ref Simple

  Invalid = object
    distance: Mile

  Reserved = object
    # Using Nim reserved keyword
    `type`: string

  MyKind = enum
    Apple
    Banana
    
  MyCaseObject = object
    name: string
    case kind: MyKind
    of Banana: banana: int
    of Apple: apple: string
    
  MyUseCaseObject = object
    field: MyCaseObject
    
# TODO `borrowSerialization` still doesn't work
# properly when it's placed in another module:
Meter.borrowSerialization int

template reject(code) =
  static: doAssert(not compiles(code))

proc `==`(lhs, rhs: Meter): bool =
  int(lhs) == int(rhs)

proc `==`(lhs, rhs: ref Simple): bool =
  if lhs.isNil: return rhs.isNil
  if rhs.isNil: return false
  return lhs[] == rhs[]

executeReaderWriterTests Msgpack


proc newSimple(x: int, y: string, d: Meter): ref Simple =
  new result
  result.x = x
  result.y = y
  result.distance = d

when false:
  # The compiler cannot handle this check at the moment
  # {.fatal.} seems fatal even in `compiles` context
  var invalid = Invalid(distance: Mile(100))
  reject invalid.toMsgpack

suite "misc tests":
  test "max unsigned value":
    var uintVal = not uint64(0)
    let msgpackValue = Msgpack.encode(uintVal)
    check:
      Msgpack.decode(msgpackValue, uint64) == uintVal

  test "Using Nim reserved keyword `type`":
    let r = Reserved(`type`: "uint8")
    check:
      r == Msgpack.decode(Msgpack.encode(r), Reserved)
 
  test "Option types":
    let
      h1 = HoldsOption(o: some Simple(x: 1, y: "2", distance: Meter(3)))
      h2 = HoldsOption(r: newSimple(1, "2", Meter(3)))
 
    check:
      h1 == Msgpack.decode(Msgpack.encode(h1), HoldsOption)
      h2 == Msgpack.decode(Msgpack.encode(h2), HoldsOption)
 
    let y = MyUseCaseObject(field: MyCaseObject(name: "hello", kind: Apple, apple: "world"))
    check:
      y == Msgpack.decode(Msgpack.encode(y), MyUseCaseObject)
    
  