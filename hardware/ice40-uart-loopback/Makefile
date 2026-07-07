# iCE40 UART Loopback - IceStorm Build for iCESugar UP5K-SG48
TOP = top
DEVICE = up5k
PACKAGE = sg48
PCF = $(TOP).pcf

all: $(TOP).bin

$(TOP).json: $(TOP).v
	yosys -p "synth_ice40 -top top -json $(TOP).json" $(TOP).v

$(TOP).asc: $(TOP).json $(PCF)
	nextpnr-ice40 --$(DEVICE) --package $(PACKAGE) --json $(TOP).json --pcf $(PCF) --asc $(TOP).asc

$(TOP).bin: $(TOP).asc
	icepack $(TOP).asc $(TOP).bin

prog: $(TOP).bin
	@echo "Drag $(TOP).bin to /Volumes/iCELink/"

timing: $(TOP).asc
	icetime -d $(DEVICE) $(TOP).asc

clean:
	rm -f $(TOP).json $(TOP).asc $(TOP).bin