# nRF52832 开发 Makefile（Arduino CLI + OpenOCD/ST-Link）
# 无 SoftDevice / 无 bootloader：app 直接链接并运行在 0x0（用自定义链接脚本 nrf52832_nosd.ld）
# 用法:
#   make compile SKETCH=blink   → 编译到 build-nosd/
#   make flash   SKETCH=blink   → 整片擦除 + 烧到 0x0
#   make detect                 → 探测芯片（验证 ST-Link 接线）

FQBN    = adafruit:nrf52:feather52832
SKETCH ?= blink
BUILD   = build-nosd
LDS     = nrf52832_nosd.ld   # 位于 core 的 cores/nRF5/linker/ 下

OSS     = $(HOME)/oss-cad-suite/oss-cad-suite
OPENOCD = $(OSS)/bin/openocd
OCD_SCR = $(OSS)/share/openocd/scripts
OCD     = $(OPENOCD) -s $(OCD_SCR) -f interface/stlink.cfg -f target/nrf52.cfg

.PHONY: all compile flash detect erase

all: compile

compile:
	arduino-cli compile --fqbn $(FQBN) --build-property build.ldscript=$(LDS) --output-dir $(BUILD) $(SKETCH)

detect:
	$(OCD) -c "init; targets; exit"

# 无 bootloader：整片擦除后烧到 0x0，复位即运行
flash:
	$(OCD) -c "init; reset halt; nrf5 mass_erase; program $(BUILD)/$(SKETCH).ino.hex verify; reset run; exit"

erase:
	$(OCD) -c "init; reset halt; nrf5 mass_erase; reset; exit"
