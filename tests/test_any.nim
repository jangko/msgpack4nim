import unittest, strutils, strtabs
import ../msgpack4nim/[msgpack4collection, msgpack2any]
import ../msgpack4nim

suite "dynamic json-like conversion":

  test "any":
    # [1, "hello", {"a": "b"}]
    var s = MsgStream.init()
    s.pack_array(3)
    s.pack(1)
    s.pack("hello")
    var tmpMap = newStringTable(modeCaseSensitive)
    tmpMap["a"] = "b"
    s.pack(tmpMap)

    var a = toAny(s.data)
    check a.kind == msgArray
    check a.arrayVal[0].kind == msgInt
    check a.arrayVal[0].intVal == 1
    check a.arrayVal[1].kind == msgString
    check a.arrayVal[1].stringVal == "hello"
    check a.arrayVal[2].kind == msgMap
    var c = a[2]
    check c[anyString("a")] == anyString("b")

  proc parseDigit(x: char): uint8 =
    if x in Digits: result = uint8(x.ord - '0'.ord)
    elif x in {'A'..'F'}: result = uint8(x.ord - 'A'.ord + 0x0A)
    elif x in {'a'..'f'}: result = uint8(x.ord - 'a'.ord + 0x0A)
    else: result = 0

  proc toBinary(s: string): string =
    assert((s.len mod 2) == 0)
    assert(s.len != 0)
    result = newStringOfCap(s.len div 2)
    var i = 0
    while i < s.len:
      let c = (parseDigit(s[i]) shl 4) or parseDigit(s[i+1])
      result.add chr(c)
      inc(i, 2)

  proc toHex(s: string): string =
    result = newStringOfCap(s.len * 2)
    for c in s:
      result.add toHex(c.ord)

  proc cmp(a: MsgAny, b: string): bool =
    let msg = fromAny(a)
    result = msg == toBinary(b)
    if not result: echo toHex(msg)

  test "bool & nil":
    check cmp(anyBool(false), "c2")
    check cmp(anyBool(true), "c3")
    check cmp(anyNull(), "c0")

  test "positive int":
    check cmp(anyUInt(0), "00")
    check cmp(anyUInt(128), "cc80")
    check cmp(anyUInt(256), "cd0100")
    check cmp(anyUInt(65536), "ce00010000")
    check cmp(anyUInt(127), "7f")
    check cmp(anyUInt(255), "ccff")
    check cmp(anyUInt(256), "cd0100")
    check cmp(anyUInt(65535), "cdffff")
    check cmp(anyUInt(uint64(high(uint32)) + 1), "CF0000000100000000")

  test "negative int":
    check cmp(anyInt(-1), "FF")
    check cmp(anyInt(-32), "e0")
    check cmp(anyInt(-128), "d080")
    check cmp(anyInt(-32768), "d18000")
    check cmp(anyInt(-65536), "d2FFFF0000")
    check cmp(anyInt(int64(low(int32))-1), "D3FFFFFFFF7FFFFFFF")

  test "float":
    check cmp(anyFloat(0.0'f64), "cb0000000000000000")

    let
      f_neg_one_64 = -1.0'f64
      f_zero_64 = 0.0'f64

    check cmp(anyFloat(f_neg_one_64*f_zero_64), "cb8000000000000000")

    check cmp(anyFloat(1.0'f64), "cb3ff0000000000000")
    check cmp(anyFloat(-1.0'f64), "cbbff0000000000000")

  test "string":
    check cmp(anyString("OK"), "a24f4b")

  test "ordinal 8 bit":
    var s = MsgStream.init()
    for i in low(char)..high(char): s.pack(i)
    for i in low(int8)..high(int8): s.pack(i)
    for i in low(uint8)..high(uint8): s.pack(i)

    s.setPosition(0)
    for i in low(char)..high(char):
      let x = s.toAny()
      if x.kind == msgInt:
        check x.intVal == i.int64
      else:
        check x.uintVal == i.uint64

    for i in low(int8)..high(int8):
      let x = s.toAny()
      if x.kind == msgInt:
        check x.intVal == i.int64
      else:
        check x.uintVal == i.uint64

    for i in low(uint8)..high(uint8):
      let x = s.toAny()
      if x.kind == msgInt:
        check x.intVal == i.int64
      else:
        check x.uintVal == i.uint64

  test "ordinal 16 bit":
    block one:
      var s = MsgStream.init()
      for i in low(int16)..high(int16): s.pack(i)
      s.setPosition(0)
      for i in low(int16)..high(int16):
        let x = s.toAny()
        if x.kind == msgInt:
          check x.intVal == i.int64
        else:
          check x.uintVal == i.uint64

    block two:
      var s = MsgStream.init()
      for i in low(uint16)..high(uint16): s.pack(i)
      s.setPosition(0)
      for i in low(uint16)..high(uint16):
        let x = s.toAny()
        if x.kind == msgInt:
          check x.intVal == i.int64
        else:
          check x.uintVal == i.uint64

  test "ordinal 32 bit":
    let uu = [low(int32), low(int32)+1, low(int32)+2, high(int32)-1,
      high(int32)-2, int32(low(int8))-2, int32(low(int8))-1, low(int8), low(int8)+1,
      low(int8)+2, int32(low(int16))-2, int32(low(int16))-1, low(int16), low(int16)+1,
      low(int16)+2, high(int8)-2, high(int8)-1, high(int8), int32(high(int8))+1,
      int32(high(int8))+2, high(int16)-2, high(int16)-1, high(int16), int32(high(int16))+1,
      int32(high(int16))+2,high(int32)]

    let vv = [low(uint32), low(uint32)+1, low(uint32)+2, high(uint32), high(uint32)-1,
      high(uint32)-2, low(uint8), low(uint8)+1, low(uint8)+2, low(uint16)+1,
      low(uint16)+2, high(uint8)-2, high(uint8)-1, high(uint8), high(uint8)+1,
      high(uint8)+2, high(uint16)-2, high(uint16)-1, high(uint16), high(uint16)+1,
      high(uint16)+2]

    var s = MsgStream.init()

    for i in uu: s.pack(i)
    for i in vv: s.pack(i)

    s.setPosition(0)

    for i in uu:
      let x = s.toAny()
      if x.kind == msgInt:
        check x.intVal == i.int64
      else:
        check x.uintVal == i.uint64

    for i in vv:
      let x = s.toAny()
      if x.kind == msgInt:
        check x.intVal == i.int64
      else:
        check x.uintVal == i.uint64

  test "ordinal 64 bit":
    let uu = [high(int64), low(int32), low(int32)+1, low(int32)+2, high(int32)-1,
      high(int32)-2, int64(low(int8))-2, int64(low(int8))-1, low(int8), low(int8)+1,
      low(int8)+2, int64(low(int16))-2, int64(low(int16))-1, low(int16), low(int16)+1,
      low(int16)+2, high(int8)-2, high(int8)-1, high(int8), int64(high(int8))+1,
      int64(high(int8))+2, high(int16)-2, high(int16)-1, high(int16), int64(high(int16))+1,
      int64(high(int16))+2,high(int32), low(int64)+1, low(int64)+2, low(int64),
      high(int64)-1, high(int64)-2, low(int64),low(int64)+1,low(int64)+2,
      int64(low(int32))-1,int64(low(int32))-2]

    var s = MsgStream.init()
    for i in uu: s.pack(i)
    s.setPosition(0)

    for i in uu:
      let x = s.toAny()
      if x.kind == msgInt:
        check x.intVal == i.int64
      else:
        check x.uintVal == i.uint64

  test "string":
    var vv = ["hello",
      repeat('a', 200),
      repeat('b', 3000),
      repeat('c', 70000)]

    var s = MsgStream.init()

    for i in vv: s.pack(i)

    s.setPosition(0)
    for i in vv:
      let x = s.toAny()
      check x.stringVal == i

  test "float number":
    let xx = [-1.0'f32, -2.0, 0.0, Inf, NegInf, 1.0, 2.0]
    let vv = [-1.0'f64, -2.0, 0.0, Inf, NegInf, 1.0, 2.0]

    var s = MsgStream.init()
    for i in xx: s.pack(i)
    for i in vv: s.pack(i)

    s.setPosition(0)
    for i in xx:
      let x = s.toAny()
      check x.float32Val == i.float32

    for i in vv:
      let x = s.toAny()
      check x.float64Val == i.float64

  test "map copy and `in` operator":
    var a = anyMap()
    a[anyString("abc")] = anyInt(123)
    var b = a.copy
    a[anyString("abc")] = anyString("hello")
    check a[anyString("abc")] == anyString("hello")
    check b[anyString("abc")] == anyInt(123)

    # `in` operator
    check anyString("abc") in a
    check anyString("abc") in b
    var c = anyArray(anyString("apple"))
    check anyString("apple") in c

  test "bin and ext":
    const extType = 0xCE'i8
    var bin = anyBin("binary data")
    var ext = anyExt("ext oi...", extType)
    var arr = anyArray(bin, ext)
    var msg = arr.fromAny()

    var a_arr = toAny(msg)
    check a_arr[0].kind == msgBin
    check a_arr[1].kind == msgExt
    check a_arr[0].binData == "binary data"
    check a_arr[1].extType == extType
    check a_arr[1].extData == "ext oi..."

  test "map with non-string field":
    type
      Fruit = object
        name: string
        color: int

    var a = anyMap()
    a[anyInt(123)] = anyString("non-string-field")
    a["name"] = anyString("apple")
    a["color"] = anyInt(1001)
    a["someInt"] = anyInt(123)

    var s = MsgStream.init(fromAny(a), MSGPACK_OBJ_TO_MAP)
    var x = s.unpack(Fruit)
    check x.name == "apple"
    check x.color == 1001

    when defined(msgpack_obj_to_map):
      var y = unpack(fromAny(a), Fruit)
      check y.name == "apple"
      check y.color == 1001

    var b = anyMap()
    b[anyInt(123)] = anyString("non-string-field")
    b["someInt"] = anyInt(123)
    b["name"] = anyString("apple")
    b["color"] = anyInt(1001)

    var s2 = MsgStream.init(fromAny(b), MSGPACK_OBJ_TO_MAP)
    var x2 = s2.unpack(Fruit)
    check x2.name == "apple"
    check x2.color == 1001

    when defined(msgpack_obj_to_map):
      var y2 = unpack(fromAny(b), Fruit)
      check y2.name == "apple"
      check y2.color == 1001
