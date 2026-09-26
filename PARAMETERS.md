# c2 / c6：通过 CDN 建立 Xray 反向连接

两个工作流是独立文件，放进目标仓库的 `.github/workflows/`。`c2` 已预填阿里云 ESA，`c6` 已预填 Cloudflare；可以通过 Actions Variables 改换域名。代码中未填入真实 UUID 或加密参数。

结构参考原仓库 `2h.yml`、`6h.yml` 的定时启动和同名任务互斥机制；传输配置参考 hk 的 `/home/ubuntu/docker/xray/config.json`：VLESS、XHTTP、TLS、ALPN h2、fingerprint chrome、flow xtls-rprx-vision。Runner 主动建立反向连接，不监听公网代理端口。

## 已填好的参数

| 参数 | c2（阿里云 ESA） | c6（Cloudflare） |
|---|---|---|
| CDN 地址 `XRAY_ADDR` | `alicdn.datascientist.top` | `cfcdn.datascientist.top` |
| CDN 端口 `XRAY_PORT` | `443` | `443` |
| TLS SNI `XRAY_SERVER_NAME` | `alicdn.datascientist.top` | `cfcdn.datascientist.top` |
| XHTTP 路径 `XRAY_PATH` | `/ws/` | `/ws/` |
| XHTTP 模式 `XRAY_MODE` | `auto` | `auto` |
| Xray 版本 `XRAY_VERSION` | `26.9.9` | `26.9.9` |

无需创建以上参数即可使用默认值。如需换 CDN 或调整参数，在仓库 Actions **Variables** 中创建加上 `C2_` / `C6_` 前缀的同名变量覆盖，例如 `C2_XRAY_ADDR`。若只覆盖地址而不单独设置 SNI，SNI 自动跟随新地址。Xray 版本不带 `v` 前缀。`443` 是 Runner 连接 CDN 的端口，CDN 回源到服务器的 `55555` 由 CDN 配置决定。

## 待填写的 Secrets

位置：仓库 → Settings → Secrets and variables → Actions → Secrets → New repository secret。

**以下四个名称是待填写的表头/占位符，值有意留空，不写入公开仓库。**

| Secret 名称 | 值（待填写） | 定义 |
|---|---|---|
| `C2_XRAY_ID` | | 阿里云这条反向连接在服务端对应用户的 VLESS UUID。 |
| `C2_XRAY_ENCRYPTION` | | 与服务端配套的完整客户端 VLESS encryption 字符串。 |
| `C6_XRAY_ID` | | Cloudflare 这条反向连接在服务端对应用户的 VLESS UUID。 |
| `C6_XRAY_ENCRYPTION` | | 与服务端配套的完整客户端 VLESS encryption 字符串。 |

建议给 c2、c6 各用独立的服务端反向用户，不直接复用正在运行的 hk 用户。若服务端启用了 ML-KEM，不可直接填 `none`，也不可把服务端 decryption 原串复制为 encryption；使用该服务端生成/配套的客户端 encryption。仅服务端 decryption 为 `none` 时填 `none`。

每个工作流对应的两项 Secret 必填。缺失时在下载/启动前失败，只提示参数名称。原有 `XRAY_ADDR`、`XRAY_ID1`、`XRAY_ID2` 等 Secrets 不受影响，新工作流不读取它们。

## 服务端如何对应

工作流中的 `reverse-in-c2` / `reverse-in-c6` 是 **客户端内部路由标签**，在本文件内必须匹配，但不要求与服务端标签同名。

服务端对应的 VLESS 用户需要配置 `reverse.tag`，例如分别为 `out-reverse-c2`、`out-reverse-c6`；服务端 SOCKS 入口的路由 `outboundTag` 指向对应标签。UUID、flow、VLESS encryption/decryption 与 XHTTP 路径必须配套。这里没有替你修改服务端或新增 SOCKS 端口。

逻辑数据方向：lxc 的 SOCKS 入口 → 现有反向连接 → GitHub Runner → 目标网站。因此将来测到的是 **GitHub Runner 出口**，不是 hk 出口。

## 定时安排

- `c2.yml`：`30 */2 * * *`，沿用 `2h.yml`，UTC 偶数小时的第 30 分钟启动；新实例取消旧的 c2 实例。
- `c6.yml`：`0 */5 * * *`，沿用 `6h.yml`，UTC 00、05、10、15、20 点启动；原文件名称虽然叫 6h，实际不是每 6 小时启动。20 点到次日 00 点间隔 4 小时。
- 两者均支持 `workflow_dispatch` 手动启动；单次 Xray 最长运行 350 分钟，job 上限 360 分钟，给下载、校验和退出留出时间。
- 并发组分别是 `c2-run` / `c6-run`，不取消原有 `2h-run` / `6h-run`。
- GitHub 的定时触发可能延迟，不承诺无缝续接。工作流进入默认分支后，定时触发才会生效；请先准备 Secrets。
- 下载失败、配置无效、Xray 异常退出会使任务失败；到 350 分钟的计划超时正常结束。退出时清除临时配置。

## 验证范围

已验证 YAML / Shell / 参数生成逻辑，并用 hk 已有 Xray 26.9.9 的 `-test` 检查无真实凭据的样例配置，返回 Configuration OK。真实 UUID 和 encryption 尚未填写，因此不能据此宣称 GitHub Runner 已与服务端连通。

## 参考

- 原工作流：[2h.yml](https://github.com/felix-git-hub/rdpwrap-autoupdate/blob/master/.github/workflows/2h.yml)、[6h.yml](https://github.com/felix-git-hub/rdpwrap-autoupdate/blob/master/.github/workflows/6h.yml)
- [Xray 26.9.9 XHTTP 模式实现](https://github.com/XTLS/Xray-core/blob/v26.9.9/transport/internet/splithttp/dialer.go)：本版本在 TLS 场景下 `auto` 使用 `packet-up`。
