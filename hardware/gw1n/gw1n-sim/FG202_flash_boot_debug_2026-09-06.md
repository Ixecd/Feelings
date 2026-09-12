# FG202 (GW1N-4B) 上板烧录全记录 —— MODE 陷阱 + apycula 打包 bug

> 日期：2026-09-06（2026-09-07 补充后续决策）
> 一句话结论：新焊的 CJMCU-2232HL 完美工作，但 FG202 上跑自研 Verilog 撞上两道墙——
> ① FG202 板 MODE 引脚 0.96V 中间态导致上电卡死在"空内置 Flash autoboot"，JTAG SRAM 救不回；
> ② apycula(yosys+nextpnr+gowin_pack) 对 GW1N-4B 打包的 bitstream 公共配置头与官方差 224 bit，芯片不进用户模式。
> 最终：**官方 IDE 生成的 fs 在 FG202 上 SRAM/MSPI boot 全通**；自研设计要跑 = 官方 IDE 生成 fs。
>
> 【2026-09-07 更新】官方 IDE 路径探明 + 换 ECP5 决策，详见第 9 章：
> - 高云教育版 Mac 免 License，但**器件库不含 GW1N-4**（只有 GW1N-9C/GW1NSR-4C/GW1NZ-1/GW1N-1P5C）→ create_project 报找不到器件
> - GW1N-4B 需要**商业版 Mac（V1.9.12.03）+ License**（已申请，等 1-3 工作日）
> - gw_sh Tcl 命令行全流程验证通过（教育版跑官方 led_water → 生成官方 fs）
> - 决策：**主路转 Lattice ECP5（已购 Colorlight i5 v7.0，¥333）**，GW1N/FG202 降级为焊接练习板

---

## 0. 目录速览

1. 环境与硬件
2. 完整调试时间线（每步现象 → 判断）
3. 核心发现（要记住的 4 条硬经验）
4. 验证过的命令（可复用）
5. 当前状态 & 接线（MODE 跳线别动！）
6. ~~明天路线~~（历史：orbstack + Gowin Linux，已被 9/7 取代）
7. 待办 / 坑清单
8. 原始分析数据
9. 2026-09-07 补充：官方 IDE 路径验证 + 换 ECP5 决策（新）

---

## 1. 环境与硬件

```
板卡：FG202 核心板（大科电子），FPGA = GW1N-LV4LQ144C6/I5（GW1N-4B，idcode 0x0100381B）
下载器：CJMCU-2232HL (FT2232HL) —— 这次新焊，USB 枚举成功（Dual RS232-HS VID:0x0403 PID:0x6010）
板载串口：CH340N → /dev/cu.usbersial-3140（FPGA IO15 TX / IO12 RX）
时钟：外部 50MHz 晶振 → IO98（官方例程 CLK_50M = IO98）
LED：L1=IO27, L2=IO28（LED_Flash 用 IO27-30 = L1-L4）
MODE 引脚：MODE0=IO144, MODE1=IO143, MODE2=IO142(推测)
外部配置 Flash：W25Q32（连 FPGA MSPI 引脚 MCLK/MCS_N/MO/MI）
工具链：openFPGALoader v1.1.1 (brew) + yosys 0.66 + nextpnr-himbaechel + apycula 0.32/0.33
目标设计：uart_loopback（50MHz/9600，tx=IO15 rx=IO12 led=IO27 err=IO28 clk=IO98）
```

硬件链路（FG202 J1 JTAG 排针 ← 2232HL A 通道，实测过的对应关系）：
```
2232HL(AD0=TCK) → J1-1 (IO14)
2232HL(AD1=TDI) → J1-3 (IO16)
2232HL(AD2=TDO) → J1-5 (IO18)
2232HL(AD3=TMS) → J1-7 (IO13)
GND → GND
```

---

## 2. 完整调试时间线

### 阶段 A：新焊 2232HL + 首次上板烧录

