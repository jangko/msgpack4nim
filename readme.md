# msgpack4nim

[MessagePack](http://msgpack.org/) implementation written in pure nim

### why another implementation?
I am fully aware of [another](https://github.com/akiradeveloper/msgpack-nim) msgpack implementation written in nim.
But I want something easier to use. Another motivation come from the nim language itself.
The current version of nim compiler offer many improvements, including 'generics ' specialization.
I found out nim compiler is smart enough to make serialization/deserialization to/from msgpack easy and convenient.

**requirement:** nim ver 0.11.2 or later

[![Build Status][badge-msgpack4nim-travisci]][msgpack4nim-travisci]

## Example

```nimrod
import msgpack4nim, streams

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
by defining your own handler pack_type/unpack_type
```nimrod
type
  #not really complex, just for example
  mycomplexobject = object
    a: someSimpleType
    b: someSimpleType

#help the compiler to decide
proc pack_type*(s: Stream, x: mycomplexobject) =
  s.pack(x.a) # let the compiler decide
  s.pack(x.b) # let the compiler decide

#help the compiler to decide
proc unpack_type*(s: Stream, x: var complexobject) =
  s.unpack(x.a)
  s.unpack(x.b)

var s: newStringStream()
var x: mycomplexobject

s.pack(x) #pack as usual

s.setPosition(0)
s.unpack(x) #unpack as usual
```

## Data Conversion

| **nim** | **msgpack** | **JsonNode** |
|--------------------------------|----------------|----------------|
| int8/16/32/64 | int8/16/32/64 | JInt |
| uint8/16/32/64 | uint8/16/32/64 | JInt |
| true/false | true/false | JBool |
| nil | nil | JNull |
| procedural type | ignored | n/a |
| cstring | ignored | n/a |
| pointer | ignored | n/a |
| ptr | [see ref-types](#ref-types) | n/a |
| ref | [see ref-types](#ref-types) | n/a |
| circular ref | [see ref-types](#ref-types) | n/a |
| distinct types | converted to base type | applicable base type |
| float32/64 | float32/64 | JFloat |
| string | string8/16/32 | JString |
| array/seq | array | JArray |
| set | array | JArray |
| range/subrange | int8/16/32/64 | JInt |
| enum | int8/16/32/64 | JInt |
| IntSet,Doubly/SinglyLinkedList | array | JArray |
| Doubly/SinglyLinkedRing | array | JArray |
| Queue,HashSet,OrderedSet | array | JArray |
| Table,TableRef | map | JObject |
| OrderedTable,OrderedTableRef | map | JObject |
| StringTableRef | map | JObject |
| CritBitTree[T] | map | JObject |
| CritBitTree[void] | array | JArray |
| object/tuple | array/map | JObject |

## object and tuple

object and tuple by default converted to msgpack array, however
you can tell the compiler to convert it to map by supplying --define:msgpack_obj_to_map

```shell
nim c --define:msgpack_obj_to_map yourfile.nim
```

or --define:msgpack_obj_to_stream to convert object/tuple fields *value* into stream of msgpack objects
```shell
nim c --define:msgpack_obj_to_stream yourfile.nim
```

What this means? It means by default, each object/tuple will be converted to one `msgpack array` contains
field(s) value only without their field(s) name.

If you specify that the object/tuple will be converted to `msgpack map`, then each object/tuple will be
converted to one `msgpack map` contains key-value pairs. The key will be field name, and the value will be field value.

If you specify that the object/tuple will be converted to msgpack stream, then each object/tuple will be converted
into one or more msgpack's type for each object's field and then the resulted stream will be concatenated
to the msgpack stream buffer.

Which one should I use?

Usually, other msgpack libraries out there convert object/tuple/record/struct or whatever structured data supported by
the language into `msgpack array`, but always make sure to consult the documentation first.
If both of the serializer and deserializer agreed to one convention, then usually there will be no problem.
No matter which library/language you use, you can exchange msgpack data among them.

#### **ref-types:**
*ref something* :

* if ref value is nil, it will be packed into msgpack nil, and when unpacked, you will get nil too
* if ref value not nil, it will be dereferenced e.g. pack(val[]) or unpack(val[])
* ref subject to some restriction. see **restriction** below
* ptr will be treated like ref during pack
* unpacking ptr will invoke alloc, so you must dealloc it

*circular reference*:
altough detecting circular reference is not too difficult(using set of pointers),
the current implementation does not provide circular reference detection.
If you pack something contains circular reference, you know something bad will happened

**Restriction**:
For objects their type is **not** serialized.
This means essentially that it does not work if the object has some other runtime type than its compiletime type:

```nimrod
import streams, msgpack4nim

type
  TA = object of RootObj
  TB = object of TA
    f: int

var
  a: ref TA
  b: ref TB

new(b)
a = b

echo stringify(pack(a))
#produces "[ ]" or "{ }"
#not "[ 0 ]" or '{ "f" : 0 }'
```
#### **limitation:**

these types will be ignored:

* procedural type
* cstring(it is not safe to assume it always terminated by null)
* pointer

these types cannot be automatically pack/unpacked:

* *void* (will cause compile time error)

however, you can provide your own handler for cstring and pointer

**Gotchas:**
because data conversion did not preserve original data types(only partial preservation),
the following code is perfectly valid and will raise no exception

```nimrod
import msgpack4nim, streams, tables, sets, strtabs

type
  Horse = object
    legs: int
    foals: seq[string]
    attr: Table[string, string]

  Cat = object
    legs: uint8
    kittens: HashSet[string]
    traits: StringTableRef

proc initHorse(): Horse =
  result.legs = 4
  result.foals = @["jilly", "colt"]
  result.attr = initTable[string, string]()
  result.attr["color"] = "black"
  result.attr["speed"] = "120mph"

var stallion = initHorse()
var tom: Cat

var buf = pack(stallion) #pack a Horse here
unpack(buf, tom)
#abracadabra, it will unpack into a Cat

echo "legs: ", $tom.legs
echo "kittens: ", $tom.kittens
echo "traits: ", $tom.traits
```

another gotcha:

```nimrod
  type
    KAB = object of RootObj
      aaa: int
      bbb: int

    KCD = object of KAB
      ccc: int
      ddd: int

    KEF = object of KCD
      eee: int
      fff: int

  var kk = KEF()
  echo stringify(pack(kk))
  # will produce "{ "eee" : 0, "fff" : 0, "ccc" : 0, "ddd" : 0, "aaa" : 0, "bbb" : 0 }"
  # not "{ "aaa" : 0, "bbb" : 0, "ccc" : 0, "ddd" : 0, "eee" : 0, "fff" : 0 }"
```

## bin and ext format

this implementation provide function to encode/decode msgpack bin/ext format header,
but for the body, you must write it yourself or read it yourself to/from the StringStream

* proc pack_bin*(s: Stream, len: int)
* proc pack_ext*(s: Stream, len: int, exttype: int8)
* proc unpack_bin*(s: Stream): int
* proc unpack_ext*(s: Stream): tuple[exttype:uint8, len: int]

```nimrod
import streams, msgpack4nim

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

## stringify

you can convert msgpack data to readable string using stringify function

```nimrod
  type
    Horse = object
      legs: int
      speed: int
      color: string
      name: string

  var cc = Horse(legs:4, speed:150, color:"black", name:"stallion")
  var zz = pack(cc)
  echo stringify(zz)
```

the result will be:

```json
default:
[ 4, 150, "black", "stallion" ]

msgpack_obj_to_map defined:
{ "legs" : 4, "speed" : 150, "color" : "black", "name" : "stallion" }

msgpack_obj_to_stream defined:
4 150 "black" "stallion"
```

## toAny
**toAny** takes a string of msgpack data or a stream, then it will produce **msgAny**
which you can interrogate of it's  type and value during runtime by accessing it's member **msgType**

**toAny** recognize all valid msgpack message and translate it into a group of types:

    msgMap, msgArray, msgString, msgBool,
    msgBin, msgExt, msgFloat32, msgFloat64,
    msgInt, msgUint, msgNull

for example, **msg** is a *msgpack* data with content [1, "hello", {"a": "b"}], you can interrogate it like this:

```nimrod
var a = msg.toAny()
assert a.kind == msgArray
assert a.arrayVal[0].kind == msgInt
assert a.arrayVal[0].intVal == 1
assert a.arrayVal[1].kind == msgString
assert a.arrayVal[1].stringVal == "hello"
assert a.arrayVal[2].kind == msgMap
var c = a[2]
assert c[anyString("a")] == anyString("b")
```

since version 0.2.1, toAny was put into separate module `msgpack2any`,
it has functionality similar with json, with support of msgpack bin and ext natively

## JSON

Start version 0.2.0, msgpack4nim receive additional family member, `msgpack2json` module.
It consists of `toJsonNode` and `fromJsonNode` to interact with stdlib's json module.

## Implementation specific

> If an object can be represented in multiple possible output formats,
> serializers SHOULD use the format which represents the data in the smallest number of bytes.

According to the spec, the serializer should use smallest number of bytes, and this behavior
is implemented in msgpack4nim. Therefore, some valid encoding would never produced by msgpack4nim.

For example: although 0xcdff00 and 0xceff000000 encoding is valid according to the spec which is decoded into positive integer 255,
msgpack4nim never produce it, because the internal algorithm will select the smallest number of bytes needed, which is 0xccff.

However, if msgpack4nim received encoded streams from other msgpack library contains those longer than needed sequence, as long as
it conforms to the spec, msgpack4nim will happily decoded it and convert it to the destination storage(variable) type.

Other msgpack library who consume msgpack4nim stream, will also decode it properly, although they might not produce smallest number
of bytes required, such situation is common in dynamically typed language msgpack library.

enjoy it, happy nim-ing

[msgpack4nim-travisci]: https://travis-ci.org/jangko/msgpack4nim
[badge-msgpack4nim-travisci]: https://travis-ci.org/jangko/msgpack4nim.svg?branch=master
