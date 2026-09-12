# GW1N UART 回环：仿真 + 综合完整流程（2026-09-04）

> 从 iCE40 step2b 移植 UART 回环到 GW1N（FG202），走通仿真 + yosys 综合 + nextpnr 布局 + gowin_pack 生成 bitstream。
> 卡点：烧录器（2232HL 报废），等 ST-Link 刷 CMSIS-DAP 或新 2232HL 到。

## 一、模块：uart_loopback.v（从 step2b 移植）

```
结构（复用 step2b 已验证逻辑）：
  块1（RX 机）：五态（等空闲高/等起始边/半位/8数据/停止），移位装载
  块2（TX 机）：移位发出 tx_data[0] + {1'b0, tx_data[7:1]}
  块3（结算） ：FIFO16 唯一写点，消费 rx_good/tx_req 脉冲

时钟：外部 50MHz 晶振（FG202 IO98 = CLK_IN），不是 iCE40 的 SB_HFOSC
  50MHz / 9600 → CYCLES=5208, HALF=2604

引脚（FG202）：
  tx  = IO15（→ CH340 RXD → 电脑）
  rx  = IO12（← CH340 TXD ← 电脑）
  clk = IO98（50MHz 晶振）
  led = IO27（L1），err = IO28（L2）
```

**iCE40 → GW1N 要改的**：
```
1. 时钟：SB_HFOSC(48M) → 外部 clk 输入（IO98 50M 晶振）
2. 引脚约束：.pcf(Lattice) → .cst(Gowin)
3. 分频：48M/9600 → 50M/9600（CYCLES 5000→5208）
4. 纯逻辑（RX/TX 机/FIFO/两拍同步）直接复用
```

**仿真初始化坑**：FPGA 上电寄存器默认 0，但仿真寄存器默认 X。
必须加 `initial` 块把所有 reg 置 0，否则状态机卡 X（tb 采样机也要初始化）。

## 二、仿真验证（iverilog + vvp）

```bash
make          # 或 make TOP=uart_loopback
make wave     # + Surfer 看波形
```

验证通过：
```
0x55 → 0x55 回发 ✓
0xAA → 0xAA 回发 ✓
"你好"UTF-8 (E4 BD A0 E5 A5 BD) + 换行 0x0A → 逐个原样回发 ✓（FIFO 连续回显）
收到 9 字节全对
```

**注意**：Makefile TOP 默认值从 counter 改成 uart_loopback。

## 三、门级网表仿真 gatesim（验证综合没改坏逻辑）

iCESugar 教训：RTL 仿真对、综合后网表可能挂（yosys FSM 提取改坏 default）。
所以综合后必须跑门级仿真——用 Gowin 单元库 + 综合网表验证逻辑没被改坏。

```bash
make gatesim   # 一条命令：综合 → 网表 → 门级仿真
```

流程（Makefile gatesim 目标）：
```
① yosys: read_verilog .v → synth_gowin → write_verilog 网表(sim/synth_uart.v)
② iverilog: Gowin cells_sim.v + synth网表 + tb_gate.v → gate.out
③ 跑 gate.out → 验证回环
```

验证通过（Gowin 单元库，带真实门模型）：
```
0x55 → 0x55 ✓
0xAA → 0xAA ✓
"你好"UTF-8 → 全部原样回发 ✓
→ 综合没改坏逻辑，RTL行为 = 门级行为 = 上板前信心
```

## 三、综合流程（yosys → nextpnr → gowin_pack）

### ① yosys 综合：.v → json

```bash
yosys -p "read_verilog ../uart_loopback.v; synth_gowin -top uart_loopback -json uart2.json"
```

资源统计（无锁存器 ✓）：
```
总 cell: 733
  ALU 77（计数器/分频）
  DFF 类 235（reg 们）
  LUT 类 ~200（组合）
  RAM: 无（FIFO 用寄存器实现）
```

### ② nextpnr 布局布线：json + pin.cst → pnr.json

```bash
nextpnr-himbaechel --device GW1N-LV4LQ144C6/I5 --json uart2.json \
  --write uart_pnr.json --vopt cst=pin.cst
```
时序收敛（timing cost 40→10），clk 走全局资源。

### ③ gowin_pack：pnr.json → .fs bitstream

```bash
gowin_pack -d GW1N-4 -o uart_loopback.fs uart_pnr.json
# 生成 1.1MB .fs（GW1N-4 标准 bitstream 大小）
```

### ④ 烧录（等烧录器）
```bash
openFPGALoader -c ft2232 --ftdi-channel 0 --fpga-part GW1N uart_loopback.fs
# 或 ST-Link 刷 CMSIS-DAP：openFPGALoader -c cmsisdap --fpga-part GW1N uart_loopback.fs
```

## 四、综合踩坑

**坑 1：RAM16SDP4 布局失败**
```
症状：fifo_mem 是 reg [7:0][0:15]，yosys 自动推断成分布式 RAM (RAM16SDP4)
      nextpnr 报 "Unable to place cell 'fifo_mem.0.1', no BELs remaining for RAM16SDP4"
原因：apycula/nextpnr 对 GW1N 块 RAM 支持有限
解法：fifo_mem 加 (* ram_style = "registers" *) → 用纯寄存器实现
      16×8 FIFO 很小，寄存器实现合理（GW1N 有 4680 LUT，733 cell 够）
```

**坑 2：`-nobram` 参数没完全生效**
```
synth_gowin -nobram 后 RAM16SDP4 还在（它是分布式 RAM，不是 BRAM）
直接改代码 ram_style 最可靠
```

## 五、待办（卡烧录器）

- [x] 仿真验证（单字节 + 中文 UTF-8 连续回显）
- [x] yosys 综合（无锁存器）
- [x] 门级网表仿真 gatesim（综合没改坏逻辑）
- [x] nextpnr 布局（时序收敛）
- [x] gowin_pack 生成 .fs
- [ ] 烧录到 FG202（等 ST-Link CMSIS-DAP / 新 2232HL）
- [ ] 真板串口验证（电脑发字符，FPGA 回显，CH340 转发）
