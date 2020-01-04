# MessagePack implementation written in nim
#
# Copyright (c) 2015-2019 Andri Lim
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
#-------------------------------------
when not declared SomeFloat:
  type
    SomeFloat = SomeReal

import endians, macros, strutils, streams

const pack_value_nil* = chr(0xc0)

type
  EncodingMode* = enum
    MSGPACK_OBJ_TO_DEFAULT
    MSGPACK_OBJ_TO_ARRAY
    MSGPACK_OBJ_TO_MAP
    MSGPACK_OBJ_TO_STREAM

  MsgStream* = ref object
    data*: string
    pos*: int
    encodingMode: EncodingMode

proc init*(x: typedesc[MsgStream], cap: int = 0, encodingMode = MSGPACK_OBJ_TO_DEFAULT): MsgStream =
  result = new(x)
  result.data = newStringOfCap(cap)
  result.pos = 0
  result.encodingMode = encodingMode

proc init*(x: typedesc[MsgStream], data: string, encodingMode = MSGPACK_OBJ_TO_DEFAULT): MsgStream =
  result = new(x)
  shallowCopy(result.data, data)
  result.pos = 0
  result.encodingMode = encodingMode

proc initMsgStream*(cap: int = 0, encodingMode = MSGPACK_OBJ_TO_DEFAULT): MsgStream {.deprecated: "use MsgStream.init instead".} =
  result = MsgStream.init(cap, encodingMode)

proc initMsgStream*(data: string, encodingMode = MSGPACK_OBJ_TO_DEFAULT): MsgStream {.deprecated: "use MsgStream.init instead".} =
  result = MsgStream.init(data, encodingMode)

proc setEncodingMode*(s: MsgStream, encodingMode: EncodingMode) =
  s.encodingMode = encodingMode

proc getEncodingMode*(s: MsgStream): EncodingMode =
  s.encodingMode

proc writeData(s: MsgStream, buffer: pointer, bufLen: int) =
  if bufLen <= 0: return
  if s.pos + bufLen > s.data.len:
    setLen(s.data, s.pos + bufLen)
  copyMem(addr(s.data[s.pos]), buffer, bufLen)
  inc(s.pos, bufLen)

proc write*[T](s: MsgStream, val: T) =
  var y: T
  shallowCopy(y, val)
  writeData(s, addr(y), sizeof(y))

proc write*(s: MsgStream, val: string) =
  if val.len > 0: writeData(s, unsafeAddr val[0], val.len)

proc readData(s: MsgStream, buffer: pointer, bufLen: int): int =
  result = min(bufLen, s.data.len - s.pos)
  if result > 0:
    copyMem(buffer, addr(s.data[s.pos]), result)
    inc(s.pos, result)
  else:
    result = 0

proc read*[T](s: MsgStream, result: var T) =
  if s.readData(addr(result), sizeof(T)) != sizeof(T):
    doAssert(false)

proc readStr*(s: MsgStream, length: int): string =
  result = newString(length)
  if length != 0:
    var L = s.readData(addr(result[0]), length)
    if L != length: result.setLen(L)

proc readChar*(s: MsgStream): char =
  s.read(result)

proc readInt16*(s: MsgStream): int16 =
  s.read(result)

proc readInt32*(s: MsgStream): int32 =
  s.read(result)

proc readInt64*(s: MsgStream): int64 =
  s.read(result)

proc peekChar*(s: MsgStream): char =
  if s.pos < s.data.len: result = s.data[s.pos]
  else: result = chr(0)

proc setPosition*(s: MsgStream, pos: int) =
  s.pos = clamp(pos, 0, s.data.len)

proc atEnd*(s: MsgStream): bool =
  return s.pos >= s.data.len

proc conversionError*(msg: string): ref ObjectConversionError =
  new(result)
  result.msg = msg

template skipUndistinct* {.pragma, deprecated.}
  # no need to use this pragma anymore
  # the undistinct macro is more clever now

proc getParamIdent(n: NimNode): NimNode =
  n.expectKind({nnkIdent, nnkVarTy, nnkSym})
  if n.kind in {nnkIdent, nnkSym}:
    result = n
  else:
    result = n[0]

proc hasDistinctImpl(w: NimNode, z: NimNode): bool =
  for k in w:
    let p = k.getImpl()[3][2][1]
    if p.kind in {nnkIdent, nnkVarTy, nnkSym}:
      let paramIdent = getParamIdent(p)
      if eqIdent(paramIdent, z): return true

proc needToSkip(typ: NimNode | typedesc, w: NimNode): bool {.compileTime.} =
  let z = getType(typ)[1]

  if z.kind == nnkSym:
    if hasDistinctImpl(w, z): return true

  if z.kind != nnkSym: return false
  let impl = getImpl(z)
  if impl.kind != nnkTypeDef: return false
  if impl[2].kind != nnkDistinctTy: return false
  if impl[0].kind != nnkPragmaExpr: return false
  let prag = impl[0][1][0]
  result = eqIdent("skipUndistinct", prag)

#this macro convert any distinct types to it's base type
macro undistinctImpl*(x: typed, typ: typedesc, w: typed): untyped =
  var ty = getType(x)
  if needToSkip(typ, w):
    result = x
    return
  var isDistinct = ty.typekind == ntyDistinct
  if isDistinct:
    let parent = ty[1]
    result = quote do: `parent`(`x`)
  else:
    result = x

template undistinct_pack*(x: typed): untyped =
  undistinctImpl(x, type(x), bindSym("pack_type", brForceOpen))

template undistinct_unpack*(x: typed): untyped =
  undistinctImpl(x, type(x), bindSym("unpack_type", brForceOpen))

