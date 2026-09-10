# iCESugar MAX30102 读取 — 综合/布局/打包
# 依赖 oss-cad-suite (yosys / nextpnr-ice40 / icepack)
# 用法: make    → 生成 max30102_test.bin，拖到 iCESugar 的 iCELink U 盘烧录

TOP    = max30102_ppg
SRCS   = $(TOP).v i2c_master.v uart_tx.v
DEVICE = up5k
PACKAGE= sg48

OSS     = $(HOME)/oss-cad-suite/oss-cad-suite/bin
YOSYS   = $(OSS)/yosys
NEXTPNR = $(OSS)/nextpnr-ice40
ICEPACK = $(OSS)/icepack

all: $(TOP).bin

$(TOP).json: $(SRCS)
	$(YOSYS) -p "synth_ice40 -top $(TOP) -json $@" $(SRCS)

$(TOP).asc: $(TOP).json $(TOP).pcf
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(TOP).pcf --asc $@

$(TOP).bin: $(TOP).asc
	$(ICEPACK) $< $@

clean:
	rm -f $(TOP).json $(TOP).asc $(TOP).bin

.PHONY: all clean
