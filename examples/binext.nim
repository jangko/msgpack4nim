import streams, ../msgpack4nim

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