when system.cpuEndian == littleEndian:
  proc take8_8(val: uint8): uint8 {.inline.} = val
  proc take8_16(val: uint16): uint8 {.inline.} = uint8(val and 0xFF)
  proc take8_32(val: uint32): uint8 {.inline.} = uint8(val and 0xFF)
  proc take8_64(val: uint64): uint8 {.inline.} = uint8(val and 0xFF)

  proc store16[ByteStream](s: ByteStream, val: uint16) =
    var res: uint16
    swapEndian16(addr(res), unsafeAddr(val))
    s.write(res)
  proc store32[ByteStream](s: ByteStream, val: uint32) =
    var res: uint32
    swapEndian32(addr(res), unsafeAddr(val))
    s.write(res)
  proc store64[ByteStream](s: ByteStream, val: uint64) =
    var res: uint64
    swapEndian64(addr(res), unsafeAddr(val))
    s.write(res)
  proc unstore16[ByteStream](s: ByteStream): uint16 =
    var tmp: uint16 = cast[uint16](s.readInt16)
    swapEndian16(addr(result), addr(tmp))
  proc unstore32[ByteStream](s: ByteStream): uint32 =
    var tmp: uint32 = cast[uint32](s.readInt32)
    swapEndian32(addr(result), addr(tmp))
  proc unstore64[ByteStream](s: ByteStream): uint64 =
    var tmp: uint64 = cast[uint64](s.readInt64)
    swapEndian64(addr(result), addr(tmp))
else:
  proc take8_8(val: uint8): uint8 {.inline.} = val
  proc take8_16(val: uint16): uint8 {.inline.} = (val shr 8) and 0xFF
  proc take8_32(val: uint32): uint8 {.inline.} = (val shr 24) and 0xFF
  proc take8_64(val: uint64): uint8 {.inline.} = uint8((val shr 56) and 0xFF)

  proc store16[ByteStream](s: ByteStream, val: uint16) = s.write(val)
  proc store32[ByteStream](s: ByteStream, val: uint32) = s.write(val)
  proc store64[ByteStream](s: ByteStream, val: uint64) = s.write(val)
  proc unstore16[ByteStream](s: ByteStream): uint16 = cast[uint16](s.readInt16)
  proc unstore32[ByteStream](s: ByteStream): uint32 = cast[uint32](s.readInt32)
  proc unstore64[ByteStream](s: ByteStream): uint64 = cast[uint64](s.readInt64)

proc take8_8[T:uint8|char|int8](val: T): uint8 {.inline.} = uint8(val)
proc take16_8[T:uint8|char|int8](val: T): uint16 {.inline.} = uint16(val)
proc take32_8[T:uint8|char|int8](val: T): uint32 {.inline.} = uint32(val)
proc take64_8[T:uint8|char|int8](val: T): uint64 {.inline.} = uint64(val)

proc pack_bool*[ByteStream](s: ByteStream, val: bool) =
  if val: s.write(chr(0xc3))
  else: s.write(chr(0xc2))

proc pack_imp_nil*[ByteStream](s: ByteStream) =
  s.write(chr(0xc0))

proc pack_imp_uint8*[ByteStream](s: ByteStream, val: uint8) =
  if val < uint8(1 shl 7):
    #fixnum
    s.write(take8_8(val))
  else:
    #unsigned 8
    s.write(chr(0xcc))
    s.write(take8_8(val))

proc unpack_imp_uint8*[ByteStream](s: ByteStream): uint8 =
  let c = s.readChar
  if c < chr(128): result = take8_8(c)
  elif c == chr(0xcc):
    result = uint8(s.readChar)
  else: raise conversionError("uint8")

proc pack_imp_uint16*[ByteStream](s: ByteStream, val: uint16) =
  if val < uint16(1 shl 7):
    #fixnum
    s.write(take8_16(val))
  elif val < uint16(1 shl 8):
    #unsigned 8
    s.write(chr(0xcc))
    s.write(take8_16(val))
  else:
    #unsigned 16
    s.write(chr(0xcd))
    s.store16(val)

proc unpack_imp_uint16*[ByteStream](s: ByteStream): uint16 =
  let c = s.readChar
  if c < chr(128): result = take16_8(c)
  elif c == chr(0xcc):
    result = take16_8(s.readChar)
  elif c == chr(0xcd):
    result = s.unstore16()
  else: raise conversionError("uint16")

proc pack_imp_uint32*[ByteStream](s: ByteStream, val: uint32) =
  if val < uint32(1 shl 8):
    if val < uint32(1 shl 7):
      #fixnum
      s.write(take8_32(val))
    else:
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_32(val))
  else:
    if val < uint32(1 shl 16):
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))
    else:
      #unsigned 32
      s.write(chr(0xce))
      s.store32(val)

proc unpack_imp_uint32*[ByteStream](s: ByteStream): uint32 =
  let c = s.readChar
  if c < chr(128): result = take32_8(c)
  elif c == chr(0xcc):
    result = take32_8(s.readChar)
  elif c == chr(0xcd):
    result = uint32(s.unstore16())
  elif c == chr(0xce):
    result = s.unstore32()
  else: raise conversionError("uint32")

proc pack_imp_uint64*[ByteStream](s: ByteStream, val: uint64) =
  if val < uint64(1 shl 8):
    if val < uint64(1 shl 7):
      #fixnum
      s.write(take8_64(val))
    else:
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_64(val))
  else:
    if val < uint64(1 shl 16):
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))
    elif val < uint64(1 shl 32):
      #unsigned 32
      s.write(chr(0xce))
      s.store32(uint32(val))
    else:
      #unsigned 64
      s.write(chr(0xcf))
      s.store64(val)