1. 新焊 2232HL 插上，两个电源红灯正常亮（这次焊接成功，340-360°C 铁律生效）
2. USB 枚举确认：
   - `Dual RS232-HS`（VID 0x0403/PID 0x6010）= 2232HL ✓（上次死因就是 D+/D- 不通不枚举）
   - `USB Serial`（VID 0x1A86/0x7523）= 板载 CH340N
3. JTAG detect 成功：
   ```
   openFPGALoader -c ft2232 --ftdi-channel 0 --fpga-part GW1N --detect
   → idcode 0x100381b, manufacturer Gowin, family GW1N, model GW1N-4, irlength 8
   ```
4. SRAM 烧 uart_loopback.fs → `Done DONE / CRC check: Success`，但 **L1/L2 灯全灭**
5. 用 CH340 发 0x55/0xAA/0x5A → 无回显（空）

### 阶段 B：分诊 FPGA 死活（测量没用的坑）

- uart_loopback 里 L2(err)=rx_sync[1]（镜像 RX），L1(led)=hb[25]^rx_led（0.75Hz 心跳，需 50MHz 时钟）
- 两灯全灭有两种解释：没进用户模式（IO 高阻）或 进了但没时钟（寄存器不动）
- 万用表量 IO12/IO15/IO27/IO28 全 ≈ 3.3V
- **坑：这个读数毫无区分力**——8/29 已观察到 FG202 板上 FPGA 死时所有 IO 也 ≈3.23V（板上拉到 3.3V）
- 且 uart_loopback 的 tx 是寄存器输出（上电复位 0），真活着应强驱动 0V，量到 3.3V = IO 三态高阻 → 倾向"没进用户模式"

### 阶段 C：官方例程验证 → 排除用户 bitstream

- 烧官方 LED_Flash.fs（大科电子例程自带，IO27-30 流水灯）→ 灯**依然全灭**
- 结论：不是 uart_loopback.fs 的问题，是 FG202 从来没成功进过用户模式（从 8/29 至今从未见任何设计跑起来）

### 阶段 D：verbose 烧录揭穿真相 —— MODE 中间态卡死

- 手册（UG290 编程配置手册）关键机制：
  ```
  MODE[2:0] 上电采样决定配置模式：
    000 = AUTO BOOT  从内置 Flash 读配置（FG202 出厂设计）
    010 = MSPI       从外部 SPI Flash 读（W25Q32 用这个）
    001 = SSPI / 100 = I2C / 110 = DUAL BOOT(GW1N-4 不支持) / 111 = CPU ...
  JTAG 配置与 MODE 无关（XXX）
  DONE 是双向开漏：外部拉低 DONE = FPGA 卡在唤醒态；DONE 拉高才进用户模式
  ```
- openFPGALoader `-v` 烧录读状态寄存器，发现致命标志全程置位：
  ```
  Non-JTAG configuration is active   ← 一直亮
  （另有 ID Verify Failed / POR 等）
  ```
- 判断：FG202 的 MODE0/1 被板子 10K 电阻分压到 **0.96V 中间态**（既非高也非低），
  上电采样得到一个模糊/错误的 MODE → 芯片按 MODE=000 从**空的内置 Flash autoboot** →
  反复读空 Flash → 卡死在 "Non-JTAG configuration is active" 状态机 → JTAG 写 SRAM（CRC 都过）也救不回。

### 阶段 E：解法一（成功！）—— MODE=010 MSPI + 外部 W25Q32 boot

关键认知：**芯片必须"上电成功 boot"才进用户模式；boot 源无效=卡死，事后 SRAM 补不回来**。
FG202 上电从内置 Flash autoboot（内置是空的，且 openFPGALoader 不支持烧 GW1N-4 内置 Flash），
外部 W25Q32 可以烧（openFPGALoader -f 对 GW1N-4 = 外部 MSPI flash），所以让芯片从外部 boot：

