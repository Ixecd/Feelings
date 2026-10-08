#!/usr/bin/env python3
"""KiCad-10 .kicad_sch generator for tVNS T1 front-end. Label-based connectivity.
Handles multi-unit symbols (74HC04/08/00, LM393) by placing each unit separately.
Validate: kicad-cli sch export netlist --format kicadsexpr -o t1.net t1_frontend.kicad_sch
"""
import os, re

SYMS = "/Applications/KiCad/KiCad.app/Contents/SharedSupport/symbols"
LIBFILE = {"Device":"Device.kicad_sym","Transistor_FET":"Transistor_FET.kicad_sym",
           "Transistor_BJT":"Transistor_BJT.kicad_sym","Amplifier_Operational":"Amplifier_Operational.kicad_sym",
           "Comparator":"Comparator.kicad_sym","Reference_Voltage":"Reference_Voltage.kicad_sym",
           "74xx":"74xx.kicad_sym","Connector_Generic":"Connector_Generic.kicad_sym"}

def _extract(lib, name):
    txt = open(os.path.join(SYMS, LIBFILE[lib]), encoding="utf-8").read()
    i = txt.find('(symbol "%s"' % name)
    if i < 0: raise SystemExit("not found %s:%s" % (lib, name))
    d = 0
    for j in range(i, len(txt)):
        if txt[j] == '(': d += 1
        elif txt[j] == ')':
            d -= 1
            if d == 0: return txt[i:j+1]

def _resolve(lib, name, d=0):
    blk = _extract(lib, name); m = re.search(r'\(extends "([^"]+)"\)', blk)
    if m and d < 6: return _resolve(lib, m.group(1), d+1)
    return blk, name

def lib_block(lib, name):
    blk, base = _resolve(lib, name)
    blk = re.sub(r'\(symbol "%s"' % re.escape(base), '(symbol "%s:%s"' % (lib, name), blk, count=1)
    blk = re.sub(r'\(symbol "%s_(\d+_\d+)"' % re.escape(base), lambda m: '(symbol "%s_%s"' % (name, m.group(1)), blk)
    return blk

def _subs(blk, base):
    out = []
    for m in re.finditer(r'\(symbol "%s_(\d+)_(\d+)"' % re.escape(base), blk):
        s = m.start(); d = 0
        for j in range(s, len(blk)):
            if blk[j] == '(': d += 1
            elif blk[j] == ')':
                d -= 1
                if d == 0: out.append((int(m.group(1)), blk[s:j+1])); break
    return out

def pins_units(lib, name):
    blk, base = _resolve(lib, name)
    common, units = {}, {}
    for u, sub in _subs(blk, base):
        for part in re.split(r'\(pin ', sub)[1:]:
            num = re.search(r'\(number\s+"([^"]+)"', part); at = re.search(r'\(at\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\)', part)
            if not (num and at): continue
            dst = common if u == 0 else units.setdefault(u, {})
            dst[num.group(1)] = (float(at.group(1)), float(at.group(2)))
    if not units: units = {1: common}; common = {}
    return common, units

def U_(n): return "00000000-0000-0000-0000-%012d" % n

def place(n, ref, lib, name, val, unit, x, y):
    return f'''\t(symbol
\t\t(lib_id "{lib}:{name}")
\t\t(at {x} {y} 0)
\t\t(unit {unit})
\t\t(exclude_from_sim no) (in_bom yes) (on_board yes) (dnp no)
\t\t(uuid "{U_(n)}")
\t\t(property "Reference" "{ref}" (at {x} {y-2.5} 0) (effects (font (size 1.27 1.27)) (hide yes)))
\t\t(property "Value" "{val}" (at {x} {y+2.5} 0) (effects (font (size 1.27 1.27)) (hide yes)))
\t\t(property "Footprint" "" (at {x} {y} 0) (effects (font (size 1.27 1.27)) (hide yes)))
\t\t(property "Datasheet" "~" (at {x} {y} 0) (effects (font (size 1.27 1.27)) (hide yes)))
\t\t(instances (project "feelings" (path "/{U_(1)}" (reference "{ref}") (unit {unit}))))
\t)'''

_L = [0]
def label(net, x, y):
    _L[0] += 1
    return f'''\t(label "{net}"
\t\t(at {x} {y} 0)
\t\t(effects (font (size 1.0 1.0)) (justify left bottom))
\t\t(uuid "{U_(700000+_L[0])}")
\t)'''