proc unpack_imp_uint64*[ByteStream](s: ByteStream): uint64 =
  let c = s.readChar
  if c < chr(128): result = take64_8(c)
  elif c == chr(0xcc):
    result = take64_8(s.readChar)
  elif c == chr(0xcd):
    result = uint64(s.unstore16())
  elif c == chr(0xce):
    result = uint64(s.unstore32())
  elif c == chr(0xcf):
    result = s.unstore64()
  else: raise conversionError("uint64")

proc pack_imp_int8*[ByteStream](s: ByteStream, val: int8) =
  if val < -(1 shl 5):
    #signed 8
    s.write(chr(0xd0))
    s.write(take8_8(cast[uint8](val)))
  else:
    #fixnum
    s.write(take8_8(cast[uint8](val)))

proc unpack_imp_int8*[ByteStream](s: ByteStream): int8 =
  let c = s.readChar
  if c >= chr(0xe0) and c <= chr(0xff):
    result = cast[int8](c)
  elif c >= chr(0x00) and c <= chr(0x7f):
    result = cast[int8](c)
  elif c == chr(0xd0):
    result = cast[int8](s.readChar)
  else: raise conversionError("int8")

proc pack_imp_int16*[ByteStream](s: ByteStream, val: int16) =
  if val < -(1 shl 5):
    if val < -(1 shl 7):
      #signed 16
      s.write(chr(0xd1))
      s.store16(cast[uint16](val))
    else:
      #signed 8
      s.write(chr(0xd0))
      var x = cast[char](take8_16(cast[uint16](val)))
      s.write(x)
  elif val < (1 shl 7):
    var x = cast[char](take8_16(cast[uint16](val)))
    #fixnum
    s.write(x)
  else:
    if val < (1 shl 8):
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_16(uint16(val)))
    else:
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))

proc unpack_imp_int16*[ByteStream](s: ByteStream): int16 =
  let c = s.readChar
  if c >= chr(0xe0) and c <= chr(0xff):
    result = int16(cast[int8](c))
  elif c >= chr(0x00) and c <= chr(0x7f):
    result = int16(cast[int8](c))
  elif c == chr(0xd0):
    result = int16(cast[int8](s.readChar))
  elif c == chr(0xd1):
    result = cast[int16](s.unstore16)
  elif c == chr(0xcc):
    result = int16(s.readChar)
  elif c == chr(0xcd):
    result = cast[int16](s.unstore16)
  else: raise conversionError("int16")

proc pack_imp_int32*[ByteStream](s: ByteStream, val: int32) =
  if val < -(1 shl 5):
    if val < -(1 shl 15):
      #signed 32
      s.write(chr(0xd2))
      s.store32(cast[uint32](val))
    elif val < -(1 shl 7):
      #signed 16
      s.write(chr(0xd1))
      s.store16(cast[uint16](val))
    else:
      #signed 8
      s.write(chr(0xd0))
      var x = cast[char](take8_32(cast[uint32](val)))
      s.write(x)
  elif val < (1 shl 7):
    #fixnum
    var x = cast[char](take8_32(cast[uint32](val)))
    s.write(x)
  else:
    if val < (1 shl 8):
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_32(uint32(val)))
    elif val < (1 shl 16):
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))
    else:
      #unsigned 32
      s.write(chr(0xce))
      s.store32(uint32(val))

proc unpack_imp_int32*[ByteStream](s: ByteStream): int32 =
  let c = s.readChar
  if c >= chr(0xe0) and c <= chr(0xff):
    result = int32(cast[int8](c))
  elif c >= chr(0x00) and c <= chr(0x7f):
    result = int32(cast[int8](c))
  elif c == chr(0xd0):
    result = int32(cast[int8](s.readChar))
  elif c == chr(0xd1):
    result = int32(cast[int16](s.unstore16))
  elif c == chr(0xd2):
    result = cast[int32](s.unstore32)
  elif c == chr(0xcc):
    result = int32(s.readChar)
  elif c == chr(0xcd):
    result = int32(s.unstore16)
  elif c == chr(0xce):
    result = cast[int32](s.unstore32)
  else: raise conversionError("int32")

proc pack_imp_int64*[ByteStream](s: ByteStream, val: int64) =
  if val < -(1 shl 5):
    if val < -(1 shl 31):
      #signed 64
      s.write(chr(0xd3))
      s.store64(uint64(val))
    elif val < -(1 shl 15):
      #signed 32
      s.write(chr(0xd2))
      s.store32(cast[uint32](val))
    elif val < -(1 shl 7):
      #signed 16
      s.write(chr(0xd1))
      s.store16(cast[uint16](val))
    else:
      #signed 8
      s.write(chr(0xd0))
      var x = cast[char](take8_64(cast[uint64](val)))
      s.write(x)
  elif val < (1 shl 7):
    #fixnum
    var x = cast[char](take8_64(cast[uint64](val)))
    s.write(x)
  else:
    if val < (1 shl 8):
      #unsigned 8
      s.write(chr(0xcc))
      s.write(take8_64(uint64(val)))
    elif val < (1 shl 16):
      #unsigned 16
      s.write(chr(0xcd))
      s.store16(uint16(val))
    elif val < (1 shl 32):
      #unsigned 32
      s.write(chr(0xce))
      s.store32(uint32(val))
    else:
      #unsigned 64
      s.write(chr(0xcf))
      s.store64(uint64(val))