1. 官方 fs 烧进外部 W25Q32：
   ```
   openFPGALoader -c ft2232 --ftdi-channel 0 --fpga-part GW1N -f 02_LED_Flash.fs
   → Erase FLASH → write Flash 100% → CRC check: Success
   ```
2. 跳线改 MODE=010：**IO143(MODE1)→3.3V、IO144(MODE0)→GND**（MODE2 赌内部=0）
3. 断电 → 上电 → **四颗灯流水跑起来了！！** 🎉
   - 外部 50MHz 晶振 + FPGA 用户逻辑 + MSPI boot 全链路打通
   - openFPGALoader 烧录流程对官方 fs 完全有效（SRAM 和 MSPI flash 都行）

### 阶段 F：apycula bitstream 怎么都不跑 —— 第二道墙

1. 重烧 uart_loopback.fs(apycula) 进外部 flash → `CRC check: FAIL / Read 0x00000000`（LED_Flash 每次 Success）
2. 断电重启 → 全灭（boot 失败）
3. 换官方壳（apycula 数据 + 官方注释头 + \r\n）→ SRAM 烧 → 全灭
4. 官方 fs SRAM 覆盖实验：健康运行中烧官方 fs 到 SRAM → **正常流水** = openFPGALoader SRAM 流程有效
5. apycula 极简 io_test（纯组合 led=0/err=0 拉低两 IO，无时钟依赖）→ SRAM 全灭
   → **排除时钟/亚稳态**，坐实 apycula bitstream 芯片不认（不进用户模式，IO 完全不受控）

### 阶段 G：实锤 apycula 打包 bug（公共配置头 224-bit 差异）

- 官方 fs（LED_Run vs LED_Flash，两个官方 IDE 产物）：前 **62901 bit 完全一致**（公共配置头，与设计无关）
- apycula fs（io_test）vs 官方：同一 62901 bit 公共头区有 **224 个差异位**（第一个在 bit 227，mod8/mod16 均匀散布）
- 尾部收尾序列两者几乎一致（177 bit 区只差 1 bit）→ 不是收尾问题
- 官方 .gprj：`<Device name="GW1N-4B" pn="GW1N-LV4LQ144C6/I5">` → FG202 = **GW1N-4B**
- 官方 fs 头属性：`//CRCCheck: ON`、`//SecurityBit: ON`、`//LoadingRate: 2.100MHz`（apycula 打包没有这些概念）
- 升级 apycula 0.32 → 0.33（2026-08-11 gowin_pack 大重写后版本）→ io_test 依然全灭
  → 问题不在 gowin_pack 打包器，在**更深层**：nextpnr-himbaechel 的 chipdb 对 GW1N-4B 的位映射不匹配

### 阶段 H：逆向评估（止损点）

- gowin_unpack 能解自己的 apycula fs（IO27/28 显示为 R13C1_OA/OB 输出，配置"自洽"）但解不了官方 fs
- 要真正定位 224 bit 差异需要 Gowin 专有 bitstream 帧格式 + FPGA Editor 位图参照 → 超出独立逆向可行边界
- **结论：FG202(GW1N-4B) 上跑自研设计 = 用官方 IDE 生成 fs**（唯一确定能成）

---

## 3. 核心发现（要记住的硬经验）

### 3.1 FG202 的 MODE 引脚是"出厂缺陷级"设计
```
- MODE0(IO144)/MODE1(IO143) 被板子 10K 电阻分压到 0.96V = 高不高低不低的中间态
- 后果：上电 MODE 采样模糊 → 芯片按 AUTO BOOT(000) 读空内置 Flash → 卡死
- 8/29 的"SRAM 配置 Done 置位但 IO 不动"的真凶就是它（不是 openFPGALoader 的锅）
- FG202 唯一能稳定跑 = 跳线强制 MODE=010(MSPI) + 外部 W25Q32 烧官方 fs
- FORGET.md 的"傻鸟设计吐槽"再加一条
```

