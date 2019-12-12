import
  faststreams/[input_stream, output_stream],
  stew/endians2

const pack_value_nil* = byte(0xc0)

proc conversionError*(msg: string): ref ObjectConversionError =
  new(result)
  result.msg = msg

when system.cpuEndian == littleEndian:
  proc take8_8(val: uint8): byte {.inline.}   = byte(val)
  proc take8_16(val: uint16): byte {.inline.} = byte(val and 0xFF)
  proc take8_32(val: uint32): byte {.inline.} = byte(val and 0xFF)
  proc take8_64(val: uint64): byte {.inline.} = byte(val and 0xFF)
else:
  proc take8_8(val: uint8): byte {.inline.}   = byte(val)
  proc take8_16(val: uint16): byte {.inline.} = byte((val shr 8) and 0xFF)
  proc take8_32(val: uint32): byte {.inline.} = byte((val shr 24) and 0xFF)
  proc take8_64(val: uint64): byte {.inline.} = byte((val shr 56) and 0xFF)

proc take16_8[T:uint8|char|int8](val: T): uint16 {.inline.} = uint16(val)
proc take32_8[T:uint8|char|int8](val: T): uint32 {.inline.} = uint32(val)
proc take64_8[T:uint8|char|int8](val: T): uint64 {.inline.} = uint64(val)

proc store[T: uint16|uint32|uint64](s: OutputStreamVar, val: T) =
  s.append(toBytesBE(val))

proc unstore[T: uint16|uint32|uint64](s: ByteStreamVar): T =
  fromBytesBE(type(result), readBytes(s, sizeof(result)))

proc pack_bool*(s: OutputStreamVar, val: bool) =
  s.append(if val: byte(0xc3) else: byte(0xc2))

proc unpack_bool*(s: ByteStreamVar, val: var bool) =
  let c = s[].read
  if c == byte(0xc3): val = true
  elif c == byte(0xc2): val = false
  else: raise conversionError("bool")

proc pack_string*(s: OutputStreamVar, len: int) =
  if len < 32:
    var d = uint8(0xa0) or uint8(len)
    s.append(byte(d))
  elif len < 256:
    s.append(byte(0xd9))
    s.append(byte(len))
  elif len < 65536:
    s.append(byte(0xda))
    s.store(uint16(len))
  else:
    s.append(byte(0xdb))
    s.store(uint32(len))

proc pack_string*(s: OutputStreamVar, val: string) =
  s.pack_string(val.len)
  s.append(val)

proc unpack_string*(s: ByteStreamVar): int =
  result = -1
  let c = s[].read
  if c >= byte(0xa0) and c <= byte(0xbf): result = int(c) and 0x1f
  elif c == byte(0xd9):
    result = int(s[].read)
  elif c == byte(0xda):
    result = int(unstore[uint16](s))
  elif c == byte(0xdb):
    result = int(unstore[uint32](s))

proc copyString(val: var string, bytes: openArray[byte]) =
  copyMem(val[0].addr, bytes[0].unsafeAddr, bytes.len)

proc unpack_string*(s: ByteStreamVar, val: var string) =
  let len = s.unpack_string()
  val = newString(len)
  val.copyString(s.readBytes(len))

proc pack_imp_uint8*(s: OutputStreamVar, val: uint8) =
  if val < uint8(1 shl 7):
    #fixnum
    s.append(byte(val))
  else:
    #unsigned 8
    s.append(byte(0xcc))
    s.append(byte(val))

proc unpack_imp_uint8*(s: ByteStreamVar): uint8 =
  let c = s[].read
  if c < byte(128): result = take8_8(c)
  elif c == byte(0xcc):
    result = uint8(s[].read)
  else: raise conversionError("uint8")

proc pack_imp_uint16*(s: OutputStreamVar, val: uint16) =
  if val < uint16(1 shl 7):
    #fixnum
    s.append(take8_16(val))
  elif val < uint16(1 shl 8):
    #unsigned 8
    s.append(byte(0xcc))
    s.append(take8_16(val))
  else:
    #unsigned 16
    s.append(byte(0xcd))
    s.store(val)

proc unpack_imp_uint16*(s: ByteStreamVar): uint16 =
  let c = s[].read
  if c < byte(128): result = take16_8(c)
  elif c == byte(0xcc):
    result = take16_8(s[].read)
  elif c == byte(0xcd):
    result = unstore[uint16](s)
  else: raise conversionError("uint16")

