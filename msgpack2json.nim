import msgpack4nim, json, streams, tables, math, base64

proc toJsonNode*(s: Stream): JsonNode =
  let pos = s.getPosition()
  let c = ord(s.readChar)
  case c
  of 0x00..0x7f:
    result = newJInt(BiggestInt(c))
  of 0x80..0x8f, 0xde..0xdf:
    s.setPosition(pos)
    let len = s.unpack_map()
    new(result)
    result.kind = JObject
    result.fields = initOrderedTable[string, JsonNode](nextPowerOfTwo(len))
    for i in 0..<len:
      let key = toJsonNode(s)
      if key.kind != JString: raise conversionError("json key needs a string")
      result.fields.add(key.getStr(), toJsonNode(s))
  of 0x90..0x9f, 0xdc..0xdd:
    s.setPosition(pos)
    let len = s.unpack_array()
    new(result)
    result.kind = JArray
    result.elems = newSeq[JsonNode](len)
    for i in 0..<len:
      result.elems[i] = toJsonNode(s)
  of 0xa0..0xbf, 0xd9..0xdb:
    s.setPosition(pos)
    let len = s.unpack_string()
    result = newJString(s.readStr(len))
  of 0xc0:
    result = newJNull()
  of 0xc1:
    raise conversionError("toJsonNode unused")
  of 0xc2:
    result = newJBool(false)
  of 0xc3:
    result = newJBool(true)
  of 0xc4..0xc6:
    s.setPosition(pos)
    result = newJObject()
    let binLen = s.unpack_bin()
    let data = base64.encode(s.readStr(binLen))
    result.add("type", newJString("bin"))
    result.add("len", newJInt(binLen.BiggestInt))
    result.add("data", newJString(data))
  of 0xc7..0xc9, 0xd4..0xd8:
    s.setPosition(pos)
    let (exttype, extlen) = s.unpack_ext()
    let data = base64.encode(s.readStr(extlen))
    result = newJObject()
    result.add("type", newJString("ext"))
    result.add("len", newJInt(extLen.BiggestInt))
    result.add("exttype", newJInt(exttype.BiggestInt))
    result.add("data", newJString(data))
  of 0xca:
    s.setPosition(pos)
    result = newJFloat(s.unpack_imp_float32().float)
  of 0xcb:
    s.setPosition(pos)
    result = newJFloat(s.unpack_imp_float64().float)
  of 0xcc..0xcf:
    s.setPosition(pos)
    result = newJInt(s.unpack_imp_uint64().BiggestInt)
  of 0xd0..0xd3:
    s.setPosition(pos)
    result = newJInt(s.unpack_imp_int64().BiggestInt)
  of 0xe0..0xff:
    result = newJInt(cast[int8](c).BiggestInt)
  else:
    raise conversionError("unknown command")

proc toJsonNode*(data: string): JsonNode =
  var s = newStringStream(data)
  result = s.toJsonNode()

proc fromJsonNode*(s: Stream, n: JsonNode) =
  case n.kind
  of JNull:
    s.write(chr(0xc0))
  of JBool:
    s.pack_type(n.getBool())
  of JInt:
    s.pack_type(n.getInt())
  of JFloat:
    s.pack_type(n.getFloat())
  of JString:
    s.pack_type(n.getStr())
  of JObject:
    s.pack_map(n.len())
    for k, v in n:
      s.pack_type(k)
      fromJsonNode(s, v)
  of JArray:
    s.pack_array(n.len())
    for c in n:
      fromJsonNode(s, c)

proc fromJsonNode*(n: JsonNode): string =
  var s = newStringStream()
  fromJsonNode(s, n)
  result = s.data
