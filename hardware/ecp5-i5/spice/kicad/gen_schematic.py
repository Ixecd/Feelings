#!/usr/bin/env python3
"""Generate a KiCad-10 .kicad_sch for the tVNS T1 front-end (label-based connectivity).
Connectivity is by net labels placed at each symbol pin endpoint. Validate:
  kicad-cli sch export netlist --format kicadsexpr -o out.net DESIGN.kicad_sch
"""
import os, re, uuid

SYMS = "/Applications/KiCad/KiCad.app/Contents/SharedSupport/symbols"
LIBFILE = {"Device":"Device.kicad_sym","Transistor_FET":"Transistor_FET.kicad_sym",
           "Transistor_BJT":"Transistor_BJT.kicad_sym","Amplifier_Operational":"Amplifier_Operational.kicad_sym",
           "Comparator":"Comparator.kicad_sym","Reference_Voltage":"Reference_Voltage.kicad_sym",
           "74xx":"74xx.kicad_sym","Connector_Generic":"Connector_Generic.kicad_sym"}

def _extract(lib, name):
    txt = open(os.path.join(SYMS, LIBFILE[lib]), encoding="utf-8").read()
    key = '(symbol "%s"' % name; i = txt.find(key)
    if i < 0: raise SystemExit("symbol not found: %s:%s" % (lib, name))
    d = 0
    for j in range(i, len(txt)):
        if txt[j] == '(': d += 1
        elif txt[j] == ')':
            d -= 1
            if d == 0: return txt[i:j+1]
    raise SystemExit("unbalanced")

def _resolve(lib, name, d=0):
    blk = _extract(lib, name)
    m = re.search(r'\(extends "([^"]+)"\)', blk)
    if m and d < 6: return _resolve(lib, m.group(1), d+1)
    return blk, name

def lib_block(lib, name):
    blk, base = _resolve(lib, name)
    blk = re.sub(r'\(symbol "%s"' % re.escape(base), '(symbol "%s:%s"' % (lib, name), blk, count=1)
    blk = re.sub(r'\(symbol "%s_(\d+_\d+)"' % re.escape(base),
                 lambda m: '(symbol "%s_%s"' % (name, m.group(1)), blk)
    return blk

def pin_map(lib, name):
    blk, _ = _resolve(lib, name); out = {}
    for part in re.split(r'\(pin ', blk)[1:]:
        num = re.search(r'\(number\s+"([^"]+)"', part); at = re.search(r'\(at\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\)', part)
        if num and at: out[num.group(1)] = (float(at.group(1)), float(at.group(2)))
    return out

def U(n): return "00000000-0000-0000-0000-%012d" % n

def place(n, ref, lib, name, val, x, y):
    return f'''\t(symbol
\t\t(lib_id "{lib}:{name}")
\t\t(at {x} {y} 0)
\t\t(unit 1)
\t\t(exclude_from_sim no) (in_bom yes) (on_board yes) (dnp no)
\t\t(uuid "{U(n)}")
\t\t(property "Reference" "{ref}" (at {x} {y-2.5} 0) (effects (font (size 1.27 1.27))))
\t\t(property "Value" "{val}" (at {x} {y+2.5} 0) (effects (font (size 1.27 1.27))))
\t\t(property "Footprint" "" (at {x} {y} 0) (effects (font (size 1.27 1.27)) (hide yes)))
\t\t(property "Datasheet" "~" (at {x} {y} 0) (effects (font (size 1.27 1.27)) (hide yes)))
\t\t(instances (project "feelings" (path "/{U(1)}" (reference "{ref}") (unit 1))))
\t)'''

LN = [0]
def label(net, x, y):
    LN[0] += 1
    return f'''\t(label "{net}"
\t\t(at {x} {y} 0)
\t\t(effects (font (size 1.0 1.0)) (justify left bottom))
\t\t(uuid "{U(700000+LN[0])}")
\t)'''

