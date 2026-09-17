# ECP5 i5 刺激脉冲发生器 — 综合/布局/打包/烧录
# 依赖 oss-cad-suite (yosys / nextpnr-ecp5 / ecppack / openFPGALoader)
# 用法:
#   make          → ecp5_stim_pulse.bit
#   make flash    → 烧 SRAM（掉电丢）
#   make flash-f  → 烧 SPI flash（上电自启）
TOP    = ecp5_stim_pulse
SRCS   = $(TOP).v
DEVICE = 25k
PACKAGE= CABGA381

OSS     = $(HOME)/oss-cad-suite/oss-cad-suite/bin
YOSYS   = $(OSS)/yosys
NEXTPNR = $(OSS)/nextpnr-ecp5
ECPPACK = $(OSS)/ecppack
LOADER  = $(OSS)/openFPGALoader

all: $(TOP).bit

$(TOP).json: $(SRCS)
	$(YOSYS) -p "synth_ecp5 -top $(TOP) -json $@" $(SRCS)

$(TOP).config: $(TOP).json $(TOP).lpf
	$(NEXTPNR) --json $< --lpf $(TOP).lpf --$(DEVICE) --package $(PACKAGE) --freq 25 --textcfg $@

$(TOP).bit: $(TOP).config
	$(ECPPACK) $< $@

flash: $(TOP).bit
	$(LOADER) -c cmsisdap $(TOP).bit

flash-f: $(TOP).bit
	$(LOADER) -c cmsisdap --unprotect-flash -f $(TOP).bit

clean:
	rm -f $(TOP).json $(TOP).config $(TOP).bit

.PHONY: all flash flash-f clean