proc pack_imp_uint32*(s: OutputStreamVar, val: uint32) =
  if val < uint32(1 shl 8):
    if val < uint32(1 shl 7):
      #fixnum
      s.append(take8_32(val))
    else:
      #unsigned 8
      s.append(byte(0xcc))
      s.append(take8_32(val))
  else:
    if val < uint32(1 shl 16):
      #unsigned 16
      s.append(byte(0xcd))
      s.store(uint16(val))
    else:
      #unsigned 32
      s.append(byte(0xce))
      s.store(val)

proc unpack_imp_uint32*(s: ByteStreamVar): uint32 =
  let c = s[].read
  if c < byte(128): result = take32_8(c)
  elif c == byte(0xcc):
    result = take32_8(s[].read)
  elif c == byte(0xcd):
    result = uint32(unstore[uint16](s))
  elif c == byte(0xce):
    result = unstore[uint32](s)
  else: raise conversionError("uint32")

proc pack_imp_uint64*(s: OutputStreamVar, val: uint64) =
  if val < uint64(1 shl 8):
    if val < uint64(1 shl 7):
      #fixnum
      s.append(take8_64(val))
    else:
      #unsigned 8
      s.append(byte(0xcc))
      s.append(take8_64(val))
  else:
    if val < uint64(1 shl 16):
      #unsigned 16
      s.append(byte(0xcd))
      s.store(uint16(val))
    elif val < uint64(1 shl 32):
      #unsigned 32
      s.append(byte(0xce))
      s.store(uint32(val))
    else:
      #unsigned 64
      s.append(byte(0xcf))
      s.store(val)

proc unpack_imp_uint64*(s: ByteStreamVar): uint64 =
  let c = s[].read
  if c < byte(128): result = take64_8(c)
  elif c == byte(0xcc):
    result = take64_8(s[].read)
  elif c == byte(0xcd):
    result = uint64(unstore[uint16](s))
  elif c == byte(0xce):
    result = uint64(unstore[uint32](s))
  elif c == byte(0xcf):
    result = unstore[uint64](s)
  else: raise conversionError("uint64")

proc pack_imp_int8*(s: OutputStreamVar, val: int8) =
  if val < -(1 shl 5):
    #signed 8
    s.append(byte(0xd0))
    s.append(take8_8(cast[uint8](val)))
  else:
    #fixnum
    s.append(take8_8(cast[uint8](val)))

proc unpack_imp_int8*(s: ByteStreamVar): int8 =
  let c = s[].read
  if c >= byte(0xe0) and c <= byte(0xff):
    result = cast[int8](c)
  elif c >= byte(0x00) and c <= byte(0x7f):
    result = cast[int8](c)
  elif c == byte(0xd0):
    result = cast[int8](s[].read)
  else: raise conversionError("int8")

proc pack_imp_int16*(s: OutputStreamVar, val: int16) =
  if val < -(1 shl 5):
    if val < -(1 shl 7):
      #signed 16
      s.append(byte(0xd1))
      s.store(cast[uint16](val))
    else:
      #signed 8
      s.append(byte(0xd0))
      var x = cast[char](take8_16(cast[uint16](val)))
      s.append(x)
  elif val < (1 shl 7):
    var x = cast[char](take8_16(cast[uint16](val)))
    #fixnum
    s.append(x)
  else:
    if val < (1 shl 8):
      #unsigned 8
      s.append(byte(0xcc))
      s.append(take8_16(uint16(val)))
    else:
      #unsigned 16
      s.append(byte(0xcd))
      s.store(uint16(val))

proc unpack_imp_int16*(s: ByteStreamVar): int16 =
  let c = s[].read
  if c >= byte(0xe0) and c <= byte(0xff):
    result = int16(cast[int8](c))
  elif c >= byte(0x00) and c <= byte(0x7f):
    result = int16(cast[int8](c))
  elif c == byte(0xd0):
    result = int16(cast[int8](s[].read))
  elif c == byte(0xd1):
    result = cast[int16](unstore[uint16](s))
  elif c == byte(0xcc):
    result = int16(s[].read)
  elif c == byte(0xcd):
    result = cast[int16](unstore[uint16](s))
  else: raise conversionError("int16")

