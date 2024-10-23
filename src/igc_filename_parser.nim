{.push raises: [].}

import std/tables
import std/times
import std/strutils
import std/strformat
import std/options
import std/json
import std/jsonutils
# import std/marshal
import pkg/results
import pkg/regex
import flight_recorder_manufacturers

const RE_SEEYOU = re2(r"^(\d)([1-9a-c])([1-9a-v])_([\da-z]{1,3})\.igc$", {regexCaseless})
const RE_STREPLA_PREFIX = re2(r"^([\da-z]{1,3})_(.*)$", {regexCaseless})
const RE_SHORT = re2(r"^(\d)([1-9a-c])([1-9a-v])([\da-z])([\da-z]{3})([\da-z]).*\.igc$",
    {regexCaseless})
const RE_LONG = re2(r"^(\d{4}-\d{2}-\d{2})(?:-([\da-z|A-Z]{3})-([\da-z|A-Z]{3,})-(\d{2})|_flight_(\d+))?.*\.igc$",
     {regexCaseless})
const RE_FULL_DATE = re2(r"^(\d{4}_\d{2}_\d{2})_\d{2}_\d{2}_\d{2}.*\.igc$", {regexCaseless})
const RE_SHORT_DATE = re2(r"^(19\d{2}|20\d{2})[\.-_]?(\d{2})[\.-_]?(\d{2}).*\.igc$",
     {regexCaseless})
const RE_IGC_DROID = re2(r"^igcdroid_(\d{4})_([a-z]{3})_(\d{2}).*\.igc$", {regexCaseless})

const CHARS = "0123456789abcdefghijklmnopqrstuvwxyz"

const MONTHS: Table[string, string] = {
    "jan": "01",
    "feb": "02",
    "mar": "03",
    "apr": "04",
    "may": "05",
    "jun": "06",
    "jul": "07",
    "aug": "08",
    "sep": "09",
    "oct": "10",
    "nov": "11",
    "dec": "12",
}.toTable


type IGCFilenameData* = object
  callsign*: Opt[string]
  date*: string
  manufacturer*: Opt[string]
  loggerId*: Opt[string]
  numFlight*: Opt[int]


proc charToNumber(chr: string): Opt[int] =
  let ch = chr.toLower
  let index = CHARS.find(ch)

  if index != -1:
    return Opt.some(index)
  else:
    return Opt.none(int)


proc charsToDate(y: string, m: string, d: string, maxYear: int): string =
  let yearDigit = charToNumber(y)
  if yearDigit.isNone: return ""

  let monthDigit = charToNumber(m)
  if monthDigit.isNone: return ""

  let dayDigit = charToNumber(d)
  if dayDigit.isNone: return ""

  var yearDiff = (maxYear mod 10) - yearDigit.get

  if yearDiff < 0:
    yearDiff += 10

  let year = maxYear - yearDiff
  let monthZeroCh = if monthDigit.get < 10: "0" else: ""
  let month = fmt"{monthZeroCh}{monthDigit.get}"
  let dayZeroCh = if dayDigit.get < 10: "0" else: ""
  let day = fmt"{dayZeroCh}{dayDigit.get}"
  return fmt"{year}-{month}-{day}"


proc parseSeeyou(filename: string, maxYear: int): Opt[IGCFilenameData] =
  var m: RegexMatch2
  let isMatch = match(filename, RE_SEEYOU, m)

  if not isMatch:
    return Opt.none(IGCFilenameData)

  let callsign = if filename[m.group(3)] != "": Opt.some(filename[m.group(
      3)]) else: Opt.none(string)
  let date = charsToDate(filename[m.group(0)], filename[m.group(1)], filename[
      m.group(2)], maxYear)
  let manufacturer = Opt.none(string)
  let loggerId = Opt.none(string)
  let numFlight = Opt.none(int)

  return Opt.some(IGCFilenameData(
    callsign: callsign,
    date: date,
    manufacturer: manufacturer,
    loggerId: loggerId,
    numFlight: numFlight,
  ))


