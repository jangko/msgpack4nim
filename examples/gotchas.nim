import std/[streams, tables, sets, strtabs, unittest]

import msgpack4nim
import msgpack4nim/msgpack4collection

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
unpack(buf, tom) #magically, it will unpack into a Cat

test "gochas":
  check tom.legs == 4
  check $tom.kittens == "{\"colt\", \"jilly\"}"
  check $tom.traits == "{color: black, speed: 120mph}"