# ===== design: (ref, lib, sym, value, [(unit,x,y), ...]) =====
C = lambda *a: list(a)
COMPS = [
 ("Q1","Transistor_FET","BS250","BS250",C((1,60,40))),("Q2","Transistor_FET","BS250","BS250",C((1,60,70))),
 ("Q3","Transistor_FET","2N7000","2N7000",C((1,95,40))),("Q4","Transistor_FET","2N7000","2N7000",C((1,95,70))),
 ("Q5","Transistor_BJT","2N3904","2N3904",C((1,35,40))),("Q6","Transistor_BJT","2N3904","2N3904",C((1,35,70))),
 ("R1","Device","R","22k",C((1,75,20))),("R2","Device","R","22k",C((1,75,95))),
 ("D1","Device","D_Zener","12V",C((1,75,30))),("D2","Device","D_Zener","12V",C((1,75,85))),
 ("R3","Device","R","4.7k",C((1,25,40))),("R4","Device","R","4.7k",C((1,25,70))),
 ("R5","Device","R","100k",C((1,35,20))),("R6","Device","R","100k",C((1,35,95))),
 ("U3","Amplifier_Operational","MCP6001R","OPA171",C((1,60,130))),
 ("Q7","Transistor_FET","2N7000","2N7000",C((1,95,130))),("Q8","Transistor_BJT","2N3904","2N3904",C((1,35,130))),
 ("Q9","Transistor_FET","2N7002","2N7002",C((1,120,115))),
 ("R7","Device","R","1k",C((1,75,115))),("R8","Device","R","100k",C((1,110,140))),
 ("R9","Device","R","100R",C((1,95,150))),("R10","Device","R","4.7k",C((1,135,105))),
 ("R11","Device","R","10k",C((1,25,130))),("R12","Device","R","100k",C((1,25,145))),
 ("C1","Device","C","0.47n",C((1,50,145))),
 ("RV1","Device","R_Potentiometer","1k",C((1,30,175))),
 ("R13","Device","R","39k",C((1,45,175))),("R14","Device","R","10k",C((1,55,175))),("R15","Device","R","10k",C((1,65,175))),
 ("C2","Device","C","3.3u",C((1,130,40))),("D3","Device","D_Zener","36V",C((1,145,30))),("D4","Device","D_Zener","36V",C((1,145,50))),
 # logic (multi-unit)
 ("U1","74xx","74HC04","SN74HC04",None),               # 6 units, placed below
 ("U2","74xx","74LS08","SN74HC08",None),               # 4 units
 # safety
 ("U4","Comparator","LM393","LM393",None),             # 2 units
 ("U5","74xx","74HC00","SN74HC00",None),               # 4 units
 ("U6","74xx","74LS08","SN74HC08",None),               # 4 units
 ("U7","Reference_Voltage","TL431LP","TL431",C((1,270,300))),
 ("R16","Device","R","10k",C((1,250,250))),("R17","Device","R","39k",C((1,250,320))),
 ("R18","Device","R","1k",C((1,265,320))),("R19","Device","R","10k",C((1,285,300))),("R20","Device","R","10k",C((1,250,340))),
 ("J1","Connector_Generic","Conn_01x08","CTRL",C((1,360,180))),("J2","Connector_Generic","Conn_01x02","ELECTRODE",C((1,360,300))),
 ("C3","Device","C","100n",C((1,185,60))),("C4","Device","C","100n",C((1,185,105))),
 ("C5","Device","C","100n",C((1,320,60))),("C6","Device","C","100n",C((1,320,105))),
 ("C7","Device","C","100n",C((1,185,150))),("C8","Device","C","100n",C((1,185,180))),
]
# unit placements for the multi-unit ICs: ref -> [(unit,x,y),...]
UNITS = {
 "U1": [(1,200,40),(2,200,70),(3,200,100),(4,235,40),(5,235,70),(6,235,100)],
 "U2": [(1,200,160),(2,230,160),(3,200,190),(4,230,190)],
 "U4": [(1,470,150),(2,470,200)],
 "U5": [(1,270,40),(2,300,40),(3,270,70),(4,300,70)],
 "U6": [(1,270,160),(2,300,160),(3,270,190),(4,300,190)],
}
URES = {}
for _c in COMPS:
    URES[_c[0]] = _c[4] if _c[4] is not None else list(UNITS[_c[0]])

