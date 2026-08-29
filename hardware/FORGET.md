# FORGET —— 硬件开发中容易忘记但绝对不能忘的东西

> 优先级：P0 = 忘了会烧板子/浪费几周。P1 = 忘了会卡半天。P2 = 忘了会走弯路。

---

## P0

### iCE40 时钟源
**永远用内部 SB_HFOSC，别碰外部 STM32 MCO。**
内部振荡器 48MHz，稳定可靠——外部 MCO 烧录后可能不跑、可能频率不对。
CLKHF_DIV("0b00") = 不分频 = 48MHz。

### 引脚映射（PMOD1 → FPGA ball）
```
PMOD 物理孔 → FPGA ball（已验证）
  RX:  pin 2（对应 PMOD 上排第二个孔） → FPGA ball 2（= P1_11）
  TX:  pin 6（对应 PMOD 下排某个孔）   → FPGA ball 6（= P1_2）
  GND: 任一 GND 孔
```
**不要假设丝印 P4/P6 = FPGA ball 4/6。** 丝印 Px 是 PMOD 序号——不是 FPGA ball。

### UART 设计
**起步写法：单 always 块——单周期脉冲握手会漏。**
双机并行版（2b）已板级验证，可行——但必须守三条纪律：
```
① 事件脉冲由源块独占写（rx_good/tx_req），结算块独占写 FIFO 状态
② case 的真状态必须显式编号，default 只做非法状态防御，绝不承载真逻辑
③ 状态机用单层 case，不要 if/else 套 case
```
②③ 是 yosys FSM 提取的坑：RTL 仿真行为正确，综合后变成坏机器（2b 板级两天不通的全部原因）。
状态机：0 空闲 → 1 半起始位 → 2 数据位 ×8 → 3-12 发送位 → 0。
波特率：48MHz / 5000 = 9600。

### 烧板前两道关
**RTL 仿真验证意图，门级仿真验证综合——两层都过再烧。**
```
make sim       # RTL 压测（32 字节连发）
make gatesim   # 综合网表仿真（官方 cells_sim + 自振荡 SB_HFOSC）
```
门级仿真的坑：官方 cells_sim 的 SB_HFOSC 是白盒不振荡（要换自振荡版）；
FF 模型 E 罩 R（E=0 时 R 被忽略）——手写模型别搞错优先级。

### 布线
**CP2102 GND 必须接 FPGA GND。不接地 = 信号无参考电平 = 全乱码。**
千万不要把电源脚（3V3/5V）短路到 GND——烧 CP2102 或烧 FPGA。

### 电源隔离
iCESugar 和 CP2102 **各自独立 USB 供电**——不要共用一根 USB 线——CP2102 对供电质量敏感。

---

## P1

### GW1N 工具链（待验证）
```
开源工具链：yosys + nextpnr-himbaechel + apycula(gowin_pack)
器件名：GW1N-LV4LQ144C6/I5
烧录：openFPGALoader + CMSIS-DAP（或 CP2102 bit-bang JTAG）
```
CST 引脚约束文件格式和 PCF 不同——需对着板子丝印或原理图反推。

### GW1N 烧录（2026-08-29 验证到一半）
```
FT2232HL（CJMCU-2232HL）A 通道 → FG202 J1 JTAG 排针：
  AD0(TCK) → J1-1, AD1(TDI) → J1-3, AD2(TDO) → J1-5, AD3(TMS) → J1-7, GND → GND
FPGA 引脚：TMS=13, TCK=14, TDI=16, TDO=18（J1 各经 22R）
detect: openFPGALoader -c ft2232 --ftdi-channel 0 --fpga-part GW1N --detect  → idcode 0x100381b
SRAM 烧: openFPGALoader -c ft2232 --ftdi-channel 0 --fpga-part GW1N [-r] blink.fs
```
已确认：
- 硬件链路全通——导线短接 27→GND，L1 亮（LED=D3V3→R1(1K)→LED→IO27，拉低点亮）
- 外部 W25Q32 里烧的就是 blink.fs（前 64KB 100% 匹配）→ `-f` 烧 Flash 实际成功，openFPGALoader 的 "CRC FAIL" 是读回校验 bug
- 核心问题：FG202 从内置 Flash autoboot（MODE≈000，MODE0/1 引脚实测 0.96V 中间态），外部 W25Q32 配置不参与启动；所有 IO 实测 3.23V = FPGA 未进用户模式，SRAM 配置后 Done Final 置位但 IO 不动
- MODE0=IO144、MODE1=IO143（各 10K 分压，实测 0.96V）
- bitstream 约束：IO_LOC "l1" 27 等，l1→X0Y12/IOBA=IOL13A=IO27，gowin_unpack 反解 OBUF 在 R13C1/R15C1（IOL13A/B、IOL15A/B）✓

