import streams, endians, strutils, sequtils, algorithm, math, hashes
import tables, intsets, lists, queues, sets, strtabs, critbits
import msgpack

type
  Choco = object
    a: int
    b: int

  Chocolate = object
    a: Choco
    b: int

proc hash*(c: Choco): Hash =
  var h: Hash = 0
  h = h !& c.a
  h = h !& c.b

  result = !$ h

proc testOrdinal() =
  var
    s = newStringStream()
    a = true
    b = false

  s.pack(a)
  s.pack(b)
  for i in low(char)..high(char): s.pack(i)
  for i in low(int8)..high(int8): s.pack(i)
  for i in low(uint8)..high(uint8): s.pack(i)

  s.setPosition(0)
  var aa,bb:bool
  s.unpack(aa)
  s.unpack(bb)
  doAssert aa == a
  doAssert bb == b

  var cc: char
  var dd: int8
  var ee: uint8
  for i in low(char)..high(char):
    s.unpack(cc)
    doAssert cc == i
  echo "char"

  for i in low(int8)..high(int8):
    s.unpack(dd)
    doAssert dd == i
  echo "int8"

  for i in low(uint8)..high(uint8):
    s.unpack(ee)
    doAssert ee == i
  echo "uint8"

proc testOrdinal2() =

  block escape:
    while true:
      var s = newStringStream()
      for i in low(int16)..high(int16): s.pack(i)
      s.setPosition(0)
      var x: int16
      for i in low(int16)..high(int16):
        s.unpack(x)
        if x != i:
          echo "miss int16: ", $x, " vs ", $i
          break escape
      echo "int16"
      break

  block escape2:
    while true:
      var s = newStringStream()
      for i in low(uint16)..high(uint16): s.pack(i)
      s.setPosition(0)
      var x: uint16
      for i in low(uint16)..high(uint16):
        s.unpack(x)
        if x != i:
          echo "miss uint16: ", $x, " vs ", $i
          break escape2
      echo "uint16"
      break

proc testOrdinal3() =
  var uu = [low(int32), low(int32)+1, low(int32)+2, high(int32)-1,
    high(int32)-2, low(int8)-2, low(int8)-1, low(int8), low(int8)+1,
    low(int8)+2, low(int16)-2, low(int16)-1, low(int16), low(int16)+1,
    low(int16)+2, high(int8)-2, high(int8)-1, high(int8), high(int8)+1,
    high(int8)+2, high(int16)-2, high(int16)-1, high(int16), high(int16)+1,
    high(int16)+2,high(int32)]

  block escape:
    while true:
      var s = newStringStream()
      var x: int32
      for i in uu:
        s.pack(i)
        s.setPosition(0)
        s.unpack(x)
        s.setPosition(0)
        if x != i:
          echo "miss int32: ", $x, " vs ", $i
          break escape

      echo "int32"
      break

  var vv = [low(uint32), low(uint32)+1, low(uint32)+2, high(uint32), high(uint32)-1,
    high(uint32)-2, low(uint8), low(uint8)+1, low(uint8)+2, low(uint16)+1,
    low(uint16)+2, high(uint8)-2, high(uint8)-1, high(uint8), high(uint8)+1,
    high(uint8)+2, high(uint16)-2, high(uint16)-1, high(uint16), high(uint16)+1,
    high(uint16)+2]

  block escape2:
    while true:
      var s = newStringStream()
      var x: uint32
      for i in vv:
        s.pack(i)
        s.setPosition(0)
        s.unpack(x)
        s.setPosition(0)
        if x != i:
          echo "miss uint32: ", $x, " vs ", $i
          break escape2

      echo "uint32"
      break

