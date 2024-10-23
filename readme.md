# igc-filename-parser

## Port
- [igc-filename-parser](https://github.com/Turbo87/igc-filename-parser)

## Usage

```nim
from igc_filename_parser import parse

result = parse("78_65dv1qz1.igc");
```

```nim
{
  "callsign": "78",
  "date": "2016-05-13",
  "manufacturer": "LXNAV",
  "loggerId": "1QZ",
  "numFlight": 1
}
```
