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

enjoy it, happy nim-ing