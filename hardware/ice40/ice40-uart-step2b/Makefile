# iCE40 UART Loopback - IceStorm Build for iCESugar UP5K-SG48
TOP = top
DEVICE = up5k
PACKAGE = sg48
PCF = $(TOP).pcf

all: $(TOP).bin

$(TOP).json: $(TOP).v
	yosys -p "synth_ice40 -nobram -top top -json $(TOP).json" $(TOP).v

$(TOP).asc: $(TOP).json $(PCF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $(TOP).json --pcf $(PCF) --asc $(TOP).asc --seed 3

$(TOP).bin: $(TOP).asc
	icepack $(TOP).asc $(TOP).bin

prog: $(TOP).bin
	@echo "Drag $(TOP).bin to /Volumes/iCELink/"

timing: $(TOP).asc
	icetime -d $(DEVICE) $(TOP).asc

# ── 两层仿真：RTL 验证意图，门级验证综合 ──
.PHONY: sim gatesim
sim:
	yosys -p "read_verilog $(TOP).v; synth_ice40 -nobram -top top; write_verilog -noattr sim/synth_top.v"
	iverilog -g2012 -o sim/rtl.out sim/top_sim2.v sim/tb_stream.v
	./sim/rtl.out

gatesim: sim
	iverilog -g2012 -o sim/gate.out sim/cells_official.v sim/synth_top.v sim/tb_gate.v
	./sim/gate.out

clean:
	rm -f $(TOP).json $(TOP).asc $(TOP).bin sim/synth_top.v sim/*.out