import unittest, ../msgpack4nim, strutils, os, json, ../msgpack4nim/msgpack2any

const
  msgpack = "msgpack"
  bignum = "bignum"

proc readHexChar(c: char): byte {.noSideEffect, inline.}=
  ## Converts an hex char to a byte
  case c
  of '0'..'9': result = byte(ord(c) - ord('0'))
  of 'a'..'f': result = byte(ord(c) - ord('a') + 10)
  of 'A'..'F': result = byte(ord(c) - ord('A') + 10)
  else:
    doAssert(false, $c & " is not a hexademical character")

func hexToString(hexStr: string): string =
  doAssert((hexStr.len and 1) == 0, "must have even length")
  let N = hexStr.len div 2

  result = newString(N)
  for i in 0 ..< N:
    result[i] = char(hexStr[2*i].readHexChar shl 4 or hexStr[2*i + 1].readHexChar)

proc parseHexDash(n: JsonNode): string =
  doAssert(n.kind == JString)
  result = hexToString(replace(n.getStr, "-", ""))

proc testNil(v, m: JsonNode): bool =
  doAssert(v.kind == JNull)
  result = true
  for x in m:
    let y = parseHexDash(x)
    result = result and (stringify(y).strip == $v)

proc testBool(v, m: JsonNode): bool =
  doAssert(v.kind == JBool)
  result = true
  for x in m:
    let y = parseHexDash(x)
    result = result and (stringify(y).strip == $v)

proc parseBin(data: string): string =
  var s = MsgStream.init(data)
  let len = s.unpack_bin()
  result = s.readStr(len)

proc testBinary(v, m: JsonNode): bool =
  doAssert(v.kind == JString)
  result = true
  let vv = parseHexDash(v)
  for x in m:
    let y = parseHexDash(x)
    result = result and (parseBin(y) == vv)

proc testNumber(v: string, m: JsonNode): bool =
  result = true
  for x in m:
    let y = parseHexDash(x)
    let yy = stringify(y).strip
    result = result and (yy.replace(".0", "") == v)

proc testString(v: string, m: JsonNode): bool =
  result = true
  for x in m:
    let y = parseHexDash(x)
    let yy = stringify(y).strip
    result = result and (yy.replace("\"", "") == v)

proc compare(v: JsonNode, z: MsgAny): bool =
  case v.kind
  of JNull: result = z.kind == msgNull
  of JBool:
    result = z.kind == msgBool and z.boolVal == v.getBool
  of JInt:
    case z.kind
    of msgUint:
      result = z.uintVal == v.getInt.uint64
    of msgInt:
      result = z.intVal == v.getInt.int64
    else:
      result = false
  of JFloat:
    case z.kind
    of msgFloat32:
      result = z.float32Val == v.getFloat
    of msgFloat64:
      result = z.float64Val == v.getFloat
    else:
      result = false
  of JString:
    result = z.kind == msgString and z.stringVal == v.getStr
  of JObject:
    result = z.kind == msgMap
    for key, val in v:
      result = result and compare(val, z[key])
  of JArray:
    result = z.kind == msgArray
    var i = 0
    for val in v:
      result = result and compare(val, z[i])
      inc i

proc testAny(v, m: JsonNode): bool =
  result = true
  for x in m:
    let y = parseHexDash(x)
    let z = toAny(y)
    result = compare(v, z)

proc parseExt(data: string): (int, string) =
  var s = MsgStream.init(data)
  let (typ, len) = s.unpack_ext()
  result = (typ.int, s.readStr(len))

proc testExt(v, m: JsonNode): bool =
  doAssert(v.kind == JArray)
  result = true

  let ext = (v[0].getInt, v[1].parseHexDash)
  for x in m:
    let y = parseHexDash(x)
    let xx = parseExt(y)
    result = xx == ext

proc toIntTS(x: openArray[char]): int64 =
  for c in x:
    result = (result shl 8) or c.int

proc parseTimestamp(x: string): (int64, int64) =
  case x.len
  of 4: result = (toIntTS(x.toOpenArray(0, 3)), 0'i64)
  of 8:
    let xx = toIntTS(x.toOpenArray(0, 7))
    result = (xx and 0x3ffffffff'i64, (cast[uint64](xx) shr 34).int64)
  of 12:
    let ns = toIntTS(x.toOpenArray(0, 3))
    let sec = toIntTS(x.toOpenArray(4, 11))
    result = (sec, ns)
  else:
    doAssert(false, "invalid timestamp")

proc testTimestamp(v, m: JsonNode): bool =
  doAssert(v.kind == JArray)
  result = true

  let sec_ns = (v[0].getStr, v[1].getStr)

  for x in m:
    let y = parseHexDash(x)
    let (typ, con) = parseExt(y)
    let res = parseTimestamp(con)
    result = (typ == -1) and (sec_ns == ($res[0], $res[1]))

proc testElem(n: JsonNode): bool =
  doAssert(n.kind == JObject)
  let m = n[msgpack]
  var numProcessed = false
  for k, v in n:
    case k
    of "nil": result = testNil(v, m)
    of "bool": result = testBool(v, m)
    of "binary": result = testBinary(v, m)
    of "number":
      numProcessed = true
      if n.hasKey(bignum):
        result = testNumber(n[bignum].getStr, m)
      else:
        result = testNumber($v, m)
    of msgpack: discard
    of bignum:
      if not numProcessed:
        result = testNumber(n[bignum].getStr, m)
    of "string": result = testString(v.getStr, m)
    of "ext": result = testExt(v, m)
    of "array", "map": result = testAny(v, m)
    of "timestamp": result = testTimestamp(v, m)
    else:
      debugEcho "unrecognized elem type: ", k
      result = false

proc tester(n: JsonNode): bool =
  doAssert(n.kind == JArray)
  result = true
  for x in n:
    result = result and testElem(x)

proc main() =
  suite "kawanet msgpack test suite":
    const dataFile = "tests" / "msgpack-test-suite.json"
    let n = json.parseFile(dataFile)
    for k, v in n:
      test k:
        check tester(v)

main()