proc parseShort(filename: string, maxYear: int): Opt[IGCFilenameData] =
  var m: RegexMatch2
  let isMatch = match(filename, RE_SHORT, m)

  if not isMatch:
    return Opt.none(IGCFilenameData)

  let callsign = Opt.none(string)
  let date = charsToDate(filename[m.group(0)], filename[m.group(1)], filename[
      m.group(2)], maxYear)
  let manufacturerId = filename[m.group(3)]
  let manufacturer = if manufacturerId != "": Opt.some(lookup(
      manufacturerId)) else: Opt.none(string)

  let logger = filename[m.group(4)]
  let loggerId = if logger != "": Opt.some(logger.toUpper) else: Opt.none(string)
  let numFlight = charToNumber(filename[m.group(5)])

  return Opt.some(IGCFilenameData(
    callsign: callsign,
    date: date,
    manufacturer: manufacturer,
    loggerId: loggerId,
    numFlight: numFlight,
  ))


proc parseLong(filename: string, maxYear: int): Opt[IGCFilenameData] =
  var m: RegexMatch2
  let isMatch = match(filename, RE_LONG, m)

  if not isMatch:
    return Opt.none(IGCFilenameData)

  let callsign = Opt.none(string)
  let date = filename[m.group(0)]

  let manufacturerId = filename[m.group(1)]
  let manufacturer = if manufacturerId != "": Opt.some(lookup(
      manufacturerId)) else: Opt.none(string)
  let logger = filename[m.group(2)]
  let loggerId = if logger != "": Opt.some(logger.toUpper) else: Opt.none(string)

  var numFlight: Opt[int] = Opt.none(int)
  if filename[m.group(3)] != "":
    let numFlightR = parseInt(filename[m.group(3)]).catch
    numFlight = if numFlightR.isOk: Opt.some(numFlightR.get) else: Opt.none(int)
  elif filename[m.group(4)] != "":
    let numFlightR = parseInt(filename[m.group(4)]).catch
    numFlight = if numFlightR.isOk: Opt.some(numFlightR.get) else: Opt.none(int)

  return Opt.some(IGCFilenameData(
    callsign: callsign,
    date: date,
    manufacturer: manufacturer,
    loggerId: loggerId,
    numFlight: numFlight,
  ))


proc parseStrepla(filename: string, maxYear: int): Opt[IGCFilenameData] =
  var m: RegexMatch2
  let isMatch = match(filename, RE_STREPLA_PREFIX, m)

  if not isMatch:
    return Opt.none(IGCFilenameData)

  let cs = filename[m.group(0)]
  let callsign = Opt.some(cs)
  var res = parseLong(filename[m.group(1)], maxYear) or parseShort(filename[
      m.group(1)], maxYear)

  if res.isSome:
    var tmp = res.get
    tmp.callsign = callsign
    res = Opt.some(tmp)

  return res


proc parseIGCDroid(filename: string, fullYear: int): Opt[IGCFilenameData] =
  var m: RegexMatch2
  let isMatch = match(filename, RE_IGC_DROID, m)

  if not isMatch:
    return Opt.none(IGCFilenameData)

  var month = MONTHS.getOrDefault(filename[m.group(1)], "")
  if month == "":
    return Opt.none(IGCFilenameData)

  let callsign = Opt.none(string)
  let date = fmt"{filename[m.group(0)]}-{month}-{filename[m.group(2)]}"
  let manufacturer = Opt.none(string)
  let loggerId = Opt.none(string)
  let numFlight = Opt.none(int)

  return Opt.some(IGCFilenameData(
    callsign: callsign,
    date: date,
    manufacturer: manufacturer,
    loggerId: loggerId,
    numFlight: numFlight,
  ))