NETS = {
 "VS":   [("Q1","3"),("Q2","3"),("R1","1"),("R2","1"),("D1","2"),("D2","2"),("J1","1")],
 "GND":  [("Q5","1"),("Q6","1"),("R5","2"),("R6","2"),("U3","2"),("R9","2"),("R8","2"),
          ("Q8","1"),("R12","2"),("C1","2"),("RV1","3"),("R14","2"),
          ("U1","7"),("U2","7"),("U1","9"),("U1","11"),("U1","13"),
          ("U5","7"),("U6","7"),("U5","9"),("U5","10"),("U5","12"),("U5","13"),
          ("U6","4"),("U6","5"),("U6","9"),("U6","10"),("U6","12"),("U6","13"),
          ("U4","4"),("U4","5"),("U4","6"),("U7","2"),("R18","2"),
          ("J1","4"),("C3","2"),("C4","2"),("C5","2"),("C6","2"),("C7","2"),("C8","2")],
 "+12V": [("U3","5"),("J1","2"),("C8","1")],
 "+5V":  [("J1","3"),("U1","14"),("U2","14"),("U5","14"),("U6","14"),("U4","8"),
          ("R16","1"),("R19","1"),("R20","1"),("RV1","1"),
          ("C3","1"),("C4","1"),("C5","1"),("C6","1"),("C7","1")],
 "VDDA": [("R10","1")],
 "A1":   [("U2","8"),("Q4","2"),("R3","1")],
 "A2":   [("U2","11"),("Q3","2"),("R4","1")],
 "G1":   [("Q1","2"),("R1","2"),("D1","1"),("Q5","3")],
 "G2":   [("Q2","2"),("R2","2"),("D2","1"),("Q6","3")],
 "MID1": [("Q1","1"),("Q3","3"),("C2","1")],
 "MID2": [("Q2","1"),("Q4","3"),("D3","2"),("D4","2"),("J2","2")],
 "B":    [("Q3","1"),("Q4","1"),("Q7","3")],
 "S":    [("Q7","1"),("R9","1"),("U3","4"),("Q9","2"),("U4","3")],
 "QG":   [("Q7","2"),("R7","2"),("R8","1")],
 "OUT":  [("U3","1"),("R7","1")],
 "INP":  [("U3","3"),("Q8","3"),("R15","2"),("C1","1")],
 "LH1B": [("R3","2"),("Q5","2"),("R5","1")],
 "LH2B": [("R4","2"),("Q6","2"),("R6","1")],
 "ENB":  [("R11","1"),("Q9","1"),("U1","6")],
 "QDB":  [("Q8","2"),("R11","2"),("R12","1")],
 "VN":   [("RV1","2"),("R13","1")],
 "VN2":  [("R13","2"),("R14","1"),("R15","1")],
 "EL1":  [("C2","2"),("D3","1"),("D4","1"),("J2","1")],
 "AWD":  [("R10","2"),("Q9","3")],
 "IN1":  [("J1","5"),("U1","1"),("U2","2")],
 "IN2":  [("J1","6"),("U1","3"),("U2","5")],
 "IN1B": [("U1","2"),("U2","13")],
 "IN2B": [("U1","4"),("U2","10")],
 "N1":   [("U2","3"),("U2","9")],
 "N2":   [("U2","6"),("U2","12")],
 "EN_MCU":  [("J1","7"),("U6","1")],
 "EN_SAFE": [("U5","3"),("U5","4"),("U6","2")],
 "EN_OUT":  [("U6","3"),("U1","5"),("U2","1"),("U2","4")],
 "TRIP_CMP":[("U4","1"),("R16","2"),("U5","1")],
 "QLB":     [("U5","6"),("U5","2")],
 "TRIP_RST":[("U5","5"),("J1","8"),("R20","2")],
 "VREF60":  [("U4","2"),("R17","2"),("R18","1")],
 "TL_K":    [("U7","1"),("U7","3"),("R19","2"),("R17","1")],
}

def build(path):
    libs = {}
    for _r, lib, nm, _v, _u in COMPS: libs["%s:%s" % (lib, nm)] = lib_block(lib, nm)
    libtxt = "\n".join("\t\t" + s.replace("\n", "\n\t\t") for s in libs.values())
    body = ""; n = 0
    coord = {}; conf = []; pincoord = {}
    for ref, lib, nm, val, _ignore in COMPS:
        common, pu = pins_units(lib, nm)
        units = list(URES[ref])
        maxu = max(pu.keys())
        if maxu not in {u for u, _, _ in units}:
            units = units + [(maxu, units[0][1], units[0][2] + 35)]
        for unit, x, y in units:
            n += 1
            body += place(n, ref, lib, nm, val, unit, x, y) + "\n"
            pins = pu.get(unit, {})
            for pin, (px, py) in pins.items():
                pincoord[(ref, pin)] = (round(x+px, 3), round(y-py, 3))
    bad = []
    for net, nodes in NETS.items():
        for ref, pin in nodes:
            if (ref, pin) not in pincoord: bad.append((net, ref, pin)); continue
            c = pincoord[(ref, pin)]
            if c in coord and coord[c] != net: conf.append((c, coord[c], net))
            coord[c] = net
            body += label(net, c[0], c[1]) + "\n"
    if bad: raise SystemExit("BAD pins: %s" % bad)
    if conf: print("!! COORD CONFLICTS (%d): %s" % (len(conf), conf[:12]))
    else: print("no coord conflicts")
    out = f'''(kicad_sch
\t(version 20260306)
\t(generator "eeschema")
\t(generator_version "10.0")
\t(uuid "{U_(1)}")
\t(paper "A2")
\t(lib_symbols
{libtxt}
\t)
{body}\t(sheet_instances
\t\t(path "/" (page "1"))
\t)
\t(embedded_fonts no)
)
'''
    open(path, "w").write(out)
    print("wrote", path, "| instances", n, "| labels", _L[0], "| nets", len(NETS))

if __name__ == "__main__":
    build("t1_frontend.kicad_sch")
