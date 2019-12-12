import
  typetraits,
  faststreams/output_stream, serialization, msgpack

export msgpack

type
  MsgpackWriter* = object
    stream*: OutputStreamVar

proc init*(T: type MsgpackWriter, stream: OutputStreamVar): T =
  result.stream = stream

template append(x: untyped) =
  w.stream.append x

template append(x, y: untyped) =
  `pack x`(w.stream, y)

proc writeNil*(w: var MsgpackWriter) =
  append pack_value_nil

proc writeValue*(w: var MsgpackWriter, value: auto) =
  mixin enumInstanceSerializedFields, writeValue, writeFieldIMPL

  when value is bool:
    append(bool, value)

  elif value is string:
    append(string, value)

  elif value is enum:
    pack_enum(w.stream, value)

  elif value is range:
    when low(value) < 0:
      pack_imp_int64(w.stream, int64(value))
    else:
      pack_imp_uint64(w.stream, uint64(value))

  elif value is SomeInteger:
    when low(value) < 0:
      pack_int_imp_select(w.stream, value)
    else:
      pack_uint_imp_select(w.stream, value)

  elif value is SomeFloat:
    append(float, value)

  elif value is set:
    append(set, value)

  elif value is (seq or array):
    pack_array(w.stream, value.len)
    for v in items(value): writeValue(w, v)

  elif value is ref|ptr:
    if value == nil:
      append pack_value_nil
    else:
      writeValue(w, value[])

  elif value is (object or tuple):
    type RecordType = type value
    var fieldsCount = 0
    value.enumInstanceSerializedFields(fieldName, field):
      inc fieldsCount
    pack_map(w.stream, fieldsCount)
    value.enumInstanceSerializedFields(fieldName, field):
      type FieldType = type field
      append(string, fieldName)
      w.writeFieldIMPL(FieldTag[RecordType, fieldName, FieldType], field, value)

  else:
    const typeName = typetraits.name(value.type)
    {.fatal: "Failed to convert to Msgpack an unsupported type: " & typeName.}

proc toMsgpack*(v: auto): string =
  mixin writeValue

  var s = init OutputStream
  var w = MsgpackWriter.init(s)
  w.writeValue v
  return s.getOutput(string)
