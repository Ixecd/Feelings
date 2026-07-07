# iCE40 UART Loopback Bringup — Session 2026-07-07

## 环境

- Mac M-series, macOS
- 转换器: USB-C → 3×USB-A
- 工具链: yosys 0.66 + nextpnr-ice40 + icepack (IceStorm)

## 设备

- iCESugar (iCE40 HX1K-VQ100) — 板载CH340编程器
- CP2102 USB-UART模块 (5引脚: 3V3, TXD, RXD, GND, +5V)

## 接线

```
CP2102 +5V  → iCESugar 5V pin
CP2102 GND  → iCESugar GND
CP2102 TXD  → iCESugar P6 (丝印UART_RX)
CP2102 RXD  → iCESugar P4 (丝印UART_TX)
```

供电: iCESugar通过USB接到转换器供电，CP2102通过5V/GND从iCESugar取电并USB接到转换器。

## 行为记录

1. **CP2102红灯** — 通电常亮 → 供电正常
2. **CP2102蓝灯** — 按键盘时闪烁 → 数据从Mac→CP2102发出
3. **iCESugar D1 (ball 99)** — 蓝灯常亮 → FPGA已配置、时钟运行
4. **iCESugar D4 (ball 95)** — 初始快速闪烁 → UART TX被RX引脚悬空噪声触发 → 毛刺滤波器(v2)加入后停止闪烁 → 滤波器生效
5. **终端串口** — CP2102被系统识别为 `/dev/cu.usbserial-0001` → screen连接成功 → 纯TX测试(持续发0x55)无输出 → UART TX/RX引脚映射疑似不正确

## 已验证

- ✅ 工具链完整通路: yosys → nextpnr → icepack → .bin
- ✅ 时钟 ball 21: 12MHz验证通过 (LED + PNR时序无违例)
- ✅ LED ball 99 (D1): 输出控制正常
- ✅ LED ball 95 (D4): 输出控制正常
- ✅ CP2102: USB枚举正常、数据发送正常(蓝灯闪)、终端可打开
- ✅ FPGA配置: 比特流拖拽烧录正常

## 未验证

- ❌ UART TX (ball 4 / P4): 不确定ball 4是否等于丝印P4
- ❌ UART RX (ball 3 / P6): 不确定ball 3是否等于丝印P6
- ❌ 完整UART回环: RX/TX不通

## 下一步

需要确认ICESugar板子上的P编号和VQ100球号的对应关系——查找官方原理图或pcf文件。备选方案: 用LED脚测试TX (ball 95)→验证串口通路。

## 文件

- top.v: UART回环Verilog (v1原始版/v2毛刺滤波版/v3纯TX测试版)
- top.pcf: 引脚约束 (TX=4, RX=3, clk=21, D1=99, D4=95)
- Makefile: IceStorm构建脚本

## 指令

```bash
make               # 编译
make prog          # 烧录

screen /dev/cu.usbserial-0001 460800              # 连接串口
Ctrl+A → K → Y                                     # 退出screen
```