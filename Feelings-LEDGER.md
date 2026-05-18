# 存储池账本——有链的不可篡改，没有链的负担

> 作者：qc
> 日期：2026-05-18
> 性质：Feelings 财务透明基础设施，GOVERNANCE 红线执行层
> 核心：一条 JSONL 文件 + 一条哈希链 + GPG 多签 = 不需要共识的密码学审计账本

---

## 零、定位

Feelings 不上公链，也不建私链。

但工资要发。创作者分成要结。存储池资金进出要对得上。这些事情需要的不是区块链，是一个**只有哈希链、没有共识层**的密码学账本。

SPL（Storage Pool Ledger）就是那个东西。

```
公链        共识 + 哈希链 + 网络 + 代币
私链        共识 + 哈希链 + 网络
SPL         哈希链 + 签名
            只拿需要的，不背不需要的
```

---

## 一、为什么不需要共识层

```
共识层在公链里做的事
    全网节点对同一笔交易达成一致
    防止双花
    防止恶意节点篡改

Feelings 的账本不需要这些
    双花不存在——一笔工资只发一次，接收方只有一个人
    恶意节点不存在——只有 Feelings 自己在写账本
    全网一致不存在——只有一份文件，没有不同拷贝需要协调

    一个人记账，只需要证明「我没改过」。
    不需要证明「全网都同意我没改过」。
```

**哈希链证明不可篡改，多签证明授权。两项加在一起，什么都不缺。**

---

## 二、结构

### 2.1 物理结构

```
Feelings-Ledger/（Git 仓库，私有）
    ledger/
        YYYY/
            MM.jsonl           当月全部记录
            MM.sig             当月 GPG 签名文件
        YYYY.jsonl              全年汇总（按月追加）
    mirrors/
        bank/                   银行对账单（PDF → TXT）
        exchange/               汇率记录（用于涉外结算）
        fee/                    手续费明细
    verify.sh                   验证脚本
    README.md
```

### 2.2 记录结构

```jsonl
{"index":1,"prev_hash":"0000000000000000000000000000000000000000000000000000000000000000","timestamp":"2026-06-01T10:00:00Z","type":"salary","recipient":"0x7a3f...","amount":"15,000","currency":"CNY","category":"engineering","from_pool":"ICBC_operations","approval_ref":"multi-sig-042","note":"2026年6月工资 - 后端工程师"}
```

字段：

```
index           自增序号，从 1 开始
prev_hash       上一条记录内容的 SHA-256（首条为全零）
timestamp       交易时间（ISO 8601）
type            交易类型（salary / creator_payout / ops / transfer / interest_in）
recipient       接收方标识（链上地址或员工 ID）
amount          金额
currency        币种（CNY / USD / SGD / EUR）
from_pool       来源池（见 storage-pool-governance.md）
approval_ref    多签审批编号
note            备注
```

### 2.3 哈希链规则

```
hash = SHA-256(
    index +
    prev_hash +
    timestamp +
    json_payload_without_prev_hash
)

规则
    1. 每条记录的 prev_hash = 上一条记录的 hash
    2. 首条记录的 prev_hash = 0 × 64（64 个零字符）
    3. 修改任何一条记录的任何字段 → 该条 hash 变化
       → 下条 prev_hash 对不上 → 整条链断裂
    4. 从头重算所有 hash，只要最后一条对得上，整条链无篡改
```

---

## 三、签名与多签

### 3.1 签名格式

```
每月的 MM.jsonl 文件生成后，由对应权限的多签授权人 GPG 签名。

MM.sig 文件内容（明文，一行一条）：
    record_index:signer_id:gpg_signature

例：
    1:admin_alice:-----BEGIN PGP SIGNATURE-----...-----END PGP SIGNATURE-----
    1:admin_bob:-----BEGIN PGP SIGNATURE-----...-----END PGP SIGNATURE-----
```

### 3.2 分级多签（对接存储池治理）

规则见 `docs/storage-pool-governance.md`。SPL 严格按照此规则执行：

```
金额范围                    所需签名
─────────                  ─────────
< 50,000 CNY               单人（财务主管）
50,000 - 500,000 CNY       双人（财务主管 + CEO）
500,000 - 5,000,000 CNY    三人（财务主管 + CEO + 治理委员会成员）
> 5,000,000 CNY            三人 + 对外公示 72 小时冷静期

每笔记录写入前必须满足对应签名数量。
签名为零的记录不写入——「先签名，后入账」。
```

---

## 四、交易类型

### 4.1 salary（工资发放）

```
来源        所在存储池
金额        税前工资
时间        月度固定日期
备注        岗位 + 部门
验证        员工可自行核对
```

### 4.2 creator_payout（创作者分成）

```
来源        Feelings-Store 收益池
金额        实时结算（见 Feelings-TOKENOMICS.md 第二节）
时间        实时
备注        感受包 ID + 使用次数
```

### 4.3 ops（运营支出）

```
来源        硬件收益池
金额        支出金额
时间        支出时
备注        用途说明（服务器 / 设备生产 / 物流 / 合规费用）
```

