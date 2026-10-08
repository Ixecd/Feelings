import bisect

def load(fn):
    ts=[]; g=[]; vs=[]
    with open(fn) as f:
        for line in f:
            p=line.split()
            if len(p)<6: continue
            ts.append(float(p[0])); g.append(float(p[1])); vs.append(float(p[3]))
    return ts,g,vs

def analyze(tag):
    ts,g,vs=load(f"hs_{tag}.txt")
    vgs=[g[i]-vs[i] for i in range(len(ts))]
    # turn-off starts at a1 fall @200us
    t0=200e-6
    # find crossing of -3V (rising) after t0
    def cross(level):
        for i in range(len(ts)):
            if ts[i]>=t0 and vgs[i]>=level:
                return ts[i]
        return None
    c3=cross(-3.0); c1=cross(-1.0); c05=cross(-0.5)
    print(f"Rpull={tag:5s}  Vgs@200us={vgs[bisect.bisect_left(ts,200e-6)]:6.2f}V")
    for t in [200,202,205,210,215,220,230,240]:
        i=min(bisect.bisect_left(ts,t*1e-6),len(ts)-1)
        print(f"    t={t:3d}us  Vgs={vgs[i]:7.3f}V  Vgs=-12..-3")
    print(f"    -> 到 -3V (关断区): {('%.2f us'%((c3-t0)*1e6)) if c3 else '未到'}"
          f" ; 到 -1V: {('%.2f us'%((c1-t0)*1e6)) if c1 else '未到'}"
          f" ; 到 -0.5V: {('%.2f us'%((c05-t0)*1e6)) if c05 else '未到'}")
    print()

for tag in ["100k","22k","10k","4k7"]:
    analyze(tag)
