import unittest, ../msgpack4nim, strutils, math, random

proc parseDigit*(x: char): uint8 =
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

proc toHex*(s: string): string =
  result = newStringOfCap(s.len * 2)
  for c in s:
    result.add toHex(c.ord)

proc cmp(a, b: string): bool =
  result = a == toBinary(b)
  if not result: echo toHex(a)

suite "msgpack specification test":

  test "bool & nil":
    check cmp(pack(false), "c2")
    check cmp(pack(true), "c3")
    when compiles(isNil(string(nil))):
      check cmp(pack(string(nil)), "c0")

  test "positive int":
    check cmp(pack(0), "00")
    check cmp(pack(128), "cc80")
    check cmp(pack(256), "cd0100")
    check cmp(pack(65536), "ce00010000")
    check cmp(pack(127), "7f")
    check cmp(pack(255), "ccff")
    check cmp(pack(256), "cd0100")
    check cmp(pack(65535), "cdffff")
    check cmp(pack(uint64(high(uint32)) + 1), "CF0000000100000000")

  test "negative int":
    check cmp(pack(-1), "FF")
    check cmp(pack(-32), "e0")
    check cmp(pack(-128), "d080")
    check cmp(pack(-32768), "d18000")
    check cmp(pack(-65536), "d2FFFF0000")
    check cmp(pack(int64(low(int32))-1), "D3FFFFFFFF7FFFFFFF")

  test "float":
    check cmp(pack(0.0'f32), "ca00000000")

    #trick the compiler to produce signed zero
    let
      f_neg_one_32 = -1.0'f32
      f_zero_32 = 0.0'f32

    check cmp(pack(f_neg_one_32*f_zero_32), "ca80000000")

    check cmp(pack(0.0'f64), "cb0000000000000000")

    let
      f_neg_one_64 = -1.0'f64
      f_zero_64 = 0.0'f64

    check cmp(pack(f_neg_one_64*f_zero_64), "cb8000000000000000")

    check cmp(pack(1.0'f64), "cb3ff0000000000000")
    check cmp(pack(-1.0'f64), "cbbff0000000000000")

  proc cmp_len[T](x: T, len: int, b: string): bool =
    var s = MsgStream.init()
    s.x(len)
    result = s.data == toBinary(b)
    if not result: echo toHex(s.data)

  proc cmp_str_len(len: int, b: string): bool =
    result = cmp_len(pack_string[MsgStream], len, b)

  proc cmp_bin_len(len: int, b: string): bool =
    result = cmp_len(pack_bin[MsgStream], len, b)

  proc cmp_arr_len(len: int, b: string): bool =
    result = cmp_len(pack_array[MsgStream], len, b)

  proc cmp_map_len(len: int, b: string): bool =
    result = cmp_len(pack_map[MsgStream], len, b)

  proc cmp_ext(len: int, b: string): bool =
    var s = MsgStream.init()
    s.pack_ext(len, 1'i8)
    result = s.data == toBinary(b)
    if not result: echo toHex(s.data)

  test "string len":
    check cmp_str_len(0, "a0")
    check cmp_str_len(1, "a1")
    check cmp_str_len(31, "bf")
    check cmp_str_len(32, "d920")
    check cmp_str_len(128, "d980")
    check cmp_str_len(256, "da0100")
    check cmp_str_len(65536, "db00010000")

  test "bin len":
    check cmp_bin_len(0, "c400")
    check cmp_bin_len(1, "c401")
    check cmp_bin_len(128, "c480")
    check cmp_bin_len(256, "c50100")
    check cmp_bin_len(65536, "c600010000")

  test "array len":
    check cmp_arr_len(0, "90")
    check cmp_arr_len(1, "91")
    check cmp_arr_len(15, "9F")
    check cmp_arr_len(16, "DC0010")
    check cmp_arr_len(128, "dc0080")
    check cmp_arr_len(256, "dc0100")
    check cmp_arr_len(65536, "dd00010000")

  test "map len":
    check cmp_map_len(0, "80")
    check cmp_map_len(1, "81")
    check cmp_map_len(15, "8F")
    check cmp_map_len(16, "de0010")
    check cmp_map_len(128, "de0080")
    check cmp_map_len(256, "de0100")
    check cmp_map_len(65536, "df00010000")

  test "ext len":
    check cmp_ext(1, "d401")
    check cmp_ext(2, "d501")
    check cmp_ext(4, "d601")
    check cmp_ext(8, "d701")
    check cmp_ext(16, "d801")
    check cmp_ext(3, "c70301")
    check cmp_ext(128, "c78001")
    check cmp_ext(256, "c8010001")
    check cmp_ext(65536, "c90001000001")

  when defined(cpu64):
    const coverage = [2^5, -2^5, 2^11, -2^11, 2^21, -2^21, 2^51, -2^51, 2^61, -2^61]
  else:
    const coverage = [2^5, -2^5, 2^11, -2^11, 2^21, -2^21]

  test "coverage":
    var m: int64
    for c in coverage:
      let s = pack(c)
      s.unpack(m)
      check m == c

  proc nb_codec[T](n: T): tuple[data: T, len: int] =
    var output: T
    var s = pack(n)
    s.unpack(output)
    result = (data: output, len:s.len)

  template nb_test[T](n: T, sz: int) =
    let o = nb_codec(n)
    check o.data == n
    check o.len == sz

  template nb_test[T](n: T, sz: int, epsilon: float) =
    let o = nb_codec(n)
    let diff = abs(o.data - n)
    check diff <= epsilon
    check o.len == sz

  test "spec len":
    for n in 0..127:
      nb_test(n, 1)

    for n in 128..255:
      nb_test(n, 2)

    for n in 256..2^16-1:
      nb_test(n, 3)

    for n in 2^16..2^16+100:
      nb_test(n, 5)

    when defined(cpu64):
      for n in 2^32-101..2^32-1:
        nb_test(n, 5)

      for n in 2^32..2^32+100:
        nb_test(n, 9)

    for n in countdown(-1,-32):
      nb_test(n, 1)

    for n in countdown(-33,-128):
      nb_test(n, 2)

    for n in countdown(-129,-2^15):
      nb_test(n, 3)

    for n in countdown(-2^15-1,-2^15-101):
      nb_test(n, 5)

    when defined(cpu64):
      for n in countdown(-2^31+100,-2^31):
        nb_test(n, 5)

      for n in countdown(-2^31-1,-2^31-101):
        nb_test(n, 9)

    randomize()
    for i in 1..100:
      let n = rand(200.0)-100.0
      nb_test(n, 9)

    for i in 1..100:
      let n = float32(rand(200.0)-100.0)
      nb_test(n, 5, 1e-5)
