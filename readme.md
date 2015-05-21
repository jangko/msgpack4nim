#msgpack4nim

[MessagePack](http://msgpack.org/) implementation written in pure nim

###why another implementation?
I am fully aware of [another](https://github.com/akiradeveloper/msgpack-nim) msgpack implementation written in nim. But I want something easier to use. Another motivation come from the nim language itself. The current version of nim compiler offer many improvements, including 'generics ' specialization. I found out nim compiler is smart enough to make serialization/deserialization to/from msgpack easy and convenient.

**requirement:** nim ver 0.11.2 or later

## Example

```nimrod
import msgpack, streams

type
  #lets try with a rather complex object
  CustomType = object
    count: int
    content: seq[int]
    name: string
    ratio: float
    attr: array[0..5, int]
    ok: bool

proc initCustomType(): CustomType =
  result.count = -1
  result.content = @[1,2,3]
  result.name = "custom"
  result.ratio = 1.0
  for i in 0..5: result.attr[i] = i
  result.ok = false

var x = initCustomType()
#you can use another stream compatible
#class here e.g. FileStream
var s = newStringStream() 
s.pack(x) #here the magic happened

s.setPosition(0)
var xx: CustomType
s.unpack(xx) #and here too

assert xx == x
echo "OK ", xx.name
```
see? you only need to call 'pack' and 'unpack', and the compiler do the hard work for you. Very easy, convenient, and works well

if you think setting up a StringStream too much for you, you can simply call pack(yourobject) and it will return a string containing msgpack data.

```nimrod
  var a = @[1,2,3,4,5,6,7,8,9,0]
  var buf = pack(a)
  var aa: seq[int]
  unpack(buf, aa)
  assert a == aa
```

in case the compiler cannot decide how to serialize or deserialize your very very complex object, you can help it in easy way

```nimrod
type
  #not really complex, just for example
  mycomplexobject = object
    a: someSimpleType
    b: someSimpleType

#help the compiler to decide
proc pack(s: Stream, x: mycomplexobject) =
  s.pack(x.a) # let the compiler decide
  s.pack(x.b) # let the compiler decide

#help the compiler to decide
proc unpack(s: Stream, x: var complexobject) =
  s.unpack(x.a)
  s.unpack(x.b)

var s: newStringStream()
var x: mycomplexobject

s.pack(x) #pack as usual

s.setPosition(0)
s.unpack(x) #unpack as usual
```

##Data Conversion

| **nim** | **msgpack** |
|--------------------------------|----------------|
| int8/16/32/64 | int8/16/32/64 |
| uint8/16/32/64 | uint8/16/32/64 |
| true/false/nil | true/false/nil |
| procedural type | ignored  |
| float32/64 | float32/64 |
| string | string8/16/32 |
| array/seq | array |
| set | array |
| range/subrange | int8/16/32/64 |
| enum | int8/16/32/64 |
| IntSet,Doubly/SinglyLinkedList | array |
| Doubly/SinglyLinkedRing | array |
| Queue,HashSet,OrderedSet | array |
| Table,TableRef | map |
| OrderedTable,OrderedTableRef | map |
| StringTableRef | map |
| CritBitTree | map |
| object/tuple | array/map |

object/tuple by default converted to msgpack array, however
you can tell the compiler to convert it to map by supplying --define:msgpack_obj_to_map

```shell
nim c --define:msgpack_obj_to_map yourfile.nim
```

##bin and ext format

this implementation provide function to encode/decode msgpack bin/ext format header, but for the body, you must write it yourself to the StringStream
	
* proc pack_bin*(s: Stream, len: int)
* proc pack_ext*(s: Stream, len: int, exttype: int8)
* proc unpack_bin*(s: Stream): int
* proc unpack_ext*(s: Stream): tuple[exttype:uint8, len: int]

```nimrod
import streams, msgpack

const exttype0 = 0

var s = newStringStream()
var body = "this is the body"

s.pack_ext(body.len, exttype0)
s.write(body)

#the same goes to bin format
s.pack_bin(body.len)
s.write(body)

s.setPosition(0)
#unpack_ext return tuple[exttype:uint8, len: int]
let (extype, extlen) = s.unpack_ext()
var extbody = s.readStr(extlen)

assert extbody == body

let binlen = s.unpack_bin()
var binbody = s.readStr(binlen)

assert binbody == body
```
enjoy it, happy nim-ing
