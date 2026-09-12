# iCESugar MAX30102/30105 采集 — 综合/布局/打包
# 依赖 oss-cad-suite (yosys / nextpnr-ice40 / icepack)
# 用法:
#   make              → max30102_hr.bin（默认 MAX30102 红+IR）
#   make GREEN=1      → 同上但走 MAX30105 绿光（multi-LED），产物 max30102_hr.bin
#   拖 max30102_hr.bin 到 iCESugar 盘烧录

TOP    = max30102_hr
SRCS   = $(TOP).v i2c_master.v uart_tx.v hr_estimator.v
DEVICE = up5k
PACKAGE= sg48

ifeq ($(GREEN),1)
VFLAGS = -DUSE_GREEN
endif

OSS     = $(HOME)/oss-cad-suite/oss-cad-suite/bin
YOSYS   = $(OSS)/yosys
NEXTPNR = $(OSS)/nextpnr-ice40
ICEPACK = $(OSS)/icepack

all: $(TOP).bin

$(TOP).json: $(SRCS)
	$(YOSYS) -p "read_verilog $(VFLAGS) $(SRCS); synth_ice40 -top $(TOP) -json $@"

$(TOP).asc: $(TOP).json $(TOP).pcf
	$(NEXTPNR) --$(DEVICE) --package $(PACKAGE) --json $< --pcf $(TOP).pcf --asc $@

$(TOP).bin: $(TOP).asc
	$(ICEPACK) $< $@

clean:
	rm -f $(TOP).json $(TOP).asc $(TOP).bin

.PHONY: all clean