proc unpack_imp_int64*[ByteStream](s: ByteStream): int64 =
  let c = s.readChar
  if c >= chr(0xe0) and c <= chr(0xff):
    result = int64(cast[int8](c))
  elif c >= chr(0x00) and c <= chr(0x7f):
    result = int64(cast[int8](c))
  elif c == chr(0xd0):
    result = int64(cast[int8](s.readChar))
  elif c == chr(0xd1):
    result = int64(cast[int16](s.unstore16))
  elif c == chr(0xd2):
    result = int64(cast[int32](s.unstore32))
  elif c == chr(0xd3):
    result = cast[int64](s.unstore64)
  elif c == chr(0xcc):
    result = int64(s.readChar)
  elif c == chr(0xcd):
    result = int64(s.unstore16)
  elif c == chr(0xce):
    result = int64(s.unstore32)
  elif c == chr(0xcf):
    result = cast[int64](s.unstore64)
  else: raise conversionError("int64")

proc pack_imp_int*[ByteStream](s: ByteStream, val: int) =
  case sizeof(val)
  of 1: s.pack_imp_int8(int8(val))
  of 2: s.pack_imp_int16(int16(val))
  of 4: s.pack_imp_int32(int32(val))
  else: s.pack_imp_int64(int64(val))

proc pack_array*[ByteStream](s: ByteStream, len: int) =
  if len <= 0x0F:
    s.write(chr(0b10010000 or (len and 0x0F)))
  elif len > 0x0F and len <= 0xFFFF:
    s.write(chr(0xdc))
    s.store16(uint16(len))
  elif len > 0xFFFF:
    s.write(chr(0xdd))
    s.store32(uint32(len))

proc pack_map*[ByteStream](s: ByteStream, len: int) =
  if len <= 0x0F:
    s.write(chr(0b10000000 or (len and 0x0F)))
  elif len > 0x0F and len <= 0xFFFF:
    s.write(chr(0xde))
    s.store16(uint16(len))
  elif len > 0xFFFF:
    s.write(chr(0xdf))
    s.store32(uint32(len))

proc pack_bin*[ByteStream](s: ByteStream, len: int) =
  if len <= 0xFF:
    s.write(chr(0xc4))
    s.write(uint8(len))
  elif len > 0xFF and len <= 0xFFFF:
    s.write(chr(0xc5))
    s.store16(uint16(len))
  elif len > 0xFFFF:
    s.write(chr(0xc6))
    s.store32(uint32(len))

proc pack_ext*[ByteStream](s: ByteStream, len: int, exttype: int8) =
  case len
  of 1:
    s.write(chr(0xd4))
    s.write(exttype)
  of 2:
    s.write(chr(0xd5))
    s.write(exttype)
  of 4:
    s.write(chr(0xd6))
    s.write(exttype)
  of 8:
    s.write(chr(0xd7))
    s.write(exttype)
  of 16:
    s.write(chr(0xd8))
    s.write(exttype)
  else:
    if len < 256:
      s.write(chr(0xc7))
      s.write(uint8(len))
      s.write(exttype)
    elif len < 65536:
      s.write(chr(0xc8))
      s.store16(uint16(len))
      s.write(exttype)
    else:
      s.write(chr(0xc9))
      s.store32(uint32(len))
      s.write(exttype)

proc pack_string*[ByteStream](s: ByteStream, len: int) =
  if len < 32:
    var d = uint8(0xa0) or uint8(len)
    s.write(take8_8(d))
  elif len < 256:
    s.write(chr(0xd9))
    s.write(uint8(len))
  elif len < 65536:
    s.write(chr(0xda))
    s.store16(uint16(len))
  else:
    s.write(chr(0xdb))
    s.store32(uint32(len))

proc pack_type*[ByteStream](s: ByteStream, val: bool) =
  s.pack_bool(val)

proc pack_type*[ByteStream](s: ByteStream, val: char) =
  s.pack_imp_uint8(uint8(val))

proc pack_type*[ByteStream](s: ByteStream, val: string) =
  when compiles(isNil(val)):
    if isNil(val): s.pack_imp_nil()
    else:
      s.pack_string(val.len)
      s.write(val)
  else:
    s.pack_string(val.len)
    s.write(val)

proc pack_type*[ByteStream](s: ByteStream, val: uint8) =
  s.pack_imp_uint8(val)

proc pack_type*[ByteStream](s: ByteStream, val: uint16) =
  s.pack_imp_uint16(val)

proc pack_type*[ByteStream](s: ByteStream, val: uint32) =
  s.pack_imp_uint32(val)

proc pack_type*[ByteStream](s: ByteStream, val: uint64) =
  s.pack_imp_uint64(val)

proc pack_type*[ByteStream](s: ByteStream, val: int8) =
  s.pack_imp_int8(val)

proc pack_type*[ByteStream](s: ByteStream, val: int16) =
  s.pack_imp_int16(val)

proc pack_type*[ByteStream](s: ByteStream, val: int32) =
  s.pack_imp_int32(val)

proc pack_type*[ByteStream](s: ByteStream, val: int64) =
  s.pack_imp_int64(val)

proc pack_int_imp_select[ByteStream, T](s: ByteStream, val: T) =
  when sizeof(val) == 1:
    s.pack_imp_int8(int8(val))
  elif sizeof(val) == 2:
    s.pack_imp_int16(int16(val))
  elif sizeof(val) == 4:
    s.pack_imp_int32(int32(val))
  else:
    s.pack_imp_int64(int64(val))

proc pack_uint_imp_select[ByteStream, T](s: ByteStream, val: T) =
  if sizeof(T) == 1:
    s.pack_imp_uint8(cast[uint8](val))
  elif sizeof(T) == 2:
    s.pack_imp_uint16(cast[uint16](val))
  elif sizeof(T) == 4:
    s.pack_imp_uint32(cast[uint32](val))
  else:
    s.pack_imp_uint64(cast[uint64](val))