### 3.2 芯片"上电 boot 失败 = 永久卡死，SRAM 救不回"
```
- FG202 只要上电 boot 源无效（空内置/坏外部 flash），芯片就卡在配置状态机
- 之后 JTAG 烧 SRAM（哪怕 CRC Success）也无法让它进用户模式
- 唯一解法：断电 → 保证 boot 源有效（外部 flash 烧官方 fs）→ 重新上电
- 反过来说：想让芯片跑 SRAM 里的东西，得先让它"健康 boot 一次"
```

### 3.3 apycula 对 GW1N-4B 有打包兼容 bug（无法用）
```
- 症状：任何 apycula 生成的 bitstream（连纯组合 IO 输出都算）烧录后芯片不进用户模式
- 证据：公共配置头(前62901bit)与官方差 224 bit；0.32/0.33 都一样
- 推断：nextpnr chipdb(GW1N-4) 与 FG202 的 GW1N-4B 位映射不匹配
- 别在 FG202 上再浪费时间试 apycula 了（除非 apycula 明确修了 GW1N-4B）
- 可选动作：把本记录整理成 apycula GitHub issue（维护者活跃）
```

### 3.4 官方 fs + openFPGALoader = FG202 全通
```
- 官方 IDE 生成的 fs：SRAM 加载、MSPI flash boot 都验证通过
- openFPGALoader 对官方 fs 的处理完全正确（解析注释头 + 校验 CRC）
- 所以拿到官方 fs 后，剩下的烧录链路已经是通的
```

---

## 4. 验证过的命令（可复用）

```bash
# detect
openFPGALoader -c ft2232 --ftdi-channel 0 --fpga-part GW1N --detect

# SRAM 烧录（官方 fs 有效；apycula fs 在这板无效）
openFPGALoader -c ft2232 --ftdi-channel 0 --fpga-part GW1N [-r] xxx.fs

# 烧外部 MSPI Flash（-f 对 GW1N-4 就是外部 W25Q32；对官方 fs CRC Success）
openFPGALoader -c ft2232 --ftdi-channel 0 --fpga-part GW1N -f xxx.fs

# verbose 看状态寄存器（诊断卡死用：看 Non-JTAG configuration is active）
openFPGALoader -c ft2232 --ftdi-channel 0 --fpga-part GW1N -v xxx.fs

# apycula 链（明天不用了，留档）
yosys -p "read_verilog uart_loopback.v; synth_gowin -top uart_loopback -json uart2.json"
nextpnr-himbaechel --device GW1N-LV4LQ144C6/I5 --json uart2.json --write uart_pnr.json --vopt cst=pin.cst
gowin_pack -d GW1N-4 -o uart_loopback.fs uart_pnr.json

# 串口回环测试（CH340）
stty -f /dev/cu.usbserial-3140 9600 raw -echo
# 后台 cat 读，printf '\x55\xAA' 写入
```

---

## 5. 当前状态 & 接线（下次注意！）

```
MODE 跳线（保持！）：IO143(MODE1) → 3.3V，IO144(MODE0) → GND  (= MODE 010 MSPI)
外部 W25Q32 当前内容：最后一次烧的是 apycula uart_loopback（CRC FAIL 那版，无效！）
  → 下次上电会 boot 失败灯全灭 → 先重烧官方 fs（LED_Flash 等）恢复
FG202 板上 98/20/21/22 号孔丝印没标（洞阵有引出但标注不全，别找了）
```

---

## 6. ~~明天路线~~（历史，已被 2026-09-07 取代，见第 9 章）

> 原计划 orbstack + Ubuntu + Gowin Linux，实际发现**教育版有 Mac 版** → 直接 Mac 装教育版，
> 但教育版不支持 GW1N-4 → 需商业版 + License。具体经过见第 9 章。下方是原计划的执行参考（gw_sh 流程已用 Mac 教育版验证等价可用）。