proc testOrdinal4() =
  var uu = [high(int64), low(int32), low(int32)+1, low(int32)+2, high(int32)-1,
    high(int32)-2, low(int8)-2, low(int8)-1, low(int8), low(int8)+1,
    low(int8)+2, low(int16)-2, low(int16)-1, low(int16), low(int16)+1,
    low(int16)+2, high(int8)-2, high(int8)-1, high(int8), high(int8)+1,
    high(int8)+2, high(int16)-2, high(int16)-1, high(int16), high(int16)+1,
    high(int16)+2,high(int32), low(int64)+1, low(int64)+2, low(int64),
    high(int64)-1, high(int64)-2, low(int64),low(int64)+1,low(int64)+2,
    low(int32)-1,low(int32)-2]

  block escape:
    while true:
      var s = newStringStream()
      var x: int64
      for i in uu:
        s.pack(i)
        s.setPosition(0)
        s.unpack(x)
        s.setPosition(0)
        if x != i:
          echo "miss int64: ", $x, " vs ", $i
          break escape

      echo "int64"
      break

  var vv = [0xFFFFFFFFFFFFFFFFFFFFFF'u64, low(uint32), low(uint32)+1, low(uint32)+2, high(uint32), high(uint32)-1,
    high(uint32)-2, low(uint8), low(uint8)+1, low(uint8)+2, low(uint16)+1,
    low(uint16)+2, high(uint8)-2, high(uint8)-1, high(uint8), high(uint8)+1,
    high(uint8)+2, high(uint16)-2, high(uint16)-1, high(uint16), high(uint16)+1,
    high(uint16)+2, 0xFFFFFFFFFFFFFFFFFFFFFF'u64-1, 0xFFFFFFFFFFFFFFFFFFFFFF'u64-2]

  block escape2:
    while true:
      var s = newStringStream()
      var x: uint64
      for i in vv:
        s.pack(i)
        s.setPosition(0)
        s.unpack(x)
        s.setPosition(0)
        if x != i:
          echo "miss uint64: ", $x, " vs ", $i
          break escape2

      echo "uint64"
      break

proc testString() =
  var d = "hello"
  var e = repeat('a', 200)
  var f = repeat('b', 3000)
  var g = repeat('c', 70000)
  var s = newStringStream()

  var dd,ee,ff,gg: string
  s.pack(d)
  s.pack(e)
  s.pack(f)
  s.pack(g)

  s.setPosition(0)
  s.unpack(dd)
  doAssert dd == d
  s.unpack(ee)
  s.unpack(ff)
  s.unpack(gg)
  doAssert ee == e
  doAssert ff == f
  doAssert gg == g
  echo "string"

