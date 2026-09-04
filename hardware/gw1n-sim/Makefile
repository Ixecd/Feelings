# Verilog 仿真 Makefile
# 用法：
#   make TOP=counter      编译 + 仿真 counter.v + counter_tb.v，生成 counter.vcd
#   make wave TOP=counter 编译 + 仿真 + 用 surfer 打开波形
#   make clean            清理生成文件
#
# 文件约定：
#   <name>.v      模块
#   <name>_tb.v   testbench
#   <name>.vcd    波形（自动生成）

TOP ?= uart_loopback
SIM ?= vvp
WAVEVIEWER ?= surfer

VSRC = $(TOP).v $(TOP)_tb.v
VVP  = $(TOP).vvp
VCD  = $(TOP).vcd

.PHONY: all sim wave gatesim clean

all: sim

sim: $(VVP)
	vvp $(VVP)

$(VVP): $(VSRC)
	iverilog -o $(VVP) $(VSRC)

wave: sim
	$(WAVEVIEWER) $(VCD) &

# 门级网表仿真：验证综合没改坏逻辑（iCESugar 教训）
# 流程：yosys 综合 → write_verilog 网表 → iverilog + Gowin 单元库 + tb_gate
gatesim:
	mkdir -p sim
	yosys -p "read_verilog $(TOP).v; synth_gowin -top $(TOP); write_verilog -noattr sim/synth_$(TOP).v" > /dev/null 2>&1
	iverilog -g2012 -o sim/gate.out /opt/homebrew/share/yosys/gowin/cells_sim.v sim/synth_$(TOP).v tb_gate.v
	./sim/gate.out

clean:
	rm -f *.vvp *.vcd *.vpd sim/*.out sim/synth_$(TOP).v
