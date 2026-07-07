# iCE40 UART 踩坑全记录 — 2026-07-07

> 板子: iCESugar (iCE40UP5K-SG48)
> 时钟: 12MHz (STM32 MCO → pin 35)
> 工具链: yosys + nextpnr-ice40 + icepack (IceStorm, open-source, macOS)

---

## 坑一：芯片型号和封装全错

之前bringup用 `--hx1k --package vq100` 编译，LED能亮，时钟能跑。但实际板子是 **iCE40UP5K-SG48**，不是HX1K-VQ100。SG48只有48个引脚，VQ100有100个引脚——引脚号完全不一样。LED之前能亮是因为iCESugar的RGB LED在SG48上的pin 39/40/41恰好和之前猜的号对上了——纯属巧合。

正确编译参数：`--up5k --package sg48`。

---

## 坑二：丝印P4/P6不等于FPGA ball号

板子上的PMOD排针标着P4/P6/UART_TX/UART_RX。以为P4=FPGA pin 4、P6=FPGA pin 6——结果拿去当UART跑了一上午——全白干。

真相：P4/P6是PMOD排针的序号——不是FPGA物理引脚。P1_11才是pin 4，P1_2才是pin 6。Px_y后面那个数字才是FPGA引脚号，前面是PMOD编号。

---

## 坑三：CP2102和板载串口没有冲突——因为板载串口根本没被切成UART模式

iCESugar的iCELink固件把编程器和虚拟串口做进了同一个USB通道。拖bin烧录时是iCELink模式，烧完之后如果不拔掉重插或者固件不自动切模式——串口就一直在编程模式，`screen`打开全是 `@init @cdone @prog` 的编程日志。

官方给了 `icesprog` 工具可以手动切桥接模式，但macOS二进制没直接跑通。

**最终绕路方案：不用板载虚拟串口——走PMOD排针+外接CP2102。**

---

## 坑四：外接CP2102不知道接哪个引脚

`io.pcf` 里写着：

```
set_io RX    4
set_io TX    6
```

对应PMOD1排针：

```
P1_11 = pin 4 = FPGA RX
P1_2  = pin 6 = FPGA TX
```

CP2102接线：

```
CP2102 TXD → PMOD1 P1_11 (pin 4, FPGA RX)
CP2102 RXD → PMOD1 P1_2  (pin 6, FPGA TX)
CP2102 GND → PMOD1 GND
CP2102 USB → Mac
```

---

## 坑五：波特率对不上

先试了 460800——不亮。试了 115200——没反应。试了 9600——打出乱码。说明TX/RX都通了——但时钟不准或者波特真值和我们算的除数为差。

降到 2400——能出字母——但回环不对。1200——也能出——也不对。试到目前最好的状态是 2400/1200 能看到字母——但还不稳定。

下一步：发固定字符 `Z`——在不同波特下看终端回的内容——找到那档能稳定出 `Z` 的——就是真实波特率。然后用测出来的真实波特反推等控器等控器等控器等控器等控器等控器等控器等控器等控器等控器等控器等控器等控器等控器等控器等控器。

---

## 已验证无误

- ✅ 芯片型号: iCE40UP5K-SG48
- ✅ 时钟: pin 35 (STM32 MCO 12MHz)
- ✅ UART RX: pin 4 (PMOD1 P1_11)
- ✅ UART TX: pin 6 (PMOD1 P1_2)
- ✅ 工具链全通: yosys → nextpnr → icepack → .bin
- ✅ CP2102: USB枚举正常, 数据收发物理层通
- ✅ FPGA: 比特流拖拽烧录正常, TX侧有波形输出

## 待解决

- ❌ 精确波特: 12MHz基频下的UART分频除数值未校准
- ❌ 回环测试: 能收能发但收发不同步

---

*一上午从芯片型号到引脚映射全是盲人摸象。LED之前能亮纯粹是几个号撞对了——和"引脚对了"没有任何关系。官方io.pcf救了命。*