proc testReal() =
  var xx = [-1.0'f32, -2.0, 0.0, Inf, NegInf, 1.0, 2.0]

  block escape:
    while true:
      var s = newStringStream()
      var x: float32
      for i in xx:
        s.pack(i)
        s.setPosition(0)
        s.unpack(x)
        s.setPosition(0)
        if x != i:
          echo "miss: ", $x, " vs ", $i
          break escape

      echo "float32"
      break

  var vv = [-1.0'f64, -2.0, 0.0, Inf, NegInf, 1.0, 2.0]

  block escape:
    while true:
      var s = newStringStream()
      var x: float64
      for i in vv:
        s.pack(i)
        s.setPosition(0)
        s.unpack(x)
        s.setPosition(0)
        if x != i:
          echo "miss: ", $x, " vs ", $i
          break escape

      echo "float64"
      break

proc testSet() =
  type
    side = enum
      ssleft, ssright, sstop, ssbottom

  var x,xx:set['a'..'z']
  var y,yy:set[0..10]
  var z:set[side]
  var a:int = -10
  var b:uint = 10
  var aa:int
  var bb:uint

  x.incl('b')
  x.incl('c')

  y.incl(1)
  y.incl(7)

  z.incl(ssleft)
  z.incl(sstop)
  z.incl(ssbottom)
  z.incl(ssright)

  var s = newStringStream()
  s.pack(x)
  s.pack(y)
  s.pack(a)
  s.pack(b)

  s.setPosition(0)
  s.unpack(xx)
  s.unpack(yy)
  doAssert x == xx
  doAssert y == yy
  s.unpack(aa)
  s.unpack(bb)
  doAssert a == aa
  doAssert b == bb

  echo "set"

proc testContainer() =
  proc `==`(a,b: IntSet): bool =
    var xx = toSeq(items(a))
    var yy = toSeq(items(b))
    xx.sort(cmp[int])
    yy.sort(cmp[int])
    result = xx == yy

  proc `==`(a,b: SinglyLinkedList[Choco]): bool =
    var xx = toSeq(items(a))
    var yy = toSeq(items(b))
    result = xx == yy

  proc `==`(a,b: DoublyLinkedList[Choco]): bool =
    var xx = toSeq(items(a))
    var yy = toSeq(items(b))
    result = xx == yy

  proc `==`(a,b: SinglyLinkedRing[Choco]): bool =
    var xx = toSeq(items(a))
    var yy = toSeq(items(b))
    result = xx == yy

  proc `==`(a,b: DoublyLinkedRing[Choco]): bool =
    var xx = toSeq(items(a))
    var yy = toSeq(items(b))
    result = xx == yy

  proc `==`(a,b: Queue[Choco]): bool =
    var xx = toSeq(items(a))
    var yy = toSeq(items(b))
    result = xx == yy

  proc `==`(a,b: HashSet[Choco]): bool =
    var xx = toSeq(items(a))
    var yy = toSeq(items(b))
    result = xx == yy

  proc `==`(a,b: OrderedSet[Choco]): bool =
    var xx = toSeq(items(a))
    var yy = toSeq(items(b))
    result = xx == yy

  proc `==`(a,b: CritBitTree[void]): bool =
    var xx = toSeq(items(a))
    var yy = toSeq(items(b))
    result = xx == yy

  var a = initIntSet()
  a.incl(-2)
  a.incl(-1)
  a.incl(0)
  a.incl(1)
  a.incl(2)

  var b = initSinglyLinkedList[Choco]()
  var c = initDoublyLinkedList[Choco]()
  var d = initSinglyLinkedRing[Choco]()
  var e = initDoublyLinkedRing[Choco]()
  var f = initQueue[Choco]()
  var g = initSet[Choco]()
  var h = initOrderedSet[Choco]()
  var k : CritBitTree[void]
  var x = Choco(a:1,b:2)
  var y = Choco(a:3,b:4)
  b.prepend(x)
  b.prepend(y)
  c.prepend(x)
  c.prepend(y)
  d.prepend(x)
  d.prepend(y)
  e.prepend(x)
  e.prepend(y)
  f.add(x)
  f.add(y)
  g.incl(x)
  g.incl(y)
  h.incl(x)
  h.incl(y)
  k.incl("hello")
  k.incl("world")

  var s = newStringStream()
  s.pack(a)
  s.pack(b)
  s.pack(c)
  s.pack(d)
  s.pack(e)
  s.pack(f)
  s.pack(g)
  s.pack(h)
  s.pack(k)

  s.setPosition(0)
  var aa: IntSet
  var bb: SinglyLinkedList[Choco]
  var cc: DoublyLinkedList[Choco]
  var dd: SinglyLinkedRing[Choco]
  var ee: DoublyLinkedRing[Choco]
  var ff: Queue[Choco]
  var gg: HashSet[Choco]
  var hh: OrderedSet[Choco]
  var kk: CritBitTree[void]

  s.unpack(aa)
  s.unpack(bb)
  s.unpack(cc)
  s.unpack(dd)
  s.unpack(ee)
  s.unpack(ff)
  s.unpack(gg)
  s.unpack(hh)
  s.unpack(kk)

  doAssert aa == a
  doAssert bb == b
  doAssert cc == c
  doAssert dd == d
  doAssert ee == e
  doAssert ff == f
  doAssert gg == g
  doAssert hh == h
  doAssert kk == k

  echo "container"

proc testMap() =
  proc `==`(a,b: OrderedTable[string, Choco]): bool =
    var xx,yy: seq[tuple[a:string, b:Choco]]
    xx = @[]
    yy = @[]
    for k,v in pairs(a): xx.add((k,v))
    for k,v in pairs(b): yy.add((k,v))
    result = xx == yy

  proc `==`(a,b: OrderedTableRef[string, Choco]): bool =
    var xx,yy: seq[tuple[a:string, b:Choco]]
    xx = @[]
    yy = @[]
    for k,v in pairs(a): xx.add((k,v))
    for k,v in pairs(b): yy.add((k,v))
    result = xx == yy

  proc equal(a,b: StringTableRef): bool =
    var xx,yy: seq[tuple[a:string, b:string]]
    xx = @[]
    yy = @[]
    for k,v in pairs(a): xx.add((k,v))
    for k,v in pairs(b): yy.add((k,v))
    result = xx == yy

  proc equal(a,b: CritBitTree[Choco]): bool =
    var xx,yy: seq[tuple[a:string, b:Choco]]
    xx = @[]
    yy = @[]
    for k,v in pairs(a): xx.add((k,v))
    for k,v in pairs(b): yy.add((k,v))
    result = xx == yy

  var s = newStringStream()
  var a = initTable[string, Choco]()
  var b = newTable[string, Choco]()
  var c = initOrderedTable[string, Choco]()
  var d = newOrderedTable[string, Choco]()
  var e = newStringTable(modeCaseSensitive)
  var f: CritBitTree[Choco]

  var x = Choco(a:1,b:2)
  var y = Choco(a:3,b:4)
  a["a"] = x
  a["b"] = y
  b["a"] = x
  b["b"] = y
  c["a"] = x
  c["b"] = y
  d["a"] = x
  d["b"] = y
  e["a"] = "aa"
  e["b"] = "bb"
  f["a"] = x
  f["b"] = y

  s.pack(a)
  s.pack(b)
  s.pack(c)
  s.pack(d)
  s.pack(e)
  s.pack(f)

  s.setPosition(0)
  var aa: Table[string, Choco]
  var bb: TableRef[string, Choco]
  var cc: OrderedTable[string, Choco]
  var dd: OrderedTableRef[string, Choco]
  var ee: StringTableRef
  var ff: CritBitTree[Choco]

  s.unpack(aa)
  s.unpack(bb)
  s.unpack(cc)
  s.unpack(dd)
  s.unpack(ee)
  s.unpack(ff)

  doAssert aa == a
  doAssert bb == b
  doAssert cc == c
  doAssert dd == d
  doAssert ee.equal e
  doAssert ff.equal f

  echo "map"

proc testArray() =
  var s = newStringStream()
  var a = [0, 1, 2, 3]
  var b = ["a", "abc", "def"]
  var c = @[0, 1, 2, 3]
  var d = @["a", "abc", "def"]

  s.pack(a)
  s.pack(b)
  s.pack(c)
  s.pack(d)

  var aa: array[0..3, int]
  var bb: array[0..2, string]
  var cc: seq[int]
  var dd: seq[string]

  s.setPosition(0)
  s.unpack(aa)
  s.unpack(bb)
  s.unpack(cc)
  s.unpack(dd)

  doAssert aa == a
  doAssert bb == b
  doAssert cc == c
  doAssert dd == d
  echo "array"

proc testTuple() =
  type
    ttt = tuple[a:string,b:int,c:int,d:float]
    www = object
      abc: int
      def: string
      ghi: float

  var s = newStringStream()
  var a: ttt = ("hello", -1, 1, 1.0)
  var b = www(abc:1, def: "hello", ghi: 1.0)

  s.pack(a)
  s.pack(b)

  s.setPosition(0)
  var aa: ttt
  var bb: www

  s.unpack(aa)
  s.unpack(bb)

  doAssert aa == a
  doAssert bb == b

  echo "tuple"

proc otherTest() =
  var a = @[1,2,3,4,5,6,7,8,9,0]
  var buf = pack(a)
  var aa: seq[int]
  unpack(buf, aa)
  doAssert a == aa

  type
    functype = object
      fn: proc(x:int)

    Horse = object
      legs: int
      speed: int
      color: string
      name: string

  var b : functype
  var msg = pack(b)
  echo msg.stringify

  var cc = Horse(legs:4, speed:150, color:"black", name:"stallion")
  var zz = pack(cc)
  echo stringify(zz)

proc refTest() =
  var refint: ref int
  new(refint)
  refint[] = 45

  var s = newStringStream()
  s.pack(refint)

  var buf = pack(refint)
  echo stringify(buf)

  type
    Ghost = ref object
      body: ref float
      legs: ref int
      hair: ref int64

  var g: Ghost
  new(g)
  new(g.body)
  new(g.legs)
  new(g.hair)

  buf = pack(g)
  echo buf.stringify()

  var h: Ghost
  unpack(buf, h)
  echo "ghost: ", $h.body[]

  #type
  #  Ghostly = object
  #    legs: void
  #    body: void
  #
  #var j: Ghostly
  #pack(j)

  var rr: ptr Chocolate
  var tt: cstring

  discard pack(rr)
  discard pack(tt)

proc testInheritance() =
  type
    KAB = object of RootObj
      aaa: int
      bbb: int

    KCD = object of KAB
      ccc: int
      ddd: int

    KEF = object of KCD
      eee: int
      fff: int

  var kk = KEF()
  echo stringify(pack(kk))

type
  ship = distinct string
  boat = distinct int

  carrier = object
    one: array[0..5, ship]
    two: seq[boat]
    three: SinglyLinkedList[ship]
    four: DoublyLinkedList[boat]
    five: SinglyLinkedRing[ship]
    six: DoublyLinkedRing[boat]
    seven: Queue[ship]
    eight: HashSet[boat]
    nine: OrderedSet[ship]
    ten: Table[ship, boat]
    eleven: TableRef[ship, boat]
    twelve: OrderedTable[boat, ship]
    thirteen: OrderedTableRef[boat, ship]
    fourteen: CritBitTree[ship]

proc hash(c: ship): Hash =
  var h: Hash = 0
  h = h !& hash(string(c))
  result = !$ h

proc hash(c: boat): Hash =
  var h: Hash = 0
  h = h !& int(c)
  result = !$ h
  
proc `==`(a,b: ship): bool = string(a) == string(b)
proc `==`(a,b: boat): bool = int(a) == int(b)

proc initCarrier(): carrier =
  for i in 0..5: result.one[i] = ship($i)
  result.two = @[boat(1), boat(2), boat(3)]
  result.three = initSinglyLinkedList[ship]()
  result.three.prepend(ship("three"))
  result.four = initDoublyLinkedList[boat]()
  result.four.prepend(boat(44))
  result.five = initSinglyLinkedRing[ship]()
  result.five.prepend(ship("five"))
  result.six = initDoublyLinkedRing[boat]()
  result.six.prepend(boat(66))
  result.seven = initQueue[ship]()
  result.seven.add(ship("seven"))
  result.eight = initSet[boat]()
  result.eight.incl(boat(88))
  result.nine = initOrderedSet[ship]()
  result.nine.incl(ship("nine"))
  result.ten = initTable[ship, boat]()
  result.ten[ship("ten")] = boat(10)
  result.eleven = newTable[ship, boat]()
  result.eleven[ship("eleven")] = boat(11)
  result.twelve = initOrderedTable[boat, ship]()
  result.twelve[boat(12)] = ship("twelve")
  result.thirteen = newOrderedTable[boat, ship]()
  result.thirteen[boat(13)] = ship("thirteen")
  result.fourteen["fourteen"] = ship("fourteen")
    
proc testDistinct() =
  var airship: ship = ship("plane")
  var buf  = pack(airship)
  echo stringify buf
  unpack(buf, airship)

  var cc = initCarrier()
  buf = pack(cc)
  echo stringify buf
  var dd: carrier
  unpack(buf, dd)

proc testObjectVariant() =
  type
    NodeKind = enum # the different node types
      nkInt, #a leaf with an integer value
      nkFloat, #a leaf with a float value
      nkString, #a leaf with a string value
      nkAdd, #an addition
      nkSub, #a subtraction
      nkIf #an if statement
    
    Node = ref NodeObj
    
    NodeObj = object
      case kind: NodeKind # the kind field is the discriminator
      of nkInt: intVal: int
      of nkFloat: floatVal: float
      of nkString: strVal: string
      of nkAdd, nkSub:
        leftOp, rightOp: Node
      of nkIf:
        condition, thenPart, elsePart: Node
  
  var aUnion = Node(kind:nkInt, intVal:22)
  var s = pack(aUnion)
  echo s.stringify
  
  var b: Node
  unpack(s, b)
  doAssert b.kind == aUnion.kind
  doAssert b.intVal == aUnion.intVal

proc testComposite() =
  type
    myObj = object
      a: int
      b: float
      c: string
      
    myComposite = object
      o: myObj
      p: int
    
  var x, y: myComposite
  x.p = 11
  x.o.a = 1
  x.o.b = 123.123
  x.o.c = "hello"
  var s = x.pack
  echo s.stringify
  s.unpack(y)
  doAssert y == x

proc testRange() =
  var x, y: range[0..10]
  x = 5
  var s = x.pack
  echo "RANGE: ", s.stringify
  s.unpack y
  doAssert y == x
  
proc testAny() =
  # [1, "hello", {"a": "b"}]
  var s = newStringStream()
  s.pack_array(3)
  s.pack(1)
  s.pack("hello")
  var tmpMap = newStringTable(modeCaseSensitive)
  tmpMap["a"] = "b"
  s.pack(tmpMap)
  s.setPosition(0)
  var a = s.toAny()
  doAssert a.msgType == msgArray
  doAssert a.arrayVal[0].msgType == msgInt
  doAssert a.arrayVal[0].intVal == 1
  doAssert a.arrayVal[1].msgType == msgString
  doAssert a.arrayVal[1].stringVal == "hello"
  doAssert a.arrayVal[2].msgType == msgMap
  doAssert a.arrayVal[2].mapVal[0].key.msgType == msgString
  doAssert a.arrayVal[2].mapVal[0].key.stringVal == "a"
  doAssert a.arrayVal[2].mapVal[0].val.msgType == msgString
  doAssert a.arrayVal[2].mapVal[0].val.stringVal == "b"
  echo "any"
  
proc test() =
  testOrdinal()
  testOrdinal2()
  testOrdinal3()
  testOrdinal4()
  testString()
  testReal()
  testSet()
  testContainer()
  testMap()
  testArray()
  testTuple()
  otherTest()
  refTest()
  testInheritance()
  testDistinct()
  testObjectVariant()
  testComposite()
  testRange()
  testAny()
  
  echo "OK"

test()