# ---------------- design ----------------
# (ref, lib, symbol, value, x, y)
COMPS = [
 ("Q1","Transistor_FET","BS250","BS250",60,40),("Q2","Transistor_FET","BS250","BS250",60,70),
 ("Q3","Transistor_FET","2N7000","2N7000",95,40),("Q4","Transistor_FET","2N7000","2N7000",95,70),
 ("Q5","Transistor_BJT","2N3904","2N3904",35,40),("Q6","Transistor_BJT","2N3904","2N3904",35,70),
 ("R1","Device","R","22k",75,20),("R2","Device","R","22k",75,95),
 ("D1","Device","D_Zener","12V",75,30),("D2","Device","D_Zener","12V",75,85),
 ("R3","Device","R","4.7k",25,40),("R4","Device","R","4.7k",25,70),
 ("R5","Device","R","100k",35,20),("R6","Device","R","100k",35,95),
 ("U3","Amplifier_Operational","MCP6001R","OPA171",60,130),
 ("Q7","Transistor_FET","2N7000","2N7000",95,130),("Q8","Transistor_BJT","2N3904","2N3904",35,130),
 ("Q9","Transistor_FET","2N7002","2N7002",120,115),
 ("R7","Device","R","1k",75,115),("R8","Device","R","100k",110,140),
 ("R9","Device","R","100R",95,150),("R10","Device","R","4.7k",135,105),
 ("R11","Device","R","10k",25,130),("R12","Device","R","100k",25,145),
 ("C1","Device","C","0.47n",50,145),
 ("RV1","Device","R_Potentiometer","1k",30,165),
 ("R13","Device","R","39k",45,165),("R14","Device","R","10k",55,165),("R15","Device","R","10k",65,165),
 ("C2","Device","C","3.3u",130,40),("D3","Device","D_Zener","36V",145,30),("D4","Device","D_Zener","36V",145,50),
]
# net -> [(ref, pin), ...]
NETS = {
 "VS":   [("Q1","3"),("Q2","3"),("R1","1"),("R2","1"),("D1","2"),("D2","2")],
 "GND":  [("Q5","1"),("Q6","1"),("R5","2"),("R6","2"),("U3","2"),("R9","2"),
          ("R8","2"),("Q8","1"),("R12","2"),("C1","2"),("RV1","1"),("RV1","3"),
          ("R14","2")],
 "V12":  [("U3","5")],
 "V5":   [("R10","1")],   # placeholder (fixed below)
 "A1":   [("Q4","2"),("R3","1")],
 "A2":   [("Q3","2"),("R4","1")],
 "G1":   [("Q1","2"),("R1","2"),("D1","1"),("Q5","3")],
 "G2":   [("Q2","2"),("R2","2"),("D2","1"),("Q6","3")],
 "MID1": [("Q1","1"),("Q3","3"),("C2","1")],
 "MID2": [("Q2","1"),("Q4","3"),("D3","2"),("D4","2")],
 "B":    [("Q3","1"),("Q4","1"),("Q7","3")],
 "S":    [("Q7","1"),("R9","1"),("U3","4"),("Q9","2")],
 "QG":   [("Q7","2"),("R7","2"),("R8","1")],
 "OUT":  [("U3","1"),("R7","1")],
 "INP":  [("U3","3"),("Q8","3"),("R15","2"),("C1","1")],
 "LH1B": [("R3","2"),("Q5","2"),("R5","1")],
 "LH2B": [("R4","2"),("Q6","2"),("R6","1")],
 "ENB":  [("R11","1"),("Q9","1")],
 "QDB":  [("Q8","2"),("R11","2"),("R12","1")],
 "VN":   [("RV1","2"),("R13","1")],
 "VN2":  [("R13","2"),("R14","1"),("R15","1")],
 "EL1":  [("C2","2"),("D3","1"),("D4","1")],
 "AWD":  [("R10","2"),("Q9","3")],
}
NETS["V5"] = [("R10","1")]

def build(path):
    libs = {}
    for _, lib, name, _, _x, _y in COMPS: libs["%s:%s" % (lib, name)] = lib_block(lib, name)
    libtxt = "\n".join("\t\t" + s.replace("\n", "\n\t\t") for s in libs.values())
    body = ""
    for i, (ref, lib, name, val, x, y) in enumerate(COMPS):
        body += place(i+1, ref, lib, name, val, x, y) + "\n"
    pm = {}
    for ref, lib, name, val, x, y in COMPS:
        pm[ref] = (pin_map(lib, name), x, y)
    unresolved = []
    for net, nodes in NETS.items():
        for ref, pin in nodes:
            p, x, y = pm[ref]
            if pin not in p: unresolved.append((net, ref, pin)); continue
            px, py = p[pin]
            body += label(net, round(x+px, 4), round(y-py, 4)) + "\n"
    if unresolved:
        raise SystemExit("unresolved pins: %s" % unresolved)
    out = f'''(kicad_sch
\t(version 20260306)
\t(generator "eeschema")
\t(generator_version "10.0")
\t(uuid "{U(1)}")
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
    print("wrote", path, "| comps", len(COMPS), "| labels", LN[0])

build("t1_frontend.kicad_sch")