proc pack_type*[ByteStream](s: ByteStream, val: int) =
  pack_int_imp_select(s, val)

proc pack_type*[ByteStream](s: ByteStream, val: uint) =
  pack_uint_imp_select(s, val)

proc pack_imp_float32[ByteStream](s: ByteStream, val: float32) {.inline.} =
  let tmp = cast[uint32](val)
  s.write(chr(0xca))
  s.store32(tmp)

proc pack_imp_float64[ByteStream](s: ByteStream, val: float64) {.inline.} =
  let tmp = cast[uint64](val)
  s.write(chr(0xcb))
  s.store64(tmp)

proc pack_type*[ByteStream](s: ByteStream, val: float32) =
  s.pack_imp_float32(val)

proc pack_type*[ByteStream](s: ByteStream, val: float64) =
  s.pack_imp_float64(val)

proc pack_type*[ByteStream](s: ByteStream, val: SomeFloat) =
  when sizeof(val) == sizeof(float32):
    s.pack_imp_float32(float32(val))
  elif sizeof(val) == sizeof(float64):
    s.pack_imp_float64(float64(val))
  else:
    raise conversionError("float")

proc pack_type*[ByteStream, T](s: ByteStream, val: set[T]) =
  s.pack_array(card(val))
  for e in items(val):
    s.pack_imp_uint64(uint64(e))

proc pack_items_imp*[ByteStream, T](s: ByteStream, val: T) {.inline.} =
  var ss = MsgStream.init(sizeof(T))
  var count = 0
  for i in items(val):
    ss.pack undistinct_pack(i)
    inc(count)
  s.pack_array(count)
  s.write(ss.data)

proc pack_map_imp*[ByteStream, T](s: ByteStream, val: T) {.inline.} =
  s.pack_map(val.len)
  for k,v in pairs(val):
    s.pack_type undistinct_pack(k)
    s.pack_type undistinct_pack(v)

proc pack_type*[ByteStream, T](s: ByteStream, val: openArray[T]) =
  s.pack_array(val.len)
  for i in 0..val.len-1: s.pack_type undistinct_pack(val[i])

proc pack_type*[ByteStream, T](s: ByteStream, val: seq[T]) =
  when compiles(isNil(val)):
    if isNil(val): s.pack_imp_nil()
    else:
      s.pack_array(val.len)
      for i in 0..val.len-1: s.pack_type undistinct_pack(val[i])
  else:
    s.pack_array(val.len)
    for i in 0..val.len-1: s.pack_type undistinct_pack(val[i])

proc pack_type*[ByteStream; T: enum|range](s: ByteStream, val: T) =
  when val is range:
    pack_int_imp_select(s, val.int64)
  else:
    pack_int_imp_select(s, val)

proc pack_type*[ByteStream; T: tuple|object](s: ByteStream, val: T) =
  var len = 0
  for field in fields(val):
    inc(len)

  template dry_and_wet() =
    when defined(msgpack_obj_to_map):
      s.pack_map(len)
      for field, value in fieldPairs(val):
        s.pack_type field
        s.pack_type undistinct_pack(value)
    elif defined(msgpack_obj_to_stream):
      for field in fields(val):
        s.pack_type undistinct_pack(field)
    else:
      s.pack_array(len)
      for field in fields(val):
        s.pack_type undistinct_pack(field)

  when ByteStream is MsgStream:
    case s.encodingMode
    of MSGPACK_OBJ_TO_ARRAY:
      s.pack_array(len)
      for field in fields(val):
        s.pack_type undistinct_pack(field)
    of MSGPACK_OBJ_TO_MAP:
      s.pack_map(len)
      for field, value in fieldPairs(val):
        s.pack_type field
        s.pack_type undistinct_pack(value)
    of MSGPACK_OBJ_TO_STREAM:
      for field in fields(val):
        s.pack_type undistinct_pack(field)
    else:
      dry_and_wet()
  else:
    dry_and_wet()

proc pack_type*[ByteStream; T: ref](s: ByteStream, val: T) =
  if isNil(val): s.pack_imp_nil()
  else: s.pack_type(val[])

proc pack_type*[ByteStream, T](s: ByteStream, val: ptr T) =
  if isNil(val): s.pack_imp_nil()
  else: s.pack_type(val[])

proc unpack_type*[ByteStream](s: ByteStream, val: var bool) =
  let c = s.readChar
  if c == chr(0xc3): val = true
  elif c == chr(0xc2): val = false
  else: raise conversionError("bool")

proc unpack_type*[ByteStream](s: ByteStream, val: var char) =
  let c = s.readChar
  if c < chr(128): val = c
  elif c == chr(0xcc):
    val = s.readChar
  else: raise conversionError("char")

proc unpack_string*[ByteStream](s: ByteStream): int =
  result = -1
  let c = s.readChar
  if c >= chr(0xa0) and c <= chr(0xbf): result = ord(c) and 0x1f
  elif c == chr(0xd9):
    result = ord(s.readChar)
  elif c == chr(0xda):
    result = int(s.unstore16())
  elif c == chr(0xdb):
    result = int(s.unstore32())

proc unpack_type*[ByteStream](s: ByteStream, val: var string) =
  when compiles(isNil(val)):
    if s.peekChar == pack_value_nil:
      val = nil
      return
  else:
    if s.peekChar == pack_value_nil:
      val = ""
      return

  let len = s.unpack_string()
  if len < 0: raise conversionError("string")
  val = s.readStr(len)

proc unpack_type*[ByteStream](s: ByteStream, val: var uint8) =
  val = s.unpack_imp_uint8()

proc unpack_type*[ByteStream](s: ByteStream, val: var uint16) =
  val = s.unpack_imp_uint16()