```
目标：用官方 IDE 编译 uart_loopback → 官方格式 fs → 回 Mac openFPGALoader 烧录

步骤：
1. 高云官网注册账号，下载 Gowin Linux x64 版（V1.9.10.03+，比 win 版新）
2. License：先看教育版是否支持 GW1N-4（免 License）；不行申请正式版（1-2 天审批）
3. orbstack 起 Ubuntu 容器（x86_64），安装 Gowin Linux
4. 学 gw_sh 命令行流程：建工程(prj) / 加源(.v + .cst) / 综合+布局 / 生成 .fs
5. 把 .fs 拷回 Mac → openFPGALoader -f 烧外部 flash → 断电上电 → 串口回环测试
   （uart_loopback 的引脚约束在 synth/pin.cst，官方 cst 语法见官方例程 src/*.cst）

注意：
- Gowin IDE 的 .cst 语法和 apycula 的 pin.cst 可能不同（官方例程是标准）
- 官方工程器件型号 = GW1N-LV4LQ144C6/I5（.gprj 里 Device name=GW1N-4B）
- 布局布线后可以用 Gowin Programmer 或直接 openFPGALoader 烧（已验证通）
```

---

## 7. 待办 / 坑清单

- [ ] Gowin Linux 下载 + 教育版 license 确认 GW1N-4 支持
- [ ] 官方 IDE 编译 uart_loopback → MSPI 烧外部 flash → 串口回环验证（最终目标）
- [ ] 尝试把本记录整理成 apycula GitHub issue（GW1N-4B 打包 224-bit 差异），附证据
- [ ] FG202 的 MODE 中间态要不要反馈给大科电子（他们例程能跑 = 他们知道要设 MODE？存疑）
- [ ] dump W25Q32 验证工具（--dump-flash 会卡死超时，openFPGALoader 读这个 flash 有毛病）

坑总结：
1. FG202 板上所有 IO 被统一上拉到 ~3.3V → 万用表量 IO 电压分不清 FPGA 死活
2. openFPGALoader -f 对 apycula fs 报 CRC FAIL 是"真失败"（apycula 数据进不了用户模式），
   对官方 fs 报 CRC FAIL 才可能是读回误报 —— 别再混为一谈
3. openFPGALoader --dump-flash 在 GW1N-4 上会卡死（读回 0x00000000 类问题）
4. 芯片 boot 源无效 = 永久卡死，别指望 SRAM 事后补
5. GW1N-4 内置 Flash：openFPGALoader 不支持烧（只支持 TEC0117/runber/brs-100/epm11），
   官方烧内置要 Gowin Programmer（Windows/Linux）


---

## 8. 原始分析数据

### fs 结构对比（官方 vs apycula）
```
官方 fs：ASCII // 注释头（含 Device: GW1N-4 / Device Version: B / Part Number: GW1N-LV4LQ144C6/I5
        / CRCCheck: ON / SecurityBit: ON / CheckSum: 0xFBDF 等）+ 数据区
apycula fs：无注释头，纯数据区
数据区两者格式一致：ASCII '0'/'1' 每 bit 一个字符 + 换行（官方 \r\n，apycula \n）
官方文件 = apycula 文件 + 注释头(539B) + 510 个 \r
```

### 公共配置头差异
```
官方 LED_Run vs 官方 LED_Flash：前 62901 bit 完全一致（公共配置头，与设计无关）
apycula io_test vs 官方：62901 bit 公共头区内 224 个差异位
  第一个差异 bit 227；mod8 均匀(20-39)、mod16 均匀(8-23) → 不是缺字段，是打包流程性差异
尾部：官方从 bit 1166607 起公共收尾(177bit)，apycula 只差 1 bit → 收尾不是问题
```

