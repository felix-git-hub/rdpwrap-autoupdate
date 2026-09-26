# c2 / c6 参数定义

所有部署参数均在仓库 Settings → Secrets and variables → Actions → Repository secrets 中配置。工作流只引用 Secret 名称，不包含实际连接地址、端口、路径或凭据，也不读取 Actions Variables。

下表不展示实际值。c2 对应阿里云 CDN，c6 对应 Cloudflare CDN。

| c2 Secret 名称 | c6 Secret 名称 | 定义 |
|---|---|---|
| `C2_XRAY_ADDR` | `C6_XRAY_ADDR` | CDN 连接域名，不含协议与路径 |
| `C2_XRAY_PORT` | `C6_XRAY_PORT` | Runner 连接 CDN 的端口，不是回源端口 |
| `C2_XRAY_SERVER_NAME` | `C6_XRAY_SERVER_NAME` | TLS SNI，需与 CDN 证书匹配 |
| `C2_XRAY_PATH` | `C6_XRAY_PATH` | XHTTP 路径，与服务端一致 |
| `C2_XRAY_MODE` | `C6_XRAY_MODE` | XHTTP 传输模式 |
| `C2_XRAY_VERSION` | `C6_XRAY_VERSION` | Xray 版本号，不带 v 前缀 |
| `C2_XRAY_ID` | `C6_XRAY_ID` | 待填写：服务端对应反向用户的 VLESS UUID |
| `C2_XRAY_ENCRYPTION` | `C6_XRAY_ENCRYPTION` | 待填写：与服务端配套的客户端 encryption |

上述参数全部必填，缺失时工作流在启动前失败，仅报告缺失名称。未知凭据只列出名称，不填虚假占位值，也不写进公开文件。

服务端需要为两条连接配置对应的反向用户和路由。建议使用独立 UUID，避免复用正在运行的反向客户端。客户端 encryption 必须与服务端 decryption 配套，两者不应直接互相复制。

c2、c6 的客户端内部路由标签分别为 reverse-in-c2、reverse-in-c6，不要求与服务端标签同名。服务端入口经反向连接访问 GitHub Runner，由 Runner 连接目标网站。

定时安排沿用原 2h.yml、6h.yml；c2 每两小时启动，c6 使用每五小时的 cron（UTC 20 点到次日 00 点间隔四小时）。新实例仅取消同组旧实例。单次最多运行 350 分钟，也支持手动启动。GitHub 定时触发可能延迟。

真实凭据补齐前，只能验证语法和配置结构，不能据此确认反向连接成功。
