import streams, unsigned, endians, strutils, sequtils, algorithm, math, hashes
import tables, intsets, lists, queues, sets, strtabs, critbits
import msgpack

type
  Choco = object
    a: int
    b: int
  
  Chocolate = object
    a: Choco
    b: int

proc hash*(c: Choco): THash =
  var h: THash = 0
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
  assert aa == a
  assert bb == b
  
  var cc: char
  var dd: int8
  var ee: uint8
  for i in low(char)..high(char):
    s.unpack(cc)
    assert cc == i
  echo "char"
  
  for i in low(int8)..high(int8):
    s.unpack(dd)
    assert dd == i
  echo "int8"
  
  for i in low(uint8)..high(uint8):
    s.unpack(ee)
    assert ee == i
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
          echo "miss: ", $x, " vs ", $i
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
          echo "miss: ", $x, " vs ", $i
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
          echo "miss: ", $x, " vs ", $i
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
          echo "miss: ", $x, " vs ", $i
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
          echo "miss: ", $x, " vs ", $i
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
          echo "miss: ", $x, " vs ", $i
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
  assert dd == d
  s.unpack(ee)
  s.unpack(ff)
  s.unpack(gg)
  assert ee == e
  assert ff == f
  assert gg == g
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
  var z,zz:set[side]
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
  
  var s = newStringStream()
  s.pack(x)
  s.pack(y)
  s.pack(a)
  s.pack(b)
  
  s.setPosition(0)
  s.unpack(xx)
  s.unpack(yy)
  assert x == xx
  assert y == yy
  s.unpack(aa)
  s.unpack(bb)
  assert a == aa
  assert b == bb
  
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
  
  var s = newStringStream()
  s.pack(a)
  s.pack(b)
  s.pack(c)
  s.pack(d)
  s.pack(e)
  s.pack(f)
  s.pack(g)
  s.pack(h)
  
  s.setPosition(0)
  var aa: IntSet
  var bb: SinglyLinkedList[Choco]
  var cc: DoublyLinkedList[Choco]
  var dd: SinglyLinkedRing[Choco]
  var ee: DoublyLinkedRing[Choco]
  var ff: Queue[Choco]
  var gg: HashSet[Choco]
  var hh: OrderedSet[Choco]
  
  s.unpack(aa)
  s.unpack(bb)
  s.unpack(cc)
  s.unpack(dd)
  s.unpack(ee)
  s.unpack(ff)
  s.unpack(gg)
  s.unpack(hh)
  
  assert aa == a
  assert bb == b
  assert cc == c
  assert dd == d
  assert ee == e
  assert ff == f
  assert gg == g
  assert hh == h
  
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
  
  assert aa == a
  assert bb == b
  assert cc == c
  assert dd == d
  assert ee.equal e
  assert ff.equal f
  
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
  
  assert aa == a
  assert bb == b
  assert cc == c
  assert dd == d
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
  
  assert aa == a
  assert bb == b
  
  echo "tuple"

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
  
  var a = @[1,2,3,4,5,6,7,8,9,0]
  var buf = pack(a)
  var aa: seq[int]
  unpack(buf, aa)
  assert a == aa
  
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
  
  var cc = Horse(legs:4, speed:150, color:"black", name:"stallion")
  var zz = pack(cc)
  echo stringify(zz)
    
  echo "OK"
  
test()