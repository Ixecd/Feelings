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
**单 always 块——不要分 RX 和 TX 两个块——单周期脉冲握手会漏。**
状态机：0 空闲 → 1 半起始位 → 2 数据位 ×8 → 3-12 发送位 → 0。
波特率：48MHz / 5000 = 9600。

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
"0b00" = 不分频 (48MHz)
"0b01" = /2  (24MHz)
"0b10" = /4  (12MHz)
"0b11" = /8  (6MHz)
```
未经验证——目前只用 "0b00"。

### 调试技巧
- 先短路 CP2102 TXD-RXD 确认模块本身能回显——隔离"是 FPGA 的问题还是 CP2102 的问题"
- LED=rx 直接观察信号有没有到 FPGA
- 所有 PMOD 引脚用 GND 触碰——找到能控制 LED 的孔——那就是连到 FPGA 的脚
- 二分法调波特率分频——先找到"偶尔能打对几个字"的值——再微调

### 快速打字乱码
不是 bug——是单缓冲限制。TX 发 1ms 期间不监听 RX——连续字符间隔 <1ms 会丢帧。
正常打字间隔 100-200ms——够用——不需要双缓冲——阶段一足够。

### iCESugar LED 引脚
```
D3 (RGB LED): FPGA ball 39 (绿), 40, 41
```
已验证 ball 39 可控。

### build 命令
```bash
cd hardware/ice40-uart-loopback
rm -f top.bin top.json top.asc
make top.bin   # yosys → nextpnr → icepack
# 拖 top.bin 到 iCESugar U 盘 → 弹出 → 烧录完成
```
