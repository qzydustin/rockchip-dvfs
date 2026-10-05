#!/usr/bin/env python3
"""Turn the ddr_timing node of a vendor dtb into a C header for px30_dmc_dbg.c (timing=1).

    extract-ddr-timing.py <vendor.dtb> > examples/<board>-ddr-timing.h

Reads the property names from px30_dmc_timing.h (the vendor's px30_dts_timing[] and
rk3328_dts_*_timing[] tables) and the values with fdtget, in the same order the vendor driver
copies them into the second shared page (of_get_px30_timings()).
"""
import re, subprocess, sys, pathlib

dtb = sys.argv[1]
hdr = (pathlib.Path(__file__).parent / "px30_dmc_timing.h").read_text()

def names(table):
    m = re.search(r"static const char \* const %s\[\] = \{(.*?)\};" % table, hdr, re.S)
    return re.findall(r'"([^"]+)"', m.group(1))

def value(name):
    out = subprocess.run(["fdtget", "-t", "u", dtb, "/ddr_timing", name], capture_output=True, text=True)
    if out.returncode:
        sys.exit("missing /ddr_timing/%s in %s" % (name, dtb))
    return int(out.stdout.split()[0])

def emit(cname, table):
    lst = names(table)
    body = ",\n\t".join("%u /* %s */" % (value(n), n) for n in lst)
    return "static const u32 %s[%d] = {\n\t%s\n};\n" % (cname, len(lst), body)

print("/* DDR timing from %s, /ddr_timing */" % pathlib.Path(dtb).name)
print(emit("stock_timing", "px30_dts_timing"))
print(emit("stock_ca", "rk3328_dts_ca_timing"))
print(emit("stock_cs0", "rk3328_dts_cs0_timing"))
print(emit("stock_cs1", "rk3328_dts_cs1_timing"))