未解：
- 为什么 SRAM 配置 Done Final 但 FPGA 不进用户模式（怀疑 openFPGALoader 对 GW1N-4 的 SRAM 流程缺唤醒/RELOAD 步骤，或 MODE 中间态干扰）
- 下一步：换能传数据的 USB 线（FT2232HL 电源灯红但 USB 不枚举=D+/D- 不通），连上后试 SRAM+`-r` reset，再验证内置 Flash

### 傻鸟设计吐槽（FG202 + CJMCU-2232HL）
```
- 板子全是洞、没标引脚——对丝印反推引脚跟猜谜一样
- MODE0/1 引脚做 10K 分压搞出 0.96V 中间态——既不高也不低，纯恶心人
- 外部 W25Q32 烧了配置根本不参与启动（从内置 Flash autoboot）——白烧
- 官方例程 cst 约束的 cell 名（R13C1_OBUF_A）和实际设计名（l1_OBUF_O）对不上——openFPGALoader 直接跳过约束
- CJMCU-2232HL 电源灯红但不枚举——D+/D- 不通，Micro-USB 座虚焊/线只供电
- openFPGALoader 的 Gowin 烧 Flash 报 "CRC FAIL" 但数据其实写进去了——误导排查方向
- SRAM 配置 Done Final 置位但 IO 全高阻——配置"成功"了个寂寞
```


### 双板 UART 帧协议
```
10 字节帧：8 字节数据 + 1 字节帧序号 (0-255 循环) + 1 字节 CRC-8-CCITT
GW1N 接收：先打两拍同步（跨时钟域） → 验证 CRC → 入 FIFO
5ms 看门狗超时 → 异步硬路径熔断 → 切安全锚点帧
```

### 过采样时钟
GW1N 板载 24MHz → rPLL 硬核 → 精准 7.3728MHz（16×460800 波特）。
不能强行分频——误差累积超 4.5% = 高位字节乱码。

### 不要跨时钟域发单周期脉冲
单周期脉冲从快时钟域到慢时钟域——概率极低被捕获。
要么拉长脉冲——要么用持续信号+握手——要么同域。
iCE40 内部用单 always 块避开了这个问题。

---

## P2

### CLKHF_DIV 编码
```
"0b00" = 不分频 (48MHz)   ← 已验证可用
"0b01" = /2  (24MHz)      ← 已验证：在这块 UP5K 板上不出时钟，不能用
"0b10" = /4  (12MHz)      未验证
"0b11" = /8  (6MHz)       未验证
```

### 调试技巧
- 先短路 CP2102 TXD-RXD 确认模块本身能回显——隔离"是 FPGA 的问题还是 CP2102 的问题"
- LED=rx 直接观察信号有没有到 FPGA
- 所有 PMOD 引脚用 GND 触碰——找到能控制 LED 的孔——那就是连到 FPGA 的脚
- 二分法调波特率分频——先找到"偶尔能打对几个字"的值——再微调

### 快速打字乱码
2b 版已有 FIFO16 吸收连发（32 字节连发仿真通过）——连发丢帧不再是单缓冲限制。
正常打字 100-200ms 间隔足够。若仍有乱码，先查 FSM 铁律与门级仿真。

### iCESugar LED 引脚
```
D3 (RGB LED): FPGA ball 39 (绿), ball 40 (红), ball 41 (蓝)
```
ball 39/40 已验证。绿+红同时亮 = 黄色。
**调试用法：把 err 输出换着接内部信号当单线逻辑分析仪。**

### build 命令
```bash
cd hardware/ice40-uart-loopback
rm -f top.bin top.json top.asc
make top.bin   # yosys → nextpnr → icepack
# 拖 top.bin 到 iCESugar U 盘 → 弹出 → 烧录完成
```