### 4.4 transfer（池间划转）

```
来源        from_pool
目标        to_pool
金额        划转金额
时间        划转时
备注        划转原因
```

### 4.5 interest_in（利息入账）

```
来源        长久池增值收益
目标        长久池
金额        当期利息
时间        按银行对账周期
备注        来源银行 + 对账单索引
```

---

## 五、验证

### 5.1 验证脚本

```sh
#!/bin/sh
# verify.sh — 校验 SPL 哈希链完整性
# 用法：./verify.sh ledger/2026.jsonl

set -e

EXPECTED="0000000000000000000000000000000000000000000000000000000000000000"
INDEX=0

cat "$1" | while IFS= read -r line; do
    INDEX=$((INDEX + 1))

    PH=$(echo "$line" | jq -r '.prev_hash')
    if [ "$PH" != "$EXPECTED" ]; then
        echo "CHAIN BREAK at index $INDEX"
        echo "  expected: $EXPECTED"
        echo "  got:      $PH"
        exit 1
    fi

    # 去掉 prev_hash 后计算本条的 hash
    HASH=$(echo "$line" | jq -c 'del(.prev_hash)' | sha256sum | awk '{print $1}')
    EXPECTED="$HASH"
done

echo "Ledger OK: $INDEX records verified. Last hash: $EXPECTED"
```

### 5.2 员工验证

```
员工收到工资后，可以自己验证：
    1. git pull Feelings-Ledger
    2. ./verify.sh ledger/2026.jsonl
    3. 找到自己那条记录，确认金额和时间

如果 verify.sh 报 CHAIN BREAK，说明账本被修改过。
员工不需要信任任何人——自己跑脚本，自己算 hash。
```

### 5.3 GPG 签名验证

```sh
#!/bin/sh
# 验证当月记录的签名
gpg --verify ledger/2026/06.sig ledger/2026/06.jsonl
```

---

## 六、镜像与备份

### 6.1 银行对账

```
每月银行对账单（PDF）→ 转 TXT → 存入 mirrors/bank/
和 ledger/YYYY/MM.jsonl 做逐笔对账

对不上怎么办：
    1. 标记为「待查」，记录差异
    2. 查明后补一条 correction 类型的记录
    3. correction 记录上链，写明原因
    4. 不删除、不覆盖原记录

允许纠正，不允许隐藏。
```

### 6.2 多地镜像

```
主仓库       github.com/Ixecd/Feelings-Ledger（私有）
镜像一       Feelings 内部 NAS
镜像二       异地冷存储（季度同步）
```

### 6.3 备份频率

```
每月              当月 .jsonl 生成 + 签名 + push
每季度            全量备份至异地冷存储
每年             全年汇总 .jsonl 生成 + 验证 + 归档
```

---

## 七、与公链的关系：不排斥，不依赖

SPL 不依赖任何公链。但如果未来出现以下场景，可以在 SPL 之上叠加公链存证：

```
叠加方式（非替代）
    SPL 每月生成的 .jsonl 文件
    → 整体计算一个 merkle root
    → merkle root 打入某条公链（不存数据，只存哈希）

    这样公链上的人可以验证「这个 merkle root 对应某个月的账本」，
    但账本的具体内容不在公链上。公开范围由 Feelings 自己控制。

此时公链做的事：
    一个远程、不可篡改的哈希存证点。
    不是共识层，不是结算层，只是一个哈希锚点。
```

---

## 八、SPL 不做的

```
不发行代币
    和 FEEL 代币无关（FEEL 如果存在，它的流转走其他通道）

不自动化
    记账是手动写入的（对接银行实际流水），不是智能合约自动执行
    自动执行发生在银行多签层面，不在 SPL 层面

不替代银行
    SPL 是账本，不是金库。资金在银行里，SPL 记录银行的流水。

不做匿名
    SPL 是内部透明的财务工具，不追求隐私币的那套逻辑
    对外公开时可脱敏，但脱敏前的内部版本是完整实名的

不部署节点
    没有节点软件，没有 p2p 网络，没有 RPC 接口
    SPL 是一个 Git 仓库 + 一个 JSONL 文件 + 一套 verify 脚本
    不需要 Docker Compose，不需要运维手册
```

---

## 九、和现有文档的关系

```
Feelings-LEDGER.md（本文档）        SPL 账本设计
Feelings-TOKENOMICS.md             商业治理与存储池设计
Feelings-PROTOCOL.md               审计日志上链要求
docs/storage-pool-governance.md    存储池多签与银行分配规则
docs/data-ownership-and-destruction.md  财务数据不在此范围内
```

---

```
区块链    共识驱动信任 → 需要网络、节点、代币、经济激励
SPL       哈希驱动验证 → 需要一个文件、一个脚本、一份签名

都是不可篡改的。
方式不同。
选那个只做你需要的事的。
```

---

*不发币，不建链，不跑节点。一个 JSONL 文件 + 一条哈希链 + 一套多签。工资透明，就这么简单。*