proc unpack_type*[ByteStream](s: ByteStream, val: var uint32) =
  val = s.unpack_imp_uint32()

proc unpack_type*[ByteStream](s: ByteStream, val: var uint64) =
  val = s.unpack_imp_uint64()

proc unpack_type*[ByteStream](s: ByteStream, val: var int8) =
  val = s.unpack_imp_int8()

proc unpack_type*[ByteStream](s: ByteStream, val: var int16) =
  val = s.unpack_imp_int16()

proc unpack_type*[ByteStream](s: ByteStream, val: var int32) =
  val = s.unpack_imp_int32()

proc unpack_type*[ByteStream](s: ByteStream, val: var int64) =
  val = s.unpack_imp_int64()

proc unpack_int_imp_select[ByteStream, T](s: ByteStream, val: var T) =
  when sizeof(T) == 1:
    val = T(s.unpack_imp_int8())
  elif sizeof(T) == 2:
    val = T(s.unpack_imp_int16())
  elif sizeof(T) == 4:
    val = T(s.unpack_imp_int32())
  else:
    val = int(s.unpack_imp_int64())

proc unpack_type*[ByteStream](s: ByteStream, val: var int) =
  unpack_int_imp_select(s, val)

proc unpack_type*[ByteStream](s: ByteStream, val: var uint) =
  if sizeof(val) == 1:
    val = s.unpack_imp_uint8()
  elif sizeof(val) == 2:
    val = s.unpack_imp_uint16()
  elif sizeof(val) == 4:
    val = s.unpack_imp_uint32()
  else:
    val = uint(s.unpack_imp_uint64())

proc unpack_imp_float32*[ByteStream](s: ByteStream): float32 {.inline.} =
  let c = s.readChar
  if c == chr(0xca):
    result = cast[float32](s.unstore32)
  else:
    raise conversionError("float32")

proc unpack_imp_float64*[ByteStream](s: ByteStream): float64 {.inline.} =
  let c = s.readChar
  if c == chr(0xcb):
    result = cast[float64](s.unstore64)
  else:
    raise conversionError("float64")

proc unpack_type*[ByteStream](s: ByteStream, val: var float32) =
  val = s.unpack_imp_float32()

proc unpack_type*[ByteStream](s: ByteStream, val: var float64) =
  val = s.unpack_imp_float64()

proc unpack_type*[ByteStream](s: ByteStream, val: var SomeFloat) =
  when sizeof(val) == sizeof(float32):
    result = float32(s.unpack_imp_float32())
  elif sizeof(val) == sizeof(float64):
    result = float64(s.unpack_imp_float64())
  else:
    raise conversionError("float")

proc unpack_array*[ByteStream](s: ByteStream): int =
  result = -1
  let c = s.readChar
  if c >= chr(0x90) and c <= chr(0x9f): result = ord(c) and 0x0f
  elif c == chr(0xdc):
    result = int(s.unstore16())
  elif c == chr(0xdd):
    result = int(s.unstore32())

proc unpack_type*[ByteStream, T](s: ByteStream, val: var set[T]) =
  let len = s.unpack_array()
  if len < 0: raise conversionError("set")
  var x: T
  for i in 0..len-1:
    x = T(s.unpack_imp_uint64())
    val.incl(x)

template unpack_items_imp*(s: typed, val: typed, msg: typed) =
  let len = s.unpack_array()
  if len < 0: raise conversionError(msg)

  var x: T
  var y: seq[T] = @[]
  for i in 0..len-1:
    s.unpack(x)
    y.add(x)
  for i in 0..len-1:
    val.prepend(y.pop())

proc unpack_map*[ByteStream](s: ByteStream): int =
  result = -1
  let c = s.readChar
  if c >= chr(0x80) and c <= chr(0x8f): result = ord(c) and 0x0f
  elif c == chr(0xde):
    result = int(s.unstore16())
  elif c == chr(0xdf):
    result = int(s.unstore32())

proc unpack_type*[ByteStream, T](s: ByteStream, val: var seq[T]) =
  when compiles(isNil(val)):
    if s.peekChar == pack_value_nil:
      val = nil
      return
  else:
    if s.peekChar == pack_value_nil:
      val = @[]
      return

  let len = s.unpack_array()
  if len < 0: raise conversionError("sequence")
  var x:T
  val = newSeq[T](len)
  for i in 0..len-1:
    s.unpack(x)
    val[i] = x

proc unpack_type*[ByteStream, T](s: ByteStream, val: var openarray[T]) =
  let len = s.unpack_array()
  if len < 0: raise conversionError("openarray")
  var x:T
  for i in 0..len-1:
    s.unpack(x)
    val[i] = x

proc unpack_type*[ByteStream; T: enum|range](s: ByteStream, val: var T) =
  when val is range:
    var tmp = s.unpack_imp_int64
    val = T(tmp)
  else:
    unpack_int_imp_select(s, val)

#bug #4 remedy
#don't know why the above proc cannot capture enum type properly
#that's why we need a proxy here
proc unpack_enum_proxy*[ByteStream, T](s: ByteStream, val: T): T =
  result = T(s.unpack_imp_int64)

macro unpack_proxy(n: typed): untyped =
  if getType(n).kind == nnkEnumTy:
    result = quote do:
      `n` = s.unpack_enum_proxy(`n`)
  else:
    result = quote do:
      s.unpack `n`

proc is_string*[ByteStream](s: ByteStream): bool =
  let c = s.peekChar
  if c >= chr(0xa0) and c <= chr(0xbf):
    return true
  result = c in {chr(0xd9), chr(0xda), chr(0xdb)}

