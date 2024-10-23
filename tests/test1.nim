
import unittest
import igc_filename_parser
import std/os
import pkg/results

proc data(date: string, manufacturer: string = "", loggerId: string = "",
    numFlight: int = -1, callsign: string = ""): Opt[IGCFilenameData] =
  let m = if manufacturer != "": Opt.some(manufacturer) else: Opt.none(string)
  let l = if loggerId != "": Opt.some(loggerId) else: Opt.none(string)
  let n = if numFlight != -1: Opt.some(numFlight) else: Opt.none(int)
  let c = if callsign != "": Opt.some(callsign) else: Opt.none(string)

  var val = IGCFilenameData(date: date, manufacturer: m,
      loggerId: l, numFlight: n, callsign: c)
  return Opt.some(val)

const tests = @[
  ("", Opt.none(IGCFilenameData)),
  ("xaaga071.igc", Opt.none(IGCFilenameData)),
  ("4aaga071.igc", data("2014-10-10", "Flarm", "A07", 1)),
  ("4aaga07x.igc", data("2014-10-10", "Flarm", "A07", 33)),
  ("811ga071.igc", data("2008-01-01", "Flarm", "A07", 1)),
  ("711ga071.igc", data("2017-01-01", "Flarm", "A07", 1)),
  ("649V6B31.igc", data("2016-04-09", "LXNAV", "6B3", 1)),
  ("649v6ea2.igc", data("2016-04-09", "LXNAV", "6EA", 2)),
  ("654G6NG1.IGC", data("2016-05-04", "Flarm", "6NG", 1)),
  ("654VJJM1.igc", data("2016-05-04", "LXNAV", "JJM", 1)),
  ("67LG6NG1.IGC", data("2016-07-21", "Flarm", "6NG", 1)),
  ("67og6ng1.igc", data("2016-07-24", "Flarm", "6NG", 1)),
  ("76av3hp2.igc", data("2017-06-10", "LXNAV", "3HP", 2)),
  ("77dv3hp1.igc", data("2017-07-13", "LXNAV", "3HP", 1)),
  ("7cdv3hp1.igc", data("2017-12-13", "LXNAV", "3HP", 1)),
  ("78_65dv1qz1.igc", data("2016-05-13", "LXNAV", "1QZ", 1, "78")),
  ("78_65dv1qz1-bla.igc", data("2016-05-13", "LXNAV", "1QZ", 1, "78")),
  ("77U_TH.igc", data("2017-07-30", "", "", -1, "TH")),
  (
      "2013-08-12-fla-6ng-01334499802.igc",
      data("2013-08-12", "Flarm", "6NG", 1),
  ),
  ("2013-10-19-xcs-aaa-05_1.igc", data("2013-10-19", "XCSoar", "AAA", 5)),
  ("2015-01-21-xxx-asc-47.igc", data("2015-01-21", "XXX", "ASC", 47)),
  (
      "TH_2015-01-21-xxx-asc-47.igc",
      data("2015-01-21", "XXX", "ASC", 47, "TH"),
  ),
  ("05l_hs__1_.igc", Opt.none(IGCFilenameData)),
  ("110911sw-welle_seyne.igc", Opt.none(IGCFilenameData)),
  ("ykep_08dec12.igc", Opt.none(IGCFilenameData)),
  ("ybla_13nov12c.igc", Opt.none(IGCFilenameData)),
  ("ww_30102016.igc", Opt.none(IGCFilenameData)),
  ("2013-01-07.igc", data("2013-01-07")),
  ("20130107.igc", data("2013-01-07")),
  ("2013.01.07_1000km.igc", data("2013-01-07")),
  ("2009_05_27_lamotte_kfnw_95rf1091.igc", data("2009-05-27")),
  ("2012_10_10_12_10_17.igc", data("2012-10-10")),
  ("igcdroid_2016_jan_30_13-14.igc", data("2016-01-30")),
  ("2013-01-08_flight_1.igc", data("2013-01-08", "", "", 1)),
  ("2019-08-19-XSD-GPB-01.igc", data("2019-08-19", "leGPSBip", "GPB", 1)),
  ("2022-10-28-XSD-MRT-02.igc", data("2022-10-28", "leGPSBip", "MRT", 2)),
  ("2022-12-16-XSD-UBP-02.igc", data("2022-12-16", "leGPSBip", "UBP", 2)),
  (
      "2022-12-16-XSD-UB2F17-02.igc",
      data("2022-12-16", "leGPSBip", "UB2F17", 2),
  ),
  (
      "2022-07-11_13.02_Reinhardsmunster_S.igc",
      data("2022-07-11", "", "", -1),
  ),
  ("2022-10-28_16.38_Orensberg.igc", data("2022-10-28", "", "", -1)),
]

test "run tests":
  for (filename, data) in tests:
    let res = parse(filename, 2017)
    # echo "------------------------------"
    # echo filename
    # echo res
    # echo data
    # echo res.isOk == data.isOk
    # echo "------------------------------"
    assert res.isOk == data.isOk
    assert res == data
    check res.isOk == data.isOk

test "does not throw":
  let testFile = "tests" / "fixtures" / "igc-filenames.txt"
  let file = open(testFile, fmRead)
  for f in file.lines:
    discard parse(f)



