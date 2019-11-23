import streams, msgpack4nim

type MsgType* = enum
  MSG_FOO,
  MSG_BAR

type Foo* = object
  name: string

type Bar* = object
  price: int

type FooBarMsg* = object
  case msgType*: MsgType
  of MSG_FOO:
    foo*: Foo
  of MSG_BAR:
    bar*: Bar

proc mm(): FooBarMsg =
  result = FooBarMsg(msgType: MSG_BAR, bar: Bar(price: 100))
  
when isMainModule:
  var fooOriginal = Foo(name: "Baz")
  var barOriginal = Bar(price: 11)
  var outboundMsgFoo = FooBarMsg(
  msgType: MSG_FOO,
  foo: fooOriginal
  )
  var outboundMsgBar = FooBarMsg(
  msgType: MSG_BAR,
  bar: barOriginal
  )

  var sFoo = MsgStream.init(encodingMode = MSGPACK_OBJ_TO_MAP)
  sFoo.pack(outboundMsgFoo)

  var sBar = MsgStream.init()
  sBar.pack(outboundMsgBar)

  debugEcho sFoo.data.stringify()
  debugEcho sBar.data.stringify()
  
  var incomingFoo: FooBarMsg
  
  incomingFoo = mm()
  debugEcho incomingFoo
 #var sFooReception = MsgStream.init(sFoo.data, encodingMode = MSGPACK_OBJ_TO_MAP)
 #try:
 #  sFooReception.unpack(incomingFoo)
 #except:
 #  echo "unpack error for foo"
 #
 #var incomingBar: FooBarMsg
 #var sBarReception = MsgStream.init(sBar.data)
 # #try:
 #sBarReception.unpack(incomingBar)
 # #except:
 #  #echo "unpack error for bar"