proc is_map*[ByteStream](s: ByteStream): bool =
  let c = s.peekChar
  if c >= chr(0x80) and c <= chr(0x8f):
    return true
  result = c in {chr(0xde), chr(0xdf)}

proc is_array*[ByteStream](s: ByteStream): bool =
  let c = s.peekChar
  if c >= chr(0x90) and c <= chr(0x9f):
    return true
  result = c in {chr(0xdc), chr(0xdd)}

proc is_bin*[ByteStream](s: ByteStream): bool =
  let c = s.peekChar
  result = c in {chr(0xc4), chr(0xc5), chr(0xc6)}

proc is_ext*[ByteStream](s: ByteStream): bool =
  let c = s.peekChar
  if c >= chr(0xd4) and c <= chr(0xd8):
    return true
  result = c in {chr(0xc7), chr(0xc8), chr(0xc9)}

proc is_bool*[ByteStream](s: ByteStream): bool =
  let c = s.peekChar
  result = c in {chr(0xc3), chr(0xc2)}

proc is_float*[ByteStream](s: ByteStream): bool =
  let c = s.peekChar
  result = c in {chr(0xca), chr(0xcb)}

proc is_uint*[ByteStream](s: ByteStream): bool =
  let c = s.peekChar
  if c >= chr(0xcc) and c <= chr(0xcf):
    return true
  result = c < chr(128)

proc is_int*[ByteStream](s: ByteStream): bool =
  let c = s.peekChar
  if c >= chr(0xe0) and c <= chr(0xff):
    return true
  if c >= chr(0x00) and c <= chr(0x7f):
    return true
  if c >= chr(0xd0) and c <= chr(0xd3):
    return true
  if c >= chr(0xcc) and c <= chr(0xcf):
    return true

proc skip_msg*[ByteStream](s: ByteStream) =
  let c = ord(s.peekChar)
  var len = 0
  case c
  of 0x00..0x7f, 0xc0..0xc3, 0xe0..0xff:
    discard s.readChar()
  of 0x80..0x8f, 0xde..0xdf:
    len = s.unpack_map()
    for i in 0..len-1:
      skip_msg(s)
      skip_msg(s)
  of 0x90..0x9f, 0xdc..0xdd:
    len = s.unpack_array()
    for i in 0..len-1:
      skip_msg(s)
  of 0xa0..0xbf, 0xd9..0xdb:
    len = s.unpack_string()
    discard s.readStr(len)
  of 0xc4..0xc6:
    len = s.unpack_bin()
    discard s.readStr(len)
  of 0xc7..0xc9, 0xd4..0xd8:
    let (_, extlen) = s.unpack_ext()
    discard s.readStr(extlen)
  of 0xca:
    discard s.unpack_imp_float32()
  of 0xcb:
    discard s.unpack_imp_float64()
  of 0xcc..0xcf:
    discard s.unpack_imp_uint64()
  of 0xd0..0xd3:
    discard s.unpack_imp_int64()
  else:
    raise conversionError("unknown command during skip")

proc unpack_type*[ByteStream; T: tuple|object](s: ByteStream, val: var T) =
  template dry_and_wet(): untyped =
    when defined(msgpack_obj_to_map):
      let len = s.unpack_map()
      var name: string
      var found: bool
      for i in 0..len-1:
        if not s.is_string:
          s.skip_msg()
          s.skip_msg()
          continue
        unpack_proxy(name)
        found = false
        for field, value in fieldPairs(val):
          if field == name:
            found = true
            unpack_proxy(value)
            break
        if not found:
          s.skip_msg()
    elif defined(msgpack_obj_to_stream):
      for field in fields(val):
        unpack_proxy(field)
    else:
      let arrayLen = s.unpack_array()
      var length = 0
      for field in fields(val):
        unpack_proxy(field)
        inc length
      doAssert(arrayLen == length, "object/tuple len mismatch")

  when ByteStream is MsgStream:
    case s.encodingMode
    of MSGPACK_OBJ_TO_ARRAY:
      let arrayLen = s.unpack_array()
      var len = 0
      for field in fields(val):
        unpack_proxy(field)
        inc len
      doAssert(arrayLen == len, "object/tuple len mismatch")
    of MSGPACK_OBJ_TO_MAP:
      let len = s.unpack_map()
      var name: string
      var found: bool
      for i in 0..len-1:
        if not s.is_string:
          s.skip_msg()
          s.skip_msg()
          continue
        unpack_proxy(name)
        found = false
        for field, value in fieldPairs(val):
          if field == name:
            found = true
            unpack_proxy(value)
            break
        if not found:
          s.skip_msg()
    of MSGPACK_OBJ_TO_STREAM:
      for field in fields(val):
        unpack_proxy(field)
    else:
      dry_and_wet()
  else:
    dry_and_wet()

proc unpack_type*[ByteStream; T: ref](s: ByteStream, val: var T) =
  if s.peekChar == pack_value_nil: return
  if isNil(val): new(val)
  s.unpack(val[])

proc unpack_type*[ByteStream, T](s: ByteStream, val: var ptr T) =
  if s.peekChar == pack_value_nil: return
  if isNil(val): val = cast[ptr T](alloc(sizeof(T)))
  s.unpack(val[])

proc unpack_bin*[ByteStream](s: ByteStream): int =
  let c = s.readChar
  if c == chr(0xc4):
    result = ord(s.readChar)
  elif c == chr(0xc5):
    result = int(s.unstore16)
  elif c == chr(0xc6):
    result = int(s.unstore32)
  else:
    raise conversionError("bin")

