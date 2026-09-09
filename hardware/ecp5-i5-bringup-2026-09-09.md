# Colorlight i5 (ECP5-25F) Bringup —— 一次跑通的开源 FPGA 链路

> 日期：2026-09-09
> 一句话结论：GW1N/FG202 折腾两天（apycula 打包 bug + 官方 IDE license 门槛）后，转 Lattice ECP5。
> i5 到手当天：detect 芯片 → blinky 合成 → 烧录 → 板载 LED 闪（~0.75Hz）——**全程开源、免 license、Mac 原生、一次跑通**。
> **状态：基本放弃 GW1N（Gowin 商业版 License 还没发到邮箱，也不打算等了）。主路切 ECP5。**

---

## 1. 环境与硬件

```
板卡：Colorlight i5 v7.0（wuxx 仓库：github.com/wuxx/Colorlight-FPGA-Projects）
FPGA：LFE5U-25F-6BG381C（ECP5 25F，24K LUT，CABGA381）
下载：底板带 DAPLink（USB 枚举为 "DAPLink CMSIS_DAP"，VID 0x0d28 / PID 0x0204）
时钟：25MHz → 引脚 P3
板载 LED：D2 → 引脚 U16（i5 v7.0 有一颗，可用它验证 blinky）
SPI Flash：GD25Q16CSIG 2MB（注意 wuxx 仓库提示 GD25Q16 有锁定问题，可换 W25Q 系）
其他（Feelings 用不上）：SDRAM EM638325 8MB、B50612D 千兆 PHY ×2
```

## 2. 工具链（对比 GW1N 的关键差异）

```
GW1N 链：yosys + nextpnr-himbaechel + apycula gowin_pack   → apycula 对 GW1N-4B 打包 bug
ECP5 链：yosys + nextpnr-ecp5 + prjtrellis(ecppack)        → 全开源成熟，一次跑通

brew 已有：yosys、prjtrellis（ecppack/ecppll/ecpmulti）
brew 缺：nextpnr-ecp5（brew 没有此 formula）
   → 用 oss-cad-suite 预编译包（含全套）：
     下载：github.com/YosysHQ/oss-cad-suite-build/releases
     最新 2026-09-09：oss-cad-suite-darwin-arm64-20260909.tgz（520MB）
     解压到 ~/oss-cad-suite/oss-cad-suite/，bin 加 PATH
   → oss-cad 内含：yosys / nextpnr-ecp5 / ecppack / openFPGALoader(完整版)

【坑1】brew 的 openFPGALoader 没编 cmsisdap 支持（报 "support for cmsisdap was not enabled"）
   → 用 oss-cad-suite/bin/openFPGALoader（完整编译）
【坑2】新版 ecppack 不吃 nextpnr 的 json，吃 --textcfg 文本配置
   → nextpnr 加 --textcfg x.config 输出，再 ecppack x.config x.bit
【坑3】nextpnr-ecp5 package 名要用 CABGA381（不是 BG381）
```

## 3. blinky 完整流程（可复用命令）

```
/tmp/ecp5_hello/blinky.v:
    module blinky(input clk, output led);
    reg [24:0] cnt;
    always @(posedge clk) cnt <= cnt + 1;
    assign led = cnt[24];
    endmodule

blinky.lpf（ECP5 用 .lpf 约束，不是 .cst）:
    BLOCK RESETPATHS;
    BLOCK ASYNCPATHS;
    LOCATE COMP "clk" SITE "P3";
    IOBUF PORT "clk" IO_TYPE=LVCMOS33 PULLMODE=NONE;
    LOCATE COMP "led" SITE "U16";
    IOBUF PORT "led" IO_TYPE=LVCMOS33 DRIVE=8;
    FREQUENCY PORT "clk" 25 MHz;

export PATH=~/oss-cad-suite/oss-cad-suite/bin:$PATH
yosys -p "synth_ecp5 -top blinky -json blinky.json" blinky.v
nextpnr-ecp5 --json blinky.json --lpf blinky.lpf --25k --package CABGA381 --freq 25 --textcfg blinky.config
ecppack blinky.config blinky.bit
openFPGALoader -c cmsisdap blinky.bit        # SRAM 烧录
# openFPGALoader -c cmsisdap -f blinky.bit    # 烧 SPI flash（GD25Q16 有锁定坑，见上）
```

验证：detect → idcode 0x41111043（LFE5U-25）；烧录 Loading 100% + Disable configuration: DONE；
板载 LED D2 以 ~0.75Hz（1.3s 周期）闪 ✓（25MHz/2^25 吻合）。

## 4. 为什么弃 GW1N 转 ECP5（记录在案）

```
GW1N/FG202 三道墙：
① MODE 引脚 0.96V 中间态 → 上电卡死（已绕开：MODE=010 MSPI + 外部 W25Q32）
② apycula 对 GW1N-4B 打包 bug → 公共配置头 224-bit 差异，芯片不进用户模式（无解）
③ 官方 IDE 门槛 → 教育版砍器件(无 GW1N-4) / 商业版要 License(已申请，绑定 MAC，
   1-3 工作日发邮箱——2026-09-09 仍未收到，也不打算等)

ECP5 对比：开源链成熟(prjtrellis/nextpnr-trellis)、免 license、Mac 原生、
  与 iCE40 同源(yosys/nextpnr 一套工作流)、社区大(wuxx/q3k)、
  24K LUT + DSP/BRAM 足够 Feelings 执行端
→ 主路切 ECP5。GW1N/FG202 降级为焊接练习板（license 到了也不投入）。
```

## 5. 待办 / 下一步

```
- [ ] ECP5 上跑 uart_loopback（同 Verilog，换 Lattice 约束）→ 串口回环
      （i5 串口：底板 DAPLink 带 CDC 串口，或用 UART 引脚 + 外接）
- [ ] blinky 烧 SPI flash（上电自启）——注意 GD25Q16 锁定问题（wuxx 仓库有解法）
- [ ] 接 Feelings 执行端逻辑（ESIR 漏桶/看门狗在 ECP5 上）
- [ ] 音频 I2S 链（MAX98357A → 入耳）
- [ ] 双板联调（iCESugar iCE40 采集 ↔ i5 ECP5 执行）：先 UART/SPI 点对点，不上 CAN
```

## 6. 关键文件位置

```
~/oss-cad-suite/oss-cad-suite/bin/           # ECP5 工具链（nextpnr-ecp5/ecppack/openFPGALoader 完整版）
/tmp/ecp5_hello/blinky.v + blinky.lpf + blinky.bit   # 首个跑通的设计
/tmp/Colorlight-FPGA-Projects/                # wuxx 仓库（i5 v7.0 引脚/资料）
/Users/qc/Feelings/hardware/FG202_flash_boot_debug_2026-09-06.md   # GW1N 折腾全记录（对照用）
```
