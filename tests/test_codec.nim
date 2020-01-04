import streams, endians, strutils, sequtils, algorithm, math, hashes
import tables, intsets, lists, deques, sets, strtabs, critbits
import ../msgpack4nim, unittest, ../msgpack4nim/msgpack4collection

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
    seven: Deque[ship]
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

proc `$`(a: ship): string =
  result = $string(a)

proc `$`(a: boat): string =
  result = $int(a)

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
  result.seven = initDeque[ship]()
  result.seven.addLast(ship("seven"))
  result.eight = initHashSet[boat]()
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

type
  Guid = distinct string
  UUID = distinct seq[string]

  PRESTO = seq[string]

proc pack_type[ByteStream](s: ByteStream, v: Guid) =
  s.pack_bin(len(v.string))
  s.write(v.string)

proc unpack_type[ByteStream](s: ByteStream, v: var Guid) =
  let L = s.unpack_bin()
  v = Guid(s.readStr(L))

suite "msgpack encoder-decoder":
  test "ordinal 8 bit":
    var
      s = MsgStream.init()
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
    check aa == a
    check bb == b

    var cc: char
    var dd: int8
    var ee: uint8
    for i in low(char)..high(char):
      s.unpack(cc)
      check cc == i

    for i in low(int8)..high(int8):
      s.unpack(dd)
      check dd == i

    for i in low(uint8)..high(uint8):
      s.unpack(ee)
      check ee == i

  test "ordinal 16 bit":
    block one:
      var s = MsgStream.init()
      for i in low(int16)..high(int16): s.pack(i)
      s.setPosition(0)
      var x: int16
      for i in low(int16)..high(int16):
        s.unpack(x)
        check x == i

    block two:
      var s = MsgStream.init()
      for i in low(uint16)..high(uint16): s.pack(i)
      s.setPosition(0)
      var x: uint16
      for i in low(uint16)..high(uint16):
        s.unpack(x)
        check x == i

  test "ordinal 32 bit":
    let uu = [low(int32), low(int32)+1, low(int32)+2, high(int32)-1,
      high(int32)-2, int32(low(int8))-2, int32(low(int8))-1, low(int8), low(int8)+1,
      low(int8)+2, int32(low(int16))-2, int32(low(int16))-1, low(int16), low(int16)+1,
      low(int16)+2, high(int8)-2, high(int8)-1, high(int8), int32(high(int8))+1,
      int32(high(int8))+2, high(int16)-2, high(int16)-1, high(int16), int32(high(int16))+1,
      int32(high(int16))+2,high(int32)]

    block one:
      var s = MsgStream.init()
      var x: int32
      for i in uu: s.pack(i)

      s.setPosition(0)
      for i in uu:
        s.unpack(x)
        check x == i

    let vv = [low(uint32), low(uint32)+1, low(uint32)+2, high(uint32), high(uint32)-1,
      high(uint32)-2, low(uint8), low(uint8)+1, low(uint8)+2, low(uint16)+1,
      low(uint16)+2, high(uint8)-2, high(uint8)-1, high(uint8), high(uint8)+1,
      high(uint8)+2, high(uint16)-2, high(uint16)-1, high(uint16), high(uint16)+1,
      high(uint16)+2]

    block two:
      var s = MsgStream.init()
      var x: uint32

      for i in vv: s.pack(i)

      s.setPosition(0)
      for i in vv:
        s.unpack(x)
        check x == i

  test "ordinal 64 bit":
    let uu = [high(int64), low(int32), low(int32)+1, low(int32)+2, high(int32)-1,
      high(int32)-2, int64(low(int8))-2, int64(low(int8))-1, low(int8), low(int8)+1,
      low(int8)+2, int64(low(int16))-2, int64(low(int16))-1, low(int16), low(int16)+1,
      low(int16)+2, high(int8)-2, high(int8)-1, high(int8), int64(high(int8))+1,
      int64(high(int8))+2, high(int16)-2, high(int16)-1, high(int16), int64(high(int16))+1,
      int64(high(int16))+2,high(int32), low(int64)+1, low(int64)+2, low(int64),
      high(int64)-1, high(int64)-2, low(int64),low(int64)+1,low(int64)+2,
      int64(low(int32))-1,int64(low(int32))-2]

    block one:
      var s = MsgStream.init()
      var x: int64

      for i in uu: s.pack(i)

      s.setPosition(0)
      for i in uu:
        s.unpack(x)
        check x == i

    let vv = [0xFFFFFFFFFFFFFFFFFFFFFF'u64, low(uint32), low(uint32)+1, low(uint32)+2, high(uint32), high(uint32)-1,
      high(uint32)-2, low(uint8), low(uint8)+1, low(uint8)+2, low(uint16)+1,
      low(uint16)+2, high(uint8)-2, high(uint8)-1, high(uint8), high(uint8)+1,
      high(uint8)+2, high(uint16)-2, high(uint16)-1, high(uint16), high(uint16)+1,
      high(uint16)+2, 0xFFFFFFFFFFFFFFFFFFFFFF'u64-1, 0xFFFFFFFFFFFFFFFFFFFFFF'u64-2]

    block two:
      var s = MsgStream.init()
      var x: uint64

      for i in vv: s.pack(i)

      s.setPosition(0)
      for i in vv:
        s.unpack(x)
        check x == i

  test "string":
    var d = "hello"
    var e = repeat('a', 200)
    var f = repeat('b', 3000)
    var g = repeat('c', 70000)
    var h = ""
    var s = MsgStream.init()

    var dd,ee,ff,gg,hh: string
    s.pack(d)
    s.pack(e)
    s.pack(f)
    s.pack(g)
    s.pack(h)

    s.setPosition(0)
    s.unpack(dd)
    check dd == d
    s.unpack(ee)
    s.unpack(ff)
    s.unpack(gg)
    s.unpack(hh)
    check ee == e
    check ff == f
    check gg == g
    check hh == h

  test "float number":
    var xx = [-1.0'f32, -2.0, 0.0, Inf, NegInf, 1.0, 2.0]

    block one:
      var s = MsgStream.init()
      var x: float32
      for i in xx: s.pack(i)

      s.setPosition(0)
      for i in xx:
        s.unpack(x)
        check x == i

    var vv = [-1.0'f64, -2.0, 0.0, Inf, NegInf, 1.0, 2.0]

    block two:
      var s = MsgStream.init()
      var x: float64
      for i in vv: s.pack(i)

      s.setPosition(0)
      for i in vv:
        s.unpack(x)
        check x == i

  test "set":
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

    var s = MsgStream.init()
    s.pack(x)
    s.pack(y)
    s.pack(a)
    s.pack(b)

    s.setPosition(0)
    s.unpack(xx)
    s.unpack(yy)
    check x == xx
    check y == yy
    s.unpack(aa)
    s.unpack(bb)
    check a == aa
    check b == bb

  test "container":
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

    proc `==`(a,b: Deque[Choco]): bool =
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
    var f = initDeque[Choco]()
    var g = initHashSet[Choco]()
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
    f.addLast(x)
    f.addLast(y)
    g.incl(x)
    g.incl(y)
    h.incl(x)
    h.incl(y)
    k.incl("hello")
    k.incl("world")

    var s = MsgStream.init()
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
    var ff: Deque[Choco]
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

    check aa == a
    check bb == b
    check cc == c
    check dd == d
    check ee == e
    check ff == f
    check gg == g
    check hh == h
    check kk == k

  test "map":
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

    var s = MsgStream.init()
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

    check aa == a
    check bb == b
    check cc == c
    check dd == d
    check ee.equal e
    check ff.equal f

  test "array":
    var s = MsgStream.init()
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

    check aa == a
    check bb == b
    check cc == c
    check dd == d

  test "tuple":
    type
      ttt = tuple[a:string,b:int,c:int,d:float]
      www = object
        abc: int
        def: string
        ghi: float

    var s = MsgStream.init()
    var a: ttt = ("hello", -1, 1, 1.0)
    var b = www(abc:1, def: "hello", ghi: 1.0)

    s.pack(a)
    s.pack(b)

    s.setPosition(0)
    var aa: ttt
    var bb: www

    s.unpack(aa)
    s.unpack(bb)

    check aa == a
    check bb == b

  test "other":
    #var a = @[1,2,3,4,5,6,7,8,9,0]
    #var buf = pack(a)
    #var aa: seq[int]
    #unpack(buf, aa)
    #check a == aa

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
    check msg.stringify == "[ null ] "

    var cc = Horse(legs:4, speed:150, color:"black", name:"stallion")
    var zz = pack(cc)
    check stringify(zz) == "[ 4, 150, \"black\", \"stallion\" ] "

  test "ref type":
    var refint: ref int
    new(refint)
    refint[] = 45

    var s = MsgStream.init()
    s.pack(refint)

    var buf = pack(refint)
    check stringify(buf) == "45 "

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
    check buf.stringify() == "[ 0.0, 0, 0 ] "

    var h: Ghost
    unpack(buf, h)
    check $h.body[] == "0.0"

    var rr: ptr Chocolate
    var tt: cstring

    discard pack(rr)
    discard pack(tt)

  test "inheritance":
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
    check stringify(pack(kk)) == "[ 0, 0, 0, 0, 0, 0 ] "

  test "distinct":
    var airship: ship = ship("plane")
    var buf  = pack(airship)
    check stringify(buf) == "\"plane\" "
    unpack(buf, airship)

    var cc = initCarrier()
    buf = pack(cc)

    var dd: carrier
    unpack(buf, dd)

    check cc.one == dd.one
    check cc.two == dd.two
    check $cc.three == $dd.three
    check $cc.four == $dd.four
    check $cc.five == $dd.five
    check $cc.six == $dd.six
    check $cc.seven == $dd.seven
    check cc.eight == dd.eight
    check cc.nine == dd.nine
    check cc.ten == dd.ten
    check cc.eleven == dd.eleven
    check cc.twelve == dd.twelve
    check cc.thirteen == dd.thirteen
    check $cc.fourteen == $dd.fourteen

  test "object variant":
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
    check s.stringify == "[ 0, 22 ] "

    var b: Node
    unpack(s, b)
    check b.kind == aUnion.kind
    check b.intVal == aUnion.intVal

  test "composite":
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
    s.unpack(y)
    check y == x

  test "range":
    var x, y: range[0..10]
    x = 5
    var s = x.pack
    s.unpack y
    check y == x

  type
    GUN = enum
      PISTOL
      RIFLE
      MUSKET
      SMG
      SHOTGUN

    MilMan = object
      weapon: GUN

  test "weapon":
    var a, b: MilMan
    a.weapon = SMG

    var buf = pack(a)
    buf.unpack(b)
    check(a.weapon == b.weapon)

  test "bin/ext":
    const exttype0 = 0

    var s = MsgStream.init()
    var body = "this is the body"

    s.pack_ext(body.len, exttype0)
    s.write(body)

    #the same goes to bin format
    s.pack_bin(body.len)
    s.write(body)

    s.setPosition(0)
    #unpack_ext return tuple[exttype:uint8, len: int]
    let (extype, extlen) = s.unpack_ext()
    var extbody = s.readStr(extlen)

    check extbody == body
    check extype == exttype0

    let binlen = s.unpack_bin()
    var binbody = s.readStr(binlen)

    check binbody == body

  proc pack_unpack_test[T](val: T) =
    var vPack = val.pack()
    var vUnpack: T
    vpack.unpack(vUnpack)
    assert val == vUnpack

  type
    abc = object
      a: int
      b: int

  test "bug":
    # bug 13
    var x = abc(a: -557853050, b : 0)
    pack_unpack_test(x)
    pack_unpack_test((-557853050, 0))
    pack_unpack_test((0, -557853050, 0))

    when defined(cpu64):
      var y = abc(a: int(-5578530500), b : 0)
      pack_unpack_test(y)
      pack_unpack_test((-5578530500, 0))
      pack_unpack_test((0, -5578530500, 0))
      pack_unpack_test((0, -5578530500, 0, 0))

    # bug 14
    type
      NilString = object
        a: int
        b: string
        c: seq[int]

    when compiles(isNil(string(nil))):
      let ns = NilString(a: 10, b: nil, c: nil)
    else:
      let ns = NilString(a: 10, b: "", c: @[])
    var os: NilString
    var buf = ns.pack()
    buf.unpack(os)
    check ns == os

  test "runtime encoding mode":
    type
      Fruit = object
        color: int
        name: string
        taste: string

    var x = Fruit(color: 15, name: "apple", taste: "sweet")
    var y: Fruit

    block encoding_mode_default:
      var s = MsgStream.init()
      s.pack(x)
      s.setPosition(0)
      s.unpack(y)
      check x == y

    block encoding_mode_array:
      var s = MsgStream.init(0, MSGPACK_OBJ_TO_ARRAY)
      s.pack(x)
      s.setPosition(0)
      s.unpack(y)
      check x == y

    block encoding_mode_map:
      var s = MsgStream.init(0, MSGPACK_OBJ_TO_MAP)
      s.pack(x)
      s.setPosition(0)
      s.unpack(y)
      check x == y

    block encoding_mode_stream:
      var s = MsgStream.init(0, MSGPACK_OBJ_TO_STREAM)
      s.pack(x)
      s.setPosition(0)
      s.unpack(y)
      check x == y

    block encoding_mode_default_default:
      var s = MsgStream.init(0, MSGPACK_OBJ_TO_DEFAULT)
      s.pack(x)
      s.setPosition(0)
      s.unpack(y)
      check x == y

    block nim_standard_stream:
      var s = newStringStream()
      s.pack(x)
      s.setPosition(0)
      s.unpack(y)
      check x == y

  test "skip undistinct":
    var b: Guid = Guid("AA")

    var s = b.pack
    check s.tohex == "C4024141"
    check s.stringify == "BIN: 4141 "

    var bb: Guid
    s.unpack(bb)
    check bb.string == b.string

    var y = PRESTO(@["AA"])
    var yy = y.pack
    check yy.toHex == "91A24141"
    check yy.stringify == "[ \"AA\" ] "

    var z = UUID(@["AA"])
    when compiles(var str = z.pack):
      discard z # silence unused warning
      check false
    else:
      discard z # silence unused warning
      check true
