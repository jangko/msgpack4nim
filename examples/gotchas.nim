import ../msgpack4nim, streams, tables, sets, strtabs, ../msgpack4nim/msgpack4collection

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

echo "legs: ", $tom.legs
echo "kittens: ", $tom.kittens
echo "traits: ", $tom.traits