proc pack_imp_int32*(s: OutputStreamVar, val: int32) =
  if val < -(1 shl 5):
    if val < -(1 shl 15):
      #signed 32
      s.append(byte(0xd2))
      s.store(cast[uint32](val))
    elif val < -(1 shl 7):
      #signed 16
      s.append(byte(0xd1))
      s.store(cast[uint16](val))
    else:
      #signed 8
      s.append(byte(0xd0))
      var x = cast[char](take8_32(cast[uint32](val)))
      s.append(x)
  elif val < (1 shl 7):
    #fixnum
    var x = cast[char](take8_32(cast[uint32](val)))
    s.append(x)
  else:
    if val < (1 shl 8):
      #unsigned 8
      s.append(byte(0xcc))
      s.append(take8_32(uint32(val)))
    elif val < (1 shl 16):
      #unsigned 16
      s.append(byte(0xcd))
      s.store(uint16(val))
    else:
      #unsigned 32
      s.append(byte(0xce))
      s.store(uint32(val))

proc unpack_imp_int32*(s: ByteStreamVar): int32 =
  let c = s[].read
  if c >= byte(0xe0) and c <= byte(0xff):
    result = int32(cast[int8](c))
  elif c >= byte(0x00) and c <= byte(0x7f):
    result = int32(cast[int8](c))
  elif c == byte(0xd0):
    result = int32(cast[int8](s[].read))
  elif c == byte(0xd1):
    result = int32(cast[int16](unstore[uint16](s)))
  elif c == byte(0xd2):
    result = cast[int32](unstore[uint32](s))
  elif c == byte(0xcc):
    result = int32(s[].read)
  elif c == byte(0xcd):
    result = int32(unstore[uint16](s))
  elif c == byte(0xce):
    result = cast[int32](unstore[uint32](s))
  else: raise conversionError("int32")

proc pack_imp_int64*(s: OutputStreamVar, val: int64) =
  if val < -(1 shl 5):
    if val < -(1 shl 31):
      #signed 64
      s.append(byte(0xd3))
      s.store(uint64(val))
    elif val < -(1 shl 15):
      #signed 32
      s.append(byte(0xd2))
      s.store(cast[uint32](val))
    elif val < -(1 shl 7):
      #signed 16
      s.append(byte(0xd1))
      s.store(cast[uint16](val))
    else:
      #signed 8
      s.append(byte(0xd0))
      var x = cast[char](take8_64(cast[uint64](val)))
      s.append(x)
  elif val < (1 shl 7):
    #fixnum
    var x = cast[char](take8_64(cast[uint64](val)))
    s.append(x)
  else:
    if val < (1 shl 8):
      #unsigned 8
      s.append(byte(0xcc))
      s.append(take8_64(uint64(val)))
    elif val < (1 shl 16):
      #unsigned 16
      s.append(byte(0xcd))
      s.store(uint16(val))
    elif val < (1 shl 32):
      #unsigned 32
      s.append(byte(0xce))
      s.store(uint32(val))
    else:
      #unsigned 64
      s.append(byte(0xcf))
      s.store(uint64(val))

proc unpack_imp_int64*(s: ByteStreamVar): int64 =
  let c = s[].read
  if c >= byte(0xe0) and c <= byte(0xff):
    result = int64(cast[int8](c))
  elif c >= byte(0x00) and c <= byte(0x7f):
    result = int64(cast[int8](c))
  elif c == byte(0xd0):
    result = int64(cast[int8](s[].read))
  elif c == byte(0xd1):
    result = int64(cast[int16](unstore[uint16](s)))
  elif c == byte(0xd2):
    result = int64(cast[int32](unstore[uint32](s)))
  elif c == byte(0xd3):
    result = cast[int64](unstore[uint64](s))
  elif c == byte(0xcc):
    result = int64(s[].read)
  elif c == byte(0xcd):
    result = int64(unstore[uint16](s))
  elif c == byte(0xce):
    result = int64(unstore[uint32](s))
  elif c == byte(0xcf):
    result = cast[int64](unstore[uint64](s))
  else: raise conversionError("int64")

proc pack_int_imp_select*[T](s: OutputStreamVar, val: T) =
  when sizeof(val) == 1:
    s.pack_imp_int8(int8(val))
  elif sizeof(val) == 2:
    s.pack_imp_int16(int16(val))
  elif sizeof(val) == 4:
    s.pack_imp_int32(int32(val))
  else:
    s.pack_imp_int64(int64(val))

