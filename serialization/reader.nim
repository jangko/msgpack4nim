import
  typetraits, msgpack,
  faststreams/input_stream, serialization/[object_serialization, errors]

export msgpack

type
  MsgpackReader* = object
    stream*: ByteStreamVar

  UnexpectedField* = object of Exception
    encounteredField*: cstring
    deserializedType*: cstring

  GenericMsgpackReaderError* = object of Exception
    deserializedField*: string
    innerException*: ref CatchableError

proc init*(T: type MsgpackReader, stream: ByteStreamVar): T =
  result.stream = stream

template unpack(x, y: untyped) =
  `unpack x`(r.stream, y)

proc raiseUnexpectedField*(r: MsgpackReader, fieldName, deserializedType: cstring) =
  var ex = new UnexpectedField
  ex.encounteredField = fieldName
  ex.deserializedType = deserializedType
  raise ex

proc handleReadException*(r: MsgpackReader,
                          Record: type,
                          fieldName: string,
                          field: auto,
                          err: ref CatchableError) =
  var ex = new GenericMsgpackReaderError
  ex.deserializedField = fieldName
  ex.innerException = err
  raise ex

proc allocPtr[T](p: var ptr T) =
  p = create(T)

proc allocPtr[T](p: var ref T) =
  p = new(T)

proc readValue*(r: var MsgpackReader, value: var auto) =
  mixin readValue

  type T = type(value)

  when value is bool:
    unpack(bool, value)

  elif value is string:
    unpack(string, value)

  elif value is enum:
    unpack_enum(r.stream, value)

  elif value is range:
    when low(value) < 0:
      value = T(unpack_imp_int64(r.stream))
    else:
      value = T(unpack_imp_uint64(r.stream))

  elif value is SomeInteger:
    when low(value) < 0:
      unpack_int_imp_select(r.stream, value)
    else:
      unpack_uint_imp_select(r.stream, value)

  elif value is SomeFloat:
    unpack(float, value)

  elif value is set:
    append(set, value)

  elif value is seq:
    let len = unpack_array(r.stream)
    value.setLen(len)
    for i in 0..<len: readValue(r, value[i])

  elif value is array:
    let len = unpack_array(r.stream)
    for i in 0..<len: readValue(r.stream, value[i])

  elif value is ref|ptr:
    if r.stream[].peek == pack_value_nil:
      value = nil
      discard r.stream[].read
    else:
      allocPtr value
      value[] = readValue(r, type(value[]))

  elif value is (object or tuple):
    when T.totalSerializedFields > 0:
      let numFields = unpack_map(r.stream)
      let fields = T.fieldReadersTable(MsgpackReader)
      var expectedFieldPos = 0
      for _ in 0..<numFields:
        var fieldName: string
        unpack(string, fieldName)
        debugEcho "fieldName: ", fieldName
        when T is tuple:
          var reader = fields[][expectedFieldPos].reader
          expectedFieldPos += 1
        else:
          var reader = findFieldReader(fields[], fieldName, expectedFieldPos)
        if reader != nil:
          reader(value, r)
        else:
          const typeName = typetraits.name(T)
          r.raiseUnexpectedField(fieldName, typeName)
  else:
    const typeName = typetraits.name(value.type)
    {.error: "Failed to convert to Msgpack an unsupported type: " & typeName.}
