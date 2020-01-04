import unittest, ../msgpack4nim, strutils, ../msgpack4nim/msgpack2json, json, os

suite "json-msgpack conversion":

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

  proc cmp(a: JsonNode, b: string): bool =
    let msg = fromJsonNode(a)
    result = msg == toBinary(b)
    if not result: echo toHex(msg)

  test "bool & nil":
    check cmp(newJBool(false), "c2")
    check cmp(newJBool(true), "c3")
    check cmp(newJNull(), "c0")

  test "positive int":
    check cmp(newJInt(0), "00")
    check cmp(newJInt(128), "cc80")
    check cmp(newJInt(256), "cd0100")
    check cmp(newJInt(65536), "ce00010000")
    check cmp(newJInt(127), "7f")
    check cmp(newJInt(255), "ccff")
    check cmp(newJInt(256), "cd0100")
    check cmp(newJInt(65535), "cdffff")
    when defined(cpu64):
      check cmp(newJInt(BiggestInT(high(uint32)) + 1), "CF0000000100000000")

  test "negative int":
    check cmp(newJInt(-1), "FF")
    check cmp(newJInt(-32), "e0")
    check cmp(newJInt(-128), "d080")
    check cmp(newJInt(-32768), "d18000")
    check cmp(newJInt(-65536), "d2FFFF0000")
    when defined(cpu64):
      check cmp(newJInt(BiggestInt(low(int32))-1), "D3FFFFFFFF7FFFFFFF")

  test "float":
    check cmp(newJFloat(0.0'f64), "cb0000000000000000")

    let
      f_neg_one_64 = -1.0'f64
      f_zero_64 = 0.0'f64

    check cmp(newJFloat(f_neg_one_64*f_zero_64), "cb8000000000000000")

    check cmp(newJFloat(1.0'f64), "cb3ff0000000000000")
    check cmp(newJFloat(-1.0'f64), "cbbff0000000000000")

  test "string":
    check cmp(newJString("OK"), "a24f4b")

  test "basic":
    let appDir = getAppDir()
    let n = json.parseFile(appDir & DirSep & "basic.json")
    let msg = fromJsonNode(n)
    let mp = readFile(appDir & DirSep & "basic.mp")
    check mp == msg

    var jn = toJsonNode(msg)
    check n == jn

  test "ordinal 8 bit":
    var s = MsgStream.init()
    for i in low(char)..high(char): s.pack(i)
    for i in low(int8)..high(int8): s.pack(i)
    for i in low(uint8)..high(uint8): s.pack(i)

    s.setPosition(0)
    for i in low(char)..high(char):
      let x = s.toJsonNode()
      check x.getInt() == i.int

    for i in low(int8)..high(int8):
      let x = s.toJsonNode()
      check x.getInt() == i.int

    for i in low(uint8)..high(uint8):
      let x = s.toJsonNode()
      check x.getInt() == i.int

  test "ordinal 16 bit":
    block one:
      var s = MsgStream.init()
      for i in low(int16)..high(int16): s.pack(i)
      s.setPosition(0)
      for i in low(int16)..high(int16):
        let x = s.toJsonNode()
        check x.getInt() == i.int

    block two:
      var s = MsgStream.init()
      for i in low(uint16)..high(uint16): s.pack(i)
      s.setPosition(0)
      for i in low(uint16)..high(uint16):
        let x = s.toJsonNode()
        check x.getInt() == i.int

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
      let x = s.toJsonNode()
      check x.getInt() == i.int

    for i in vv:
      let x = s.toJsonNode()
      when not defined(cpu64):
        if x.num > high(int32).BiggestInt or x.num < low(int32).BiggestInt: continue
      check x.getInt() == i.int

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
      let x = s.toJsonNode()
      when not defined(cpu64):
        if x.num > high(int32).BiggestInt or x.num < low(int32).BiggestInt: continue
      check x.getInt() == i.int

  test "string":
    var vv = ["hello",
      repeat('a', 200),
      repeat('b', 3000),
      repeat('c', 70000)]

    var s = MsgStream.init()
    for i in vv: s.pack(i)

    s.setPosition(0)
    for i in vv:
      let x = s.toJsonNode()
      check x.getStr() == i

  test "float number":
    let xx = [-1.0'f32, -2.0, 0.0, Inf, NegInf, 1.0, 2.0]
    let vv = [-1.0'f64, -2.0, 0.0, Inf, NegInf, 1.0, 2.0]

    var s = MsgStream.init()
    for i in xx: s.pack(i)
    for i in vv: s.pack(i)

    s.setPosition(0)
    for i in xx:
      let x = s.toJsonNode()
      check x.getFloat() == i.float

    for i in vv:
      let x = s.toJsonNode()
      check x.getFloat() == i.float