### gowin_unpack 结果
```
gowin_unpack -d GW1N-4 -o unpack.v io_test.fs → 成功，IO27/28 配置为输出(R13C1_OA/OB)，"自洽"
gowin_unpack 解官方 fs → ValueError("Unsupported device") 解不了
```

### 关键器件/版本信息
```
FG202 FPGA：GW1N-4B（官方 .gprj: <Device name="GW1N-4B" pn="GW1N-LV4LQ144C6/I5">gw1n4b-011</Device>）
idcode：0x0100381B（openFPGALoader 注释 = GW1N-4B）
apycula chipdb GW1N-4 提取自 partnumber GW1N-LV1LQ144C6/I5（LV1 vs FG202 的 LV4，电压档标注差异）
apycula 版本线：0.32(2026-04-07) → gowin_pack 重写(2026-08-11) → 0.33(2026-08-25)，均不解决
```

### 关键文件位置
```
/Users/qc/Feelings/hardware/gw1n/gw1n-sim/uart_loopback.v          # 目标设计
/Users/qc/Feelings/hardware/gw1n/gw1n-sim/synth/uart_loopback.fs   # apycula 产物（无效）
/Users/qc/Feelings/hardware/gw1n/gw1n-sim/synth/pin.cst            # apycula 引脚约束
/tmp/fg202_ex/02_LED_Flash/impl/pnr/02_LED_Flash.fs           # 官方可用 fs（流水灯）
/tmp/fg202_ex/01_LED_Run/impl/pnr/LED_Run.fs                  # 官方可用 fs
/tmp/io_test/io_test.fs / io_test_v33.fs                      # apycula 诊断（无效）
~/Downloads/Gowin FG202 Data Pack/                            # 官方资料（原理图/例程/win 版 IDE）
```

---

## 9. 2026-09-07 补充：官方 IDE 路径验证 + 换 ECP5 决策

> 9/6 记录了"自研设计 = 官方 IDE 生成 fs"的结论，9/6 晚~9/7 实际走了官方 IDE 路径，
> 撞上"教育版不支持 GW1N-4"这第三道墙，最终决定换 Lattice ECP5。本页把过程补全。

### 9.1 高云官方 IDE 的获取排查（具体问题记录）

**好消息**：高云官方 IDE 有 **Mac 版**（官网软件页有 MAC 标签），教育版免 License。
下载：`Gowin_V1.9.11.03Education_macOS.dmg`(654MB)，挂载后是 `GowinIDE.app`，拖进 /Applications。
```
安装位置：/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/
  IDE/bin/gw_sh        ← 命令行 Tcl console（无头综合的关键）
  IDE/bin/gowinide     ← GUI
  IDE/data/device/*.csv ← 教育版支持器件库
  IDE/data/examples/   ← 官方例程（led_water/FIFO_HS/...）
  IDE/doc/CN/*.pdf     ← 自带文档（SUG918 快速入门等）
```

**运行 gw_sh 需要动态库环境**（app 自带 env.zshrc）：
```bash
export DYLD_FRAMEWORK_PATH=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/lib
export DYLD_LIBRARY_PATH=/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA/IDE/lib
/Applications/.../Gowin_EDA/IDE/bin/gw_sh [script.tcl]   # 无参数=交互，带参数=跑脚本
```
（有 OpenGL/Chromium 软件渲染警告，纯命令行综合无影响，忽略）

**gw_sh Tcl 命令行流程**（SUG918 快速入门第 4 章）：
```tcl
# 新建工程：-pn 器件 pn，可带 device_version（仅器件有多个 silicon 版本时需要）
create_project -name NAME -dir DIR -pn GW1N-LV9LQ144C6/I5 device_version C
import_files -file "path/xxx.v"          # 逐个导入源/约束
import_files -file "path/xxx.cst"
set_option -output_base_name NAME
set_option -top_module TOP
set_option -synthesis_tool gowinsynthesis
set_option -verilog_std sysv2017
run all                                  # 综合+布局布线+bitstream 一键
# 对已有工程(.gprj)：open_project /path/xxx.gprj 后 run all
```

