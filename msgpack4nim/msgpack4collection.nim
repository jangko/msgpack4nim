import sequtils, math, ../msgpack4nim
import tables, intsets, lists, deques, sets, strtabs, critbits

proc pack_type*[ByteStream](s: ByteStream, val: IntSet) =
  var ss = MsgStream.init()
  var count = 0
  for i in items(val):
    ss.pack_imp_int(i)
    inc(count)
  s.pack_array(count)
  s.write(ss.data)

proc pack_type*[ByteStream, T](s: ByteStream, val: SinglyLinkedList[T]) =
  s.pack_items_imp(val)

proc pack_type*[ByteStream, T](s: ByteStream, val: DoublyLinkedList[T]) =
  s.pack_items_imp(val)

proc pack_type*[ByteStream, T](s: ByteStream, val: SinglyLinkedRing[T]) =
  s.pack_items_imp(val)

proc pack_type*[ByteStream, T](s: ByteStream, val: DoublyLinkedRing[T]) =
  s.pack_items_imp(val)

proc pack_type*[ByteStream, T](s: ByteStream, val: Deque[T]) =
  s.pack_array(val.len)
  for i in items(val): s.pack_type undistinct_pack(i)

proc pack_type*[ByteStream, T](s: ByteStream, val: HashSet[T]) =
  s.pack_array(val.len)
  for i in items(val): s.pack_type undistinct_pack(i)

proc pack_type*[ByteStream, T](s: ByteStream, val: OrderedSet[T]) =
  s.pack_array(val.len)
  for i in items(val): s.pack_type undistinct_pack(i)

proc pack_type*[ByteStream, K,V](s: ByteStream, val: Table[K,V]) =
  s.pack_map_imp(val)

proc pack_type*[ByteStream, K,V](s: ByteStream, val: TableRef[K,V]) =
  if isNil(val): s.pack_imp_nil()
  else:
    s.pack_map_imp(val)

proc pack_type*[ByteStream, K,V](s: ByteStream, val: OrderedTable[K,V]) =
  s.pack_map_imp(val)

proc pack_type*[ByteStream, K,V](s: ByteStream, val: OrderedTableRef[K,V]) =
  if isNil(val): s.pack_imp_nil()
  else:
    s.pack_map_imp(val)

proc pack_type*[ByteStream](s: ByteStream, val: StringTableRef) =
  if isNil(val): s.pack_imp_nil()
  else:
    s.pack_map_imp(val)

proc pack_type*[ByteStream, T](s: ByteStream, val: CritBitTree[T]) =
  when T is void:
    s.pack_array(val.len)
    for i in items(val): s.pack_type(i)
  else:
    s.pack_map_imp(val)

proc unpack_type*[ByteStream, T](s: ByteStream, val: var SinglyLinkedList[T]) =
  val = initSinglyLinkedList[T]()
  s.unpack_items_imp(val, "singly linked list")

proc unpack_type*[ByteStream, T](s: ByteStream, val: var DoublyLinkedList[T]) =
  val = initDoublyLinkedList[T]()
  s.unpack_items_imp(val, "doubly linked list")

proc unpack_type*[ByteStream, T](s: ByteStream, val: var SinglyLinkedRing[T]) =
  val = initSinglyLinkedRing[T]()
  s.unpack_items_imp(val, "singly linked ring")

proc unpack_type*[ByteStream, T](s: ByteStream, val: var DoublyLinkedRing[T]) =
  val = initDoublyLinkedRing[T]()
  s.unpack_items_imp(val, "doubly linked ring")

proc unpack_type*[ByteStream, T](s: ByteStream, val: var Deque[T]) =
  let len = s.unpack_array()
  if len < 0: raise conversionError("Deque")

  val = initDeque[T](math.nextPowerOfTwo(len))
  var x: T
  for i in 0..len-1:
    s.unpack(x)
    val.addLast(x)

proc unpack_type*[ByteStream, T](s: ByteStream, val: var HashSet[T]) =
  let len = s.unpack_array()
  if len < 0: raise conversionError("hash set")

  val = initHashSet[T](math.nextPowerOfTwo(len))
  var x: T
  for i in 0..len-1:
    s.unpack(x)
    val.incl(x)

proc unpack_type*[ByteStream, T](s: ByteStream, val: var OrderedSet[T]) =
  let len = s.unpack_array()
  if len < 0: raise conversionError("ordered set")

  val = initOrderedSet[T](math.nextPowerOfTwo(len))
  var x: T
  for i in 0..len-1:
    s.unpack(x)
    val.incl(x)

proc unpack_type*[ByteStream, K,V](s: ByteStream, val: var Table[K,V]) =
  let len = s.unpack_map()
  if len < 0: raise conversionError("table")

  val = initTable[K,V](math.nextPowerOfTwo(len))
  var k: K
  var v: V
  for i in 0..len-1:
    s.unpack(k)
    s.unpack(v)
    val[k] = v

proc unpack_type*[ByteStream, K,V](s: ByteStream, val: var TableRef[K,V]) =
  if s.peekChar == pack_value_nil: return

  let len = s.unpack_map()
  if len < 0: raise conversionError("tableref")

  val = newTable[K,V](math.nextPowerOfTwo(len))
  var k: K
  var v: V
  for i in 0..len-1:
    s.unpack(k)
    s.unpack(v)
    val[k] = v

proc unpack_type*[ByteStream, K,V](s: ByteStream, val: var OrderedTable[K,V]) =
  let len = s.unpack_map()
  if len < 0: raise conversionError("ordered table")

  val = initOrderedTable[K,V](math.nextPowerOfTwo(len))
  var k: K
  var v: V
  for i in 0..len-1:
    s.unpack(k)
    s.unpack(v)
    val[k] = v

proc unpack_type*[ByteStream, K,V](s: ByteStream, val: var OrderedTableRef[K,V]) =
  if s.peekChar == pack_value_nil: return

  let len = s.unpack_map()
  if len < 0: raise conversionError("ordered tableref")

  val = newOrderedTable[K,V](math.nextPowerOfTwo(len))
  var k: K
  var v: V
  for i in 0..len-1:
    s.unpack(k)
    s.unpack(v)
    val[k] = v

proc unpack_type*[ByteStream](s: ByteStream, val: var StringTableRef) =
  if s.peekChar == pack_value_nil: return

  let len = s.unpack_map()
  if len < 0: raise conversionError("string table")

  val = newStringTable(modeCaseSensitive)
  var k, v: string
  for i in 0..len-1:
    s.unpack_type(k)
    s.unpack_type(v)
    val[k] = v

proc unpack_type*[ByteStream, T](s: ByteStream, val: var CritBitTree[T]) =
  when T is void:
    let len = s.unpack_array()
    if len < 0: raise conversionError("critbit tree")
    var key: string
    for i in 0..len-1:
      s.unpack_type(key)
      val.incl(key)
  else:
    let len = s.unpack_map()
    if len < 0: raise conversionError("critbit tree")

    var k: string
    var v: T
    for i in 0..len-1:
      s.unpack(k)
      s.unpack(v)
      val[k] = v

proc unpack_type*[ByteStream](s: ByteStream, val: var IntSet) =
  val = initIntSet()
  let len = s.unpack_array()
  if len < 0: raise conversionError("int set")

  var x: int
  for i in 0..len-1:
    x = s.unpack_imp_int32()
    val.incl(x)