proc unpack_ext*[ByteStream](s: ByteStream): tuple[exttype: int8, len: int] =
  let c = s.readChar
  case c
  of chr(0xd4):
    let t = cast[int8](s.readChar)
    result = (t, 1)
  of chr(0xd5):
    let t = cast[int8](s.readChar)
    result = (t, 2)
  of chr(0xd6):
    let t = cast[int8](s.readChar)
    result = (t, 4)
  of chr(0xd7):
    let t = cast[int8](s.readChar)
    result = (t, 8)
  of chr(0xd8):
    let t = cast[int8](s.readChar)
    result = (t, 16)
  else:
    if c == chr(0xc7):
      let len = ord(s.readChar)
      let t = cast[int8](s.readChar)
      result = (t, len)
    elif c == chr(0xc8):
      let len = int(s.unstore16)
      let t = cast[int8](s.readChar)
      result = (t, len)
    elif c == chr(0xc9):
      let len = int(s.unstore32)
      let t = cast[int8](s.readChar)
      result = (t, len)
    else:
      raise conversionError("ext")

proc pack_type*[ByteStream; T: proc](s: ByteStream, val: T) =
  s.pack_imp_nil()

proc unpack_type*[ByteStream; T: proc](s: ByteStream, val: var T) =
  discard
  #raise conversionError("can't convert proc type")

proc pack_type*[ByteStream](s: ByteStream, val: cstring) =
  s.pack_imp_nil()

proc unpack_type*[ByteStream](s: ByteStream, val: var cstring) =
  discard
  #raise conversionError("can't convert cstring type")

proc pack_type*[ByteStream](s: ByteStream, val: pointer) =
  s.pack_imp_nil()

proc unpack_type*[ByteStream](s: ByteStream, val: var pointer) =
  discard
  #raise conversionError("can't convert pointer type")

proc pack*[ByteStream, T](s: ByteStream, val: T) = s.pack_type undistinct_pack(val)
proc unpack*[ByteStream, T](s: ByteStream, val: var T) = s.unpack_type undistinct_unpack(val)

proc pack*[T](val: T): string =
  var s = MsgStream.init(sizeof(T))
  s.pack(val)
  result = s.data

proc unpack*[T](data: string, val: var T) =
  var s = MsgStream.init(data)
  s.setPosition(0)
  s.unpack(val)

proc unpack*[ByteStream, T](s: ByteStream, val: typedesc[T]): T {.inline.} =
  unpack(s, result)

proc unpack*[T](data: string, val: typedesc[T]): T {.inline.} =
  unpack(data, result)

proc stringify[ByteStream](s: ByteStream, zz: ByteStream) =
  let c = ord(s.peekChar)
  var len = 0
  case c
  of 0x00..0x7f:
    zz.write($c)
    discard s.readChar()
  of 0x80..0x8f:
    len = s.unpack_map()
    zz.write("{ ")
    for i in 0..len-1:
      if i > 0: zz.write(", ")
      stringify(s, zz)
      zz.write(" : ")
      stringify(s, zz)
    zz.write(" }")
  of 0x90..0x9f:
    len = s.unpack_array()
    zz.write("[ ")
    for i in 0..len-1:
      if i > 0: zz.write(", ")
      stringify(s, zz)
    zz.write(" ]")
  of 0xa0..0xbf:
    len = s.unpack_string()
    let str = s.readStr(len)
    zz.write("\"" & str & "\"")
  of 0xc0:
    zz.write("null")
    discard s.readChar()
  of 0xc1:
    discard s.readChar()
    raise conversionError("stringify unused")
  of 0xc2:
    zz.write("false")
    discard s.readChar()
  of 0xc3:
    zz.write("true")
    discard s.readChar()
  of 0xc4..0xc6:
    len = s.unpack_bin()
    zz.write("BIN: ")
    let str = s.readStr(len)
    for cc in str:
      zz.write(toHex(ord(cc), 2))
  of 0xc7..0xc9:
    let (exttype, extlen) = s.unpack_ext()
    zz.write("EXT: " & toHex(exttype, 2) & " ")
    let str = s.readStr(extlen)
    for cc in str:
      zz.write(toHex(ord(cc), 2))
  of 0xca:
    let f = s.unpack_imp_float32()
    zz.write($f)
  of 0xcb:
    let f = s.unpack_imp_float64()
    zz.write($f)
  of 0xcc..0xcf:
    let f = s.unpack_imp_uint64()
    zz.write($f)
  of 0xd0..0xd3:
    let f = s.unpack_imp_int64()
    zz.write($f)
  of 0xd4..0xd8:
    let (exttype, extlen) = s.unpack_ext()
    zz.write("EXT: " & toHex(exttype, 2) & " ")
    let str = s.readStr(extlen)
    for cc in str:
      zz.write(toHex(ord(cc), 2))
  of 0xd9..0xdb:
    len = s.unpack_string()
    let str = s.readStr(len)
    zz.write("\"" & str & "\"")
  of 0xdc..0xdd:
    len = s.unpack_array()
    zz.write("[ ")
    for i in 0..len-1:
      if i > 0: zz.write(", ")
      stringify(s, zz)
    zz.write(" ]")
  of 0xde..0xdf:
    len = s.unpack_map()
    zz.write("{ ")
    for i in 0..len-1:
      if i > 0: zz.write(", ")
      stringify(s, zz)
      zz.write(" : ")
      stringify(s, zz)
    zz.write(" }")
  of 0xe0..0xff:
    zz.write($cast[int8](c))
    discard s.readChar()
  else:
    raise conversionError("unknown command")

proc stringify*(data: string): string =
  var s = MsgStream.init(data)
  var zz = MsgStream.init(data.len)
  while not s.atEnd():
    stringify(s, zz)
    zz.write(" ")
  result = zz.data