proc parseFullDate(filename: string, fullYear: int): Opt[IGCFilenameData] =
  var m: RegexMatch2
  let isMatch = match(filename, RE_FULL_DATE, m)

  if not isMatch:
    return Opt.none(IGCFilenameData)

  let callsign = Opt.none(string)
  let date = filename[m.group(0)].replace("_", "-")
  let manufacturer = Opt.none(string)
  let loggerId = Opt.none(string)
  let numFlight = Opt.none(int)

  return Opt.some(IGCFilenameData(
    callsign: callsign,
    date: date,
    manufacturer: manufacturer,
    loggerId: loggerId,
    numFlight: numFlight,
  ))


proc parseShortDate(filename: string, fullYear: int): Opt[IGCFilenameData] =
  var m: RegexMatch2
  let isMatch = match(filename, RE_SHORT_DATE, m)

  if not isMatch:
    return Opt.none(IGCFilenameData)

  let callsign = Opt.none(string)
  let date = fmt"{filename[m.group(0)]}-{filename[m.group(1)]}-{filename[m.group(2)]}"
  let manufacturer = Opt.none(string)
  let loggerId = Opt.none(string)
  let numFlight = Opt.none(int)

  return Opt.some(IGCFilenameData(
    callsign: callsign,
    date: date,
    manufacturer: manufacturer,
    loggerId: loggerId,
    numFlight: numFlight,
  ))


type Parser = proc (f: string, y: int): Opt[IGCFilenameData]{.raises: [],
    noSideEffect, gcsafe, nimcall.}
type ParsersArray = array[7, Parser]

let PARSERS: ParsersArray = [
  parseShort,
  parseLong,
  parseSeeyou,
  parseStrepla,
  parseShortDate,
  parseFullDate,
  parseIGCDroid,
]


proc parse*(filename: string, maxYear: int = -1): Opt[
    IGCFilenameData] =
  var my: int
  if maxYear == -1:
    my = now().year
  else:
    my = maxYear

  for parser in PARSERS:
    let res = parser(filename, my)
    if res.isSome:
      return res

  return Opt.none(IGCFilenameData)

proc serialize(o: Opt[IGCFilenameData]): JsonNode =
  # result = pretty( %* o)
  if o.isNone:
    result = %*{}
  else:
    result = newJObject()

    let j = o.get
    result = %* {
      # "callsign": if j.callsign.isNone: j.callsign.get else:
      "callsign": %(Opt.none(string))
      # "date": if j.date.isSome: j.date.get esle: newJNull(),
        # "manufacturer": if j.manufacturers.isSome: j.manufacturers.get else: newJNull(),
        # "loggerId": if j.loggerId.isSome: j.loggerId.get else: newJNull(),
        # "numFlight": if j.numFlight.isSome: j.numFlight.get else: newJNull()
      }


when isMainModule:
  block:
    # echo "charToNumber z"
    let res = charToNumber("z").get
    assert res == 35

  block:
    # echo "charToNumber 0"
    let res = charToNumber("0").get
    assert res == 0

  block:
    # echo "charToNumber ž"
    let res = charToNumber("ž")
    assert res.isNone == true

  block:
    # echo "parseFullDate"
    let res = parseFullDate("2019-08-19-XSD-GPB-01.igc", 2024)
  block:
    # echo "parseShort"
    # let res = parseShort("654VJJM1.igc", 2024)
    # let res = parseShort("620130107.igc", 1900)
    # let res = parseShort("2013-01-07.igc", 1900)
    # let res = parseShort("2013-01-07.igc", 1900)
    let res = parseShort("4aaga071.igc", 2024)
    assert res.isSome == true
  block:
    # echo "2022-12-16-XSD-UB2F17-02.igc"
    let res = parseLong("2022-12-16-XSD-UB2F17-02.igc", 1900)
    assert res.isSome == true
  block:
    # echo "2013-01-08_FLIGHT_1.igc"
    # let res = parseLong("2013-01-08_FLIGHT_1.igc", 1900)
    let res = parse("2013-01-08_FLIGHT_1.igc")
    assert res.isSome == true
  block:
    let res = parse("-flarm-44bg4bi1.igc")
    assert res.isNone == true
  block:
    let res = parse("78_65dv1qz1.igc");
    # echo $$res
    echo res.serialize
    assert res.isSome == true
    # echo res.get.toJson

