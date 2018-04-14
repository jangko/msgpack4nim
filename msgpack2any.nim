import msgpack4nim, streams, tables, math, hashes

type
  AnyType* = enum
    msgMap, msgArray, msgString, msgBool,
    msgBin, msgExt, msgFloat32, msgFloat64,
    msgInt, msgUint, msgNull

  MsgAny* = ref MsgAnyObj
  MsgAnyObj* {.acyclic.} = object
    case kind*: AnyType
    of msgMap: mapVal*: OrderedTable[MsgAny, MsgAny]
    of msgArray: arrayVal*: seq[MsgAny]
    of msgString: stringVal*: string
    of msgBool: boolVal*: bool
    of msgBin:
      binLen*: int
      binData*: string
    of msgExt:
      extLen*, extType*: int
      extData*: string
    of msgFloat32: float32Val*: float32
    of msgFloat64: float64Val*: float64
    of msgInt: intVal*: int64
    of msgUint: uintVal*: uint64
    of msgNull: nil

proc newMsgAny*(kind: AnyType): MsgAny =
  new(result)
  result.kind = kind

proc hash*(n: OrderedTable[MsgAny, MsgAny]): Hash {.noSideEffect.}

proc hash*(n: MsgAny): Hash =
  case n.kind
  of msgArray:
    result = hash(n.arrayVal)
  of msgMap:
    result = hash(n.mapVal)
  of msgString:
    result = hash(n.stringVal)
  of msgBool:
    result = hash(n.boolVal)
  of msgBin:
    result = hash(n.binLen)
    result = result !& hash(n.binData)
    result = !$result
  of msgExt:
    result = hash(n.extLen)
    result = result !& hash(n.extType)
    result = result !& hash(n.extData)
    result = !$result
  of msgFloat32:
    result = hash(n.float32Val)
  of msgFloat64:
    result = hash(n.float64Val)
  of msgInt:
    result = hash(n.intVal)
  of msgUint:
    result = hash(n.uintVal)
  of msgNull:
    result = hash(0)

proc hash*(n: OrderedTable[MsgAny, MsgAny]): Hash =
  for key, val in n:
    result = result xor (hash(key) !& hash(val))
  result = !$result

proc `==`* (a, b: MsgAny): bool =
  if a.isNil:
    if b.isNil: return true
    return false
  elif b.isNil or a.kind != b.kind:
    return false
  else:
    case a.kind
    of msgNull:
      result = true
    of msgUint:
      result = a.uintVal == b.uintVal
    of msgInt:
      result = a.intVal == b.intVal
    of msgFloat64:
      result = a.float64Val == b.float64Val
    of msgFloat32:
      result = a.float32Val == b.float32Val
    of msgExt:
      result = a.extData == b.extData and a.extType == b.extType and a.extLen == b.extLen
    of msgBin:
      result = a.binData == b.binData and a.binLen == b.binLen
    of msgBool:
      result = a.boolVal == b.boolVal
    of msgString:
      result = a.stringVal == b.stringVal
    of msgArray:
      result = a.arrayVal == b.arrayVal
    of msgMap:
     # we cannot use OrderedTable's equality here as
     # the order does not matter for equality here.
     if a.mapVal.len != b.mapVal.len: return false
     for key, val in a.mapVal:
       if not b.mapVal.hasKey(key): return false
       if b.mapVal[key] != val: return false
     result = true

proc anyMap*(len: int = 4): MsgAny =
  result = newMsgAny(msgMap)
  result.mapVal = initOrderedTable[MsgAny, MsgAny](nextPowerOfTwo(len))

proc anyArray*(len: int = 0): MsgAny =
  result = newMsgAny(msgArray)
  result.arrayVal = newSeqOfCap[MsgAny](len)

proc anyArray*(args: openArray[MsgAny]): MsgAny =
  result = anyArray(args.len)
  for c in args: result.arrayVal.add c

proc anyArray*(args: varargs[MsgAny]): MsgAny =
  result = anyArray(args.len)
  for c in args: result.arrayVal.add c

proc anyBin*(val: string): MsgAny =
  result = newMsgAny(msgBin)
  result.binData = val
  result.binLen = val.len

