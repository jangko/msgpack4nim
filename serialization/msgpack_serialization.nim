import
  serialization, reader, writer, msgpack

import stew/shims/sets, options, stew/shims/tables

export
  serialization, reader, writer, sets, options, tables

serializationFormat Msgpack,
                    Reader = MsgpackReader,
                    Writer = MsgpackWriter,
                    PreferedOutput = string,
                    mimeType = "application/msgpack"

template supports*(_: type Msgpack, T: type): bool =
  # The Msgpack format should support every type
  true

proc writeValue*(writer: var MsgpackWriter, value: Option) =
  mixin writeValue

  if value.isSome:
    writer.writeValue value.get
  else:
    writer.writeNil

proc readValue*[T](reader: var MsgpackReader, value: var Option[T]) =
  mixin readValue

  if reader.stream[].peek == pack_value_nil:
    reset value
    discard reader.stream[].read
  else:
    value = some reader.readValue(T)

type
  SetType* = OrderedSet | HashSet

proc writeValue*(writer: var MsgpackWriter, value: SetType) =
  mixin writeValue

  writer.stream.pack_array(value.len)
  for e in value:
    writer.writeValue(e)

proc readValue*(reader: var MsgpackReader, value: var SetType) =
  mixin readValue

  type ElemType = type(value.items)
  value = init SetType
  let len = reader.stream.unpack_array()
  for i in 0..len-1:
    value.incl(reader.readValue(ElemType))

type
  TableType* = OrderedTable | Table

proc writeValue*(writer: var MsgpackWriter, value: TableType) =
  mixin writeValue
  pack_map(writer.stream, value.len)
  for key, val in value:
    writer.writeValue(key)
    writer.writeValue(val)

proc readValue*(reader: var MsgpackReader, value: var TableType) =
  mixin readValue

  type KeyType = type(value.keys)
  type ValueType = type(value.values)
  value = init TableType
  let numFields = unpack_map(reader.stream)
  for _ in 0..<numFields:
    value[reader.readValue(KeyType)] = reader.readValue(ValueType)