proc pack_uint_imp_select*[T](s: OutputStreamVar, val: T) =
  if sizeof(T) == 1:
    s.pack_imp_uint8(cast[uint8](val))
  elif sizeof(T) == 2:
    s.pack_imp_uint16(cast[uint16](val))
  elif sizeof(T) == 4:
    s.pack_imp_uint32(cast[uint32](val))
  else:
    s.pack_imp_uint64(cast[uint64](val))

proc unpack_int_imp_select*[T](s: ByteStreamVar, val: var T) =
  when sizeof(T) == 1:
    val = T(s.unpack_imp_int8())
  elif sizeof(T) == 2:
    val = T(s.unpack_imp_int16())
  elif sizeof(T) == 4:
    val = T(s.unpack_imp_int32())
  else:
    val = int(s.unpack_imp_int64())

proc unpack_uint_imp_select*[T](s: ByteStreamVar, val: var T) =
  if sizeof(val) == 1:
    val = s.unpack_imp_uint8()
  elif sizeof(val) == 2:
    val = s.unpack_imp_uint16()
  elif sizeof(val) == 4:
    val = s.unpack_imp_uint32()
  else:
    val = uint(s.unpack_imp_uint64())

proc pack_enum*[T](s: OutputStreamVar, val: T) =
  pack_int_imp_select(s, val)

proc unpack_enum*[T](s: ByteStreamVar, val: var T) =
  unpack_int_imp_select(s, val)

proc pack_imp_float32*(s: OutputStreamVar, val: float32) {.inline.} =
  let tmp = cast[uint32](val)
  s.append(byte(0xca))
  s.store(tmp)

proc pack_imp_float64*(s: OutputStreamVar, val: float64) {.inline.} =
  let tmp = cast[uint64](val)
  s.append(byte(0xcb))
  s.store(tmp)

proc unpack_imp_float32*(s: ByteStreamVar): float32 {.inline.} =
  let c = s[].read
  if c == byte(0xca):
    result = cast[float32](unstore[uint32](s))
  else:
    raise conversionError("float32")

proc unpack_imp_float64*(s: ByteStreamVar): float64 {.inline.} =
  let c = s[].read
  if c == byte(0xcb):
    result = cast[float64](unstore[uint64](s))
  else:
    raise conversionError("float64")

proc pack_float*[T](s: OutputStreamVar, val: T) {.inline.} =
  when sizeof(val) == 4:
    pack_impl_float32(s, val)
  else:
    pack_impl_float64(s, val)

proc unpack_float*[T](s: ByteStreamVar, val: var T) {.inline.} =
  when sizeof(val) == 4:
    unpack_impl_float32(s, val)
  else:
    unpack_impl_float64(s, val)

proc pack_array*(s: OutputStreamVar, len: int) =
  if len <= 0x0F:
    s.append(byte(0b10010000 or (len and 0x0F)))
  elif len > 0x0F and len <= 0xFFFF:
    s.append(byte(0xdc))
    s.store(uint16(len))
  elif len > 0xFFFF:
    s.append(byte(0xdd))
    s.store(uint32(len))

proc pack_set*[T](s: OutputStreamVar, val: set[T]) =
  s.pack_array(card(val))
  for e in items(val):
    s.pack_imp_uint64(uint64(e))

proc unpack_array*(s: ByteStreamVar): int =
  result = -1
  let c = s[].read
  if c >= byte(0x90) and c <= byte(0x9f): result = int(c) and 0x0f
  elif c == byte(0xdc):
    result = int(unstore[uint16](s))
  elif c == byte(0xdd):
    result = int(unstore[uint32](s))

proc unpack_set*[T](s: ByteStreamVar, val: var set[T]) =
  let len = s.unpack_array()
  if len < 0: raise conversionError("set")
  var x: T
  for i in 0..len-1:
    x = T(s.unpack_imp_uint64())
    val.incl(x)

proc pack_map*(s: OutputStreamVar, len: int) =
  if len <= 0x0F:
    s.append(byte(0b10000000 or (len and 0x0F)))
  elif len > 0x0F and len <= 0xFFFF:
    s.append(byte(0xde))
    s.store(uint16(len))
  elif len > 0xFFFF:
    s.append(byte(0xdf))
    s.store(uint32(len))

proc unpack_map*(s: ByteStreamVar): int =
  result = -1
  let c = s[].read
  if c >= byte(0x80) and c <= byte(0x8f): result = int(c) and 0x0f
  elif c == byte(0xde):
    result = int(unstore[uint16](s))
  elif c == byte(0xdf):
    result = int(unstore[uint32](s))
