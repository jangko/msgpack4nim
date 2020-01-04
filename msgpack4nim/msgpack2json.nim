import ../msgpack4nim, json, tables, math, base64

proc toJsonNode*[ByteStream](s: ByteStream): JsonNode =
  let c = ord(s.peekChar)
  case c
  of 0x00..0x7f:
    result = newJInt(BiggestInt(c))
    discard s.readChar()
  of 0x80..0x8f, 0xde..0xdf:
    let len = s.unpack_map()
    result = JsonNode(kind: JObject)
    result.fields = initOrderedTable[string, JsonNode](nextPowerOfTwo(len))
    for i in 0..<len:
      let key = toJsonNode(s)
      if key.kind != JString: raise conversionError("json key needs a string")
      result.fields.add(key.getStr(), toJsonNode(s))
  of 0x90..0x9f, 0xdc..0xdd:
    let len = s.unpack_array()
    result = JsonNode(kind: JArray)
    result.elems = newSeq[JsonNode](len)
    for i in 0..<len:
      result.elems[i] = toJsonNode(s)
  of 0xa0..0xbf, 0xd9..0xdb:
    let len = s.unpack_string()
    result = newJString(s.readStr(len))
  of 0xc0:
    result = newJNull()
    discard s.readChar()
  of 0xc1:
    discard s.readChar()
    raise conversionError("toJsonNode unused")
  of 0xc2:
    result = newJBool(false)
    discard s.readChar()
  of 0xc3:
    result = newJBool(true)
    discard s.readChar()
  of 0xc4..0xc6:
    result = newJObject()
    let binLen = s.unpack_bin()
    let data = base64.encode(s.readStr(binLen))
    result.add("type", newJString("bin"))
    result.add("len", newJInt(binLen.BiggestInt))
    result.add("data", newJString(data))
  of 0xc7..0xc9, 0xd4..0xd8:
    let (exttype, extlen) = s.unpack_ext()
    let data = base64.encode(s.readStr(extlen))
    result = newJObject()
    result.add("type", newJString("ext"))
    result.add("len", newJInt(extLen.BiggestInt))
    result.add("exttype", newJInt(exttype.BiggestInt))
    result.add("data", newJString(data))
  of 0xca:
    result = newJFloat(s.unpack_imp_float32().float)
  of 0xcb:
    result = newJFloat(s.unpack_imp_float64().float)
  of 0xcc..0xcf:
    result = newJInt(s.unpack_imp_uint64().BiggestInt)
  of 0xd0..0xd3:
    result = newJInt(s.unpack_imp_int64().BiggestInt)
  of 0xe0..0xff:
    result = newJInt(cast[int8](c).BiggestInt)
    discard s.readChar()
  else:
    raise conversionError("unknown command")

proc toJsonNode*(data: string): JsonNode =
  var s = MsgStream.init(data)
  result = s.toJsonNode()

proc fromJsonNode*[ByteStream](s: ByteStream, n: JsonNode) =
  case n.kind
  of JNull:
    s.write(pack_value_nil)
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
  var s = MsgStream.init()
  fromJsonNode(s, n)
  result = s.data