proc anyExt*(val: string, typ: int8): MsgAny =
  result = newMsgAny(msgExt)
  result.extData = val
  result.extLen = val.len
  result.extType = typ.int

proc anyString*(val: string): MsgAny =
  result = newMsgAny(msgString)
  result.stringVal = val

proc anyBool*(val: bool): MsgAny =
  result = newMsgAny(msgBool)
  result.boolVal = val

proc anyFloat*(val: float32): MsgAny =
  result = newMsgAny(msgFloat32)
  result.float32Val = val

proc anyFloat*(val: float64): MsgAny =
  result = newMsgAny(msgFloat64)
  result.float64Val = val

proc anyInt*(val: int64): MsgAny =
  result = newMsgAny(msgInt)
  result.intVal = val

proc anyUint*(val: uint64): MsgAny =
  result = newMsgAny(msgUint)
  result.uintVal = val

proc anyNull*(): MsgAny =
  newMsgAny(msgNull)

iterator items*(n: MsgAny): MsgAny =
  assert n.kind == msgArray
  for i in items(n.arrayVal):
    yield i

iterator mitems*(n: var MsgAny): var MsgAny =
  assert n.kind == msgArray
  for i in mitems(n.arrayVal):
    yield i

iterator pairs*(n: MsgAny): tuple[key, val: MsgAny] =
  assert n.kind == msgMap
  for key, val in pairs(n.mapVal):
    yield (key, val)

iterator mpairs*(n: var MsgAny): tuple[key: MsgAny, val: var MsgAny] =
  assert n.kind == msgMap
  for key, val in mpairs(n.mapVal):
    yield (key, val)

proc len*(n: MsgAny): int =
  case n.kind
  of msgArray: result = n.arrayVal.len
  of msgMap: result = n.mapVal.len
  else: discard

proc add*(n, elem: MsgAny) =
  assert n.kind == msgArray
  n.arrayVal.add elem

proc add*(n, key, val: MsgAny) =
  assert n.kind == msgMap
  n.mapVal[key] = val

proc `[]`*(node: MsgAny, name: MsgAny): MsgAny {.inline.} =
  assert(not isNil(node))
  assert(node.kind == msgMap)
  #if not node.mapVal.hasKey(name): return nil
  result = node.mapVal[name]

proc `[]`*(node: MsgAny, index: int): MsgAny {.inline.} =
  assert(not isNil(node))
  assert(node.kind == msgArray)
  return node.arrayVal[index]

proc hasKey*(node: MsgAny, key: MsgAny): bool =
  assert(node.kind == msgMap)
  result = node.mapVal.hasKey(key)

proc contains*(node: MsgAny, val: MsgAny): bool =
  assert(node.kind in {msgMap, msgArray})
  if node.kind == msgMap:
    result = node.mapVal.hasKey(val)
  else:
    result = find(node.arrayVal, val) >= 0

proc `[]=`*(obj: MsgAny, key: MsgAny, val: MsgAny) {.inline.} =
  assert(obj.kind == msgMap)
  obj.mapVal[key] = val

proc getOrDefault*(node: MsgAny, key: MsgAny): MsgAny =
  if not isNil(node) and node.kind == msgMap:
    result = node.mapVal.getOrDefault(key)

proc delete*(obj: MsgAny, key: MsgAny) =
  assert(obj.kind == msgMap)
  if not obj.mapVal.hasKey(key):
    raise newException(IndexError, "key not in object")
  obj.mapVal.del(key)

proc copy*(n: MsgAny): MsgAny =
  case n.kind
  of msgNull:
    result = anyNull()
  of msgUint:
    result = anyUint(n.uintVal)
  of msgInt:
    result = anyInt(n.intVal)
  of msgFloat64:
    result = anyFloat(n.float64Val)
  of msgFloat32:
    result = anyFloat(n.float32Val)
  of msgExt:
    result = anyExt(n.extData, n.extType.int8)
  of msgBin:
    result = anyBin(n.binData)
  of msgBool:
    result = anyBool(n.boolVal)
  of msgString:
    result = anyString(n.stringVal)
  of msgArray:
    result = anyArray(n.arrayVal.len)
    for c in n:
      result.add copy(c)
  of msgMap:
    result = anyMap(n.mapVal.len)
    for k, v in n:
      result[k.copy] = v.copy

