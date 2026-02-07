import std/[os, strutils, times, streams, json]
import msgpack4nim
import msgpack4nim/msgpack2any
import msgpack4nim/msgpack2json

type
  Sample = object
    id: int
    name: string
    values: seq[int]
    flags: array[4, bool]
    ratio: float64
    meta: tuple[a: int, b: string]

  LargeChild = object
    a: int
    b: int
    c: int
    d: int
    e: int
    f: int
    g: int
    h: int
    s1: string
    s2: string
    s3: string
    s4: string

  LargeSample = object
    id: int
    name: string
    description: string
    tags: seq[string]
    values: seq[int]
    metrics: array[16, float64]
    flags: array[8, bool]
    extra: array[8, string]
    child: LargeChild
    children: seq[LargeChild]
    meta: tuple[a: int, b: string]

proc buildSample(): Sample =
  result.id = 42
  result.name = "alpha"
  result.values = @[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  result.flags = [true, false, true, false]
  result.ratio = 3.1415926
  result.meta = (a: 7, b: "beta")

proc makeChild(seed: int): LargeChild =
  result.a = seed
  result.b = seed + 1
  result.c = seed + 2
  result.d = seed + 3
  result.e = seed + 4
  result.f = seed + 5
  result.g = seed + 6
  result.h = seed + 7
  result.s1 = "c" & $seed
  result.s2 = "d" & $seed
  result.s3 = "e" & $seed
  result.s4 = "f" & $seed

proc buildLargeSample(): LargeSample =
  result.id = 9001
  result.name = "omega"
  result.description = "large-sample"
  result.tags = @["red", "green", "blue", "amber", "violet", "cyan", "black", "white"]
  result.values = newSeq[int](20)
  for i in 0..<result.values.len:
    result.values[i] = i * 3
  for i in 0..<result.metrics.len:
    result.metrics[i] = float64(i) * 0.5
  for i in 0..<result.flags.len:
    result.flags[i] = (i mod 2 == 0)
  for i in 0..<result.extra.len:
    result.extra[i] = "x" & $i
  result.child = makeChild(10)
  result.children = newSeq[LargeChild](4)
  for i in 0..<result.children.len:
    result.children[i] = makeChild(100 + i)
  result.meta = (a: 99, b: "zeta")

template timeIt(label: string, iters: int, body: untyped) =
  let t0 = cpuTime()
  for i in 0..<iters:
    body
  let t1 = cpuTime()
  let elapsed = t1 - t0
  let perOp = (elapsed * 1_000_000_000.0) / float(iters)
  echo label, ": ", elapsed.formatFloat(ffDecimal, 3), "s (", perOp.formatFloat(ffDecimal, 1), " ns/op)"

proc main() =
  let iters = if paramCount() > 0: parseInt(paramStr(1)) else: 100000
  let sample = buildSample()
  let dataSmall = pack(sample)
  let large = buildLargeSample()
  let dataLarge = pack(large)

  when defined(msgpack_obj_to_map):
    echo "encoding: map"
  elif defined(msgpack_obj_to_stream):
    echo "encoding: stream"
  else:
    echo "encoding: array"

  var sSmall = MsgStream.init(dataSmall)
  var sLarge = MsgStream.init(dataLarge)
  var decodedSmall: Sample
  var decodedLarge: LargeSample
  var anyVal: MsgAny
  var jsonVal: JsonNode
  var sink = 0

  timeIt("unpack sample", iters):
    sSmall.setPosition(0)
    sSmall.unpack(decodedSmall)
    sink = sink xor decodedSmall.id

  timeIt("skip sample", iters):
    sSmall.setPosition(0)
    sSmall.skip_msg()
    sink = sink xor int(sSmall.getPosition())

  timeIt("unpack large", iters):
    sLarge.setPosition(0)
    sLarge.unpack(decodedLarge)
    sink = sink xor decodedLarge.id

  timeIt("skip large", iters):
    sLarge.setPosition(0)
    sLarge.skip_msg()
    sink = sink xor int(sLarge.getPosition())

  timeIt("toAny large", iters):
    sLarge.setPosition(0)
    anyVal = sLarge.toAny()
    sink = sink xor anyVal.len

  timeIt("toJson large", iters):
    sLarge.setPosition(0)
    jsonVal = sLarge.toJsonNode()
    case jsonVal.kind
    of JObject, JArray:
      sink = sink xor len(jsonVal)
    else:
      sink = sink xor 1

  if sink == 123456789:
    echo "ignore: ", sink

when isMainModule:
  main()