### 9.2 第三道墙：教育版不支持 GW1N-4

对 FG202 跑 create_project 时：
```
create_project ... -pn GW1N-LV4LQ144C6/I5 device_version B
→ "The target device does not have device version"
去掉 device_version / 加 -device_version B 变体全试：
→ "can't find device: GW1N-LV4LQ144C6/I5" 或 同上
```

根因（不是语法问题）：**教育版器件库不含 GW1N-4**。
证据：`IDE/data/device/device_info.csv` 里 GW1N 家族只有 8 个条目：
```
gw1nz1-015     GW1NZ-LV1QN48C6/I5      ← 教育版有
gw1nsr4c-000   GW1NSR-LV4CQN48PC6/I5   ← 教育版有
gw1n9c-000/003 GW1N-LV9QN48C6/I5 等    ← 教育版有（9C 多封装）
gw1n9c-017     GW1N-LV9LQ144C6/I5
gw1n1p5c-020   GW1N-UV1P5QN48XFC7/I6   ← 教育版有
# GW1N-4 / GW1N-4B 完全不在列表  ← 用户 FG202 芯片！
```
教育版（Education）"不需要 License，但支持的芯片型号有限制"——GW1N-4 不在限制内支持范围。

### 9.3 商业版路径 + License 申请（FG202 唯一官方路）

- **商业版 For Mac V1.9.12.03**：dmg 873MB，官网软件页"云源软件商业版"→ MAC 标签下载
- **License**：免费申请，绑定**本机 MAC 地址**，审核 1-3 工作日，邮件发 license 文件
  ```
  官网 License 表单填写：
    MAC 地址（本机真实网卡）：
      ac:07:75:10:71:95   (en0 硬件 MAC，主)
      36:60:12:30:3f:c0   (en1，可一并填，空格分隔)
    License 类型：单机型(Node-locked)
  状态：2026-09-07 已提交，等审核邮件
  ```
- license 到了：装商业版 → 放 license → create_project 用 GW1N-LV4LQ144C6/I5 编译 uart_loopback → openFPGALoader 烧（链路已验证通）

### 9.4 命令行流程验证通过（教育版 led_water 例程）

用教育版跑官方例程验证 gw_sh 全流程（验证器件用 GW1NSR-4C，教育版支持）：
```
把 IDE/data/examples/led_water 拷到可写目录
run.tcl:  open_project /path/led_water.gprj
          run all
→ Placement/Routing/Timing/Bitstream generation 全 completed
→ 生成 impl/pnr/led_water.fs，文件头 "//Copyright (C)... Gowin Semiconductor" = 官方格式 ✓
结论：open_project + run all 命令行流程完全可用（等价于 GUI）
```

### 9.5 决策：换 Lattice ECP5（GW1N 主路放弃）

**换的理由**（综合权衡，非一时冲动）：
```
① apycula 对 GW1N-4B 打包 bug 无法用（224-bit 差异，已实锤）
② Gowin 官方 IDE 门槛高：教育版砍器件(没 GW1N-4)、商业版要 license(一年一续)
③ 换板成本低：ECP5 生态 = iCE40 同源(yosys/nextpnr-trellis 开源免 license，Mac 全通)
④ 长期迭代舒适度：ECP5 每次改逻辑重新综合烧录零门槛
⑤ 选芯片 = 选生态，不是选芯片参数（本次最大教训）
```

**GW1N/FG202 的归宿**：不浪费——license 到了烧通一次收尾（不留半截），
之后**转职为"焊接练习板"**（FG202 满板洞阵，练排针/飞线正合适）。

### 9.6 ECP5 目标板：Colorlight i5 v7.0（已购 ¥333 含底板+模组）