proc toAny*(s: Stream): MsgAny =
  let pos = s.getPosition()
  let c = ord(s.readChar)
  case c
  of 0x00..0x7f:
    result = newMsgAny(msgInt)
    result.intVal = c
  of 0x80..0x8f, 0xde..0xdf:
    s.setPosition(pos)
    let len = s.unpack_map()
    result = newMsgAny(msgMap)
    result.mapVal = initOrderedTable[MsgAny, MsgAny](nextPowerOfTwo(len))
    for i in 0..<len:
      result.mapVal[toAny(s)] = toAny(s)
  of 0x90..0x9f, 0xdc..0xdd:
    s.setPosition(pos)
    let len = s.unpack_array()
    result = newMsgAny(msgArray)
    result.arrayVal = newSeq[MsgAny](len)
    for i in 0..<len:
      result.arrayVal[i] = toAny(s)
  of 0xa0..0xbf, 0xd9..0xdb:
    s.setPosition(pos)
    let len = s.unpack_string()
    result = newMsgAny(msgString)
    result.stringVal = s.readStr(len)
  of 0xc0:
    result = newMsgAny(msgNull)
  of 0xc1:
    raise conversionError("toAny unused")
  of 0xc2:
    result = newMsgAny(msgBool)
    result.boolVal = false
  of 0xc3:
    result = newMsgAny(msgBool)
    result.boolVal = true
  of 0xc4..0xc6:
    s.setPosition(pos)
    result = newMsgAny(msgBin)
    result.binLen = s.unpack_bin()
    result.binData = s.readStr(result.binLen)
  of 0xc7..0xc9, 0xd4..0xd8:
    s.setPosition(pos)
    let (exttype, extlen) = s.unpack_ext()
    result = newMsgAny(msgExt)
    result.extLen = extlen
    result.extType = exttype.int
    result.binData = s.readStr(extlen)
  of 0xca:
    s.setPosition(pos)
    result = newMsgAny(msgFloat32)
    result.float32Val = s.unpack_imp_float32()
  of 0xcb:
    s.setPosition(pos)
    result = newMsgAny(msgFloat64)
    result.float64Val = s.unpack_imp_float64()
  of 0xcc..0xcf:
    s.setPosition(pos)
    result = newMsgAny(msgUint)
    result.uintVal = s.unpack_imp_uint64()
  of 0xd0..0xd3:
    s.setPosition(pos)
    result = newMsgAny(msgInt)
    result.intVal = s.unpack_imp_int64()
  of 0xe0..0xff:
    result = newMsgAny(msgInt)
    result.intVal = cast[int8](c).int64
  else:
    raise conversionError("unknown command")

proc toAny*(data: string): MsgAny =
  var s = newStringStream(data)
  result = s.toAny()

proc fromAny*(s: Stream, n: MsgAny) =
  case n.kind
  of msgNull:
    s.write(pack_value_nil)
  of msgUint:
    s.pack_type(n.uintVal)
  of msgInt:
    s.pack_type(n.intVal)
  of msgFloat64:
    s.pack_type(n.float64Val)
  of msgFloat32:
    s.pack_type(n.float32Val)
  of msgExt:
    s.pack_ext(n.extLen, n.extType.int8)
    s.write(n.extData)
  of msgBin:
    s.pack_bin(n.binLen)
    s.write(n.binData)
  of msgBool:
    s.pack_type(n.boolVal)
  of msgString:
    s.pack_type(n.stringVal)
  of msgArray:
    s.pack_array(n.len())
    for c in n:
      fromAny(s, c)
  of msgMap:
    s.pack_map(n.len())
    for k, v in n:
      fromAny(s, k)
      fromAny(s, v)

proc fromAny*(n: MsgAny): string =
  var s = newStringStream()
  fromAny(s, n)
  result = s.data

proc `$`*(n: MsgAny): string =
  stringify(fromAny(n))