**i5 v7.0 规格**（wuxx 仓库确认，`github.com/wuxx/Colorlight-FPGA-Projects`）：
```
FPGA：LFE5U-25F-6BG381C（ECP5 25F，24K LUT，BGA381 出厂贴好）
SDRAM：EM638325BK-6H 8MB
SPI Flash：GD25Q16CSIG 2MB（配 flash；注意仓库提示 GD25Q16 有锁定问题，可换 W25Q 系）
PHY：Broadcom B50612D ×2（千兆，Feelings 用不上，以后可玩 LiteX/以太网）
引出：DDR2 SODIMM 200P 金手指 → 底板引出 GPIO
时钟：25MHz
底板带 DAPLink(JTAG+CDC串口)，openocd/dapprog 烧录
```

**i5 生态要点**：
```
- 工具链：yosys + nextpnr-trellis + prjtrellis + openFPGALoader（全开源，Mac brew，无 license）
- 与 iCE40 同一套 yosys/nextpnr 工作流 → 技能无缝迁移
- 社区：wuxx/q3k(chubby75)/kholia，能跑 LiteX/RISC-V
- 烧录：底板 DAPLink → openocd；或 FT2232HL(2232HL) / ST-Link刷CMSIS-DAP 也能用
- 待办：i5 到货后 Mac 配工具链（brew 装 nextpnr-trellis + openFPGALoader 已装）
```

### 9.7 音频单元决策（I2S 背板）

```
方向：第一阶段入耳播声音/节律做刺激（输出），留口子以后环境声采集（输入）
关键决定：音频总线直接定 I2S（双向协议）
  输出 → MAX98357A(I2S 功放，一芯片含 DAC+功放) → 入耳单元
  输入(以后) → ICS-43434(I2S 麦) 复用 BCLK/LRCLK + 一根 DIN → 架构零改动
环境声归属建议：若做"随环境节律同步刺激"，麦克风进执行端 FPGA(ECP5) 同芯片闭环 DSP，
  别放采集端跨芯片传（延迟/同步麻烦）
影响选型：音频(几百 LUT + 几个 DSP)不构成 FPGA 升档压力，25F 绰绰有余
```

### 9.8 阶段定位 & 更新路线

**定位**：现在是"跑通闭环"阶段（开发板飞线 → 传感器→决策→刺激回环能响）。
原型/做小是几个月后的事，闭环跑完前不做任何选型/尺寸决定（第②阶段会推翻早期假设）。

```
闭环 7 级台阶：
① 采集端收发    ✅ iCE40 UART 回环已通
② 执行端烧录    ⏳ FG202 官方 fs 烧通（等商业版 license）→ 之后 GW1N 转焊接练习板
                （主路切 ECP5：等 i5 到货 → Mac 工具链 → ECP5 跑同样逻辑）
③ 传感器读数    MAX30102/MPU6050 → iCE40 I2C 读真实值
④ 帧桥          iCE40 发帧 → 执行端收帧 + CRC
⑤ 决策          最简漏桶(先单维) → 阈值 → 触发
⑥ 刺激          LM334 恒流源 + 1K+100nF 等效负载（铁律：不碰人体）
⑦ 声音          I2S 播节律音（MAX98357A → 入耳）
```

**更新待办**：
- [ ] 等 Gowin 商业版 License（1-3 工作日）→ 收尾烧通 FG202 一次
- [ ] 等 Colorlight i5 v7.0 到货 → Mac 配 ECP5 工具链（brew: yosys/nextpnr-trellis 已有则验证）
- [ ] ECP5 上跑 uart_loopback（同 Verilog，换 Lattice 约束）→ 串口回环
- [ ] 音频链：i5 出 I2S → MAX98357A → 入耳 播节律音
- [ ] apycula GW1N-4B 打包 bug 整理成 GitHub issue（附本记录证据，可选）
- [ ] FG202 的 MODE 中间态问题反馈大科电子（可选）

