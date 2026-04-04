# 🐳 Cloudflare WARP + GOST Docker Proxy

这是一个基于 Docker 的一键部署方案，用于运行 **Cloudflare WARP** 客户端，并通过 **GOST** 开启 HTTP/SOCKS5 代理服务。

本项目旨在提供一个轻量级、高性能的代理工具，支持 Cloudflare WARP 的 Free 模式和 Zero Trust 模式，并允许用户自定义代理认证。

## ✨ 主要特性

- **双重模式支持**：
  - **Free 模式**：使用默认的 WARP 连接，支持通过 `WARP_LICENSE` 开启 WARP+ 流量。
  - **Zero Trust 模式**：支持通过 `WARP_TOKEN` 登录企业/团队网络。
- **多协议代理**：内置 GOST，同时提供 HTTP 和 SOCKS5 代理服务。
- **灵活的认证**：支持设置代理账号密码（可选），保障代理安全。
- **状态监控**：内置健康检查，自动监控 WARP 连接状态。

---

## 🚀 快速开始

### 1. 创建 `docker-compose.yml`

请在你的服务器上新建一个目录，并创建 `docker-compose.yml` 文件，内容如下：

```yaml
version: '3'

services:
  warp-proxy:
    # 使用 liuxcserver/warp-docker-proxy:latest 或  ghcr.io/liuxcserver/warp-docker-proxy:latest
    image: "liuxcserver/warp-docker-proxy:latest"
    container_name: warp-docker-proxy
    hostname: warp-docker-proxy
    ports:
      - "41080:1080" # 映射端口，宿主机:容器
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun # 必须：用于 WARP 隧道
    environment:
      - DEBIAN_FRONTEND=noninteractive
      # --- 核心配置 ---
      
      # 1. Zero Trust 模式 (不填默认Free模式)
      # 登陆 https://[team].cloudflareaccess.com/warp 认证后获取auth接口信息
      # 填入 com.cloudflare.warp:// 开头的 Token
      - WARP_TOKEN=
      
      # 2. Free 模式 License (可选)
      # 填入你的 WARP+ 或 Teams License Key
      - WARP_LICENSE=
      
      # 3. 代理认证 (可选)
      # 如果不填，则代理无需密码即可连接
      - PROXY_USER=
      - PROXY_PASSWORD=

    volumes:
      - ./data:/var/lib/cloudflare-warp # 持久化 WARP 身份数据
      - ./logs:/logs                    # 挂载日志目录
    healthcheck:
      test: ["CMD", "warp-cli", "status"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s
    networks:
      - warp-net
networks:
  warp-net:

```

---

## ⚙️ 配置说明

请根据你的需求修改 `docker-compose.yml` 中的 `environment` 部分。

### 1. 代理认证 (可选)

代理服务的账号密码是**可选**的。

- **开启认证**：填写 `PROXY_USER` 和 `PROXY_PASSWORD`。
- **关闭认证**：将这两个变量留空，任何人都可以通过端口连接代理。

### 2. WARP 模式选择 (二选一)

你需要根据使用场景选择以下其中一种模式：

#### 模式 A：Free 模式 (个人版)
这是默认模式。
- **普通连接**：不填写 `WARP_LICENSE` 和 `WARP_TOKEN` 即可使用。
- **WARP+ 流量**：如果你有 License Key，请填写 `WARP_LICENSE` 变量。

#### 模式 B：Zero Trust 模式 (团队版)
如果你使用 Cloudflare for Teams 网络：
- 请填写 `WARP_TOKEN`。
- **注意**：Token 通常以 `com.cloudflare.warp://` 开头。
- 在此模式下，`WARP_LICENSE` 将被忽略。

### 3. 端口映射

- **`41080:1080`**:
  - 左侧 `41080` 是宿主机端口（外部访问端口）。
  - 右侧 `1080` 是容器内部端口。
  - 你可以根据需要修改左侧端口，例如 `"1080:1080"`。

---

## 🛠️ 维护与调试
#### 启动服务
在 `docker-compose.yml` 所在目录下运行：
  ```bash
  docker-compose up -d
  ```
#### 检查状态
- **查看容器状态**:
  ```bash
  docker ps | grep warp-docker-proxy
  ```
- **查看 WARP 连接状态**:
  ```bash
  docker exec warp-docker-proxy warp-cli --accept-tos status
  ```
- **查看代理日志**:

  ```bash
  docker logs warp-docker-proxy
  ```

#### 代理测试
测试时请将 `your_username` 和 `your_password` 替换为你配置的实际账号密码，或者如果未配置密码则直接留空。
- **HTTP 代理测试**:

  ```bash
  curl -x http://your_username:your_password@localhost:41080 http://ipinfo.io/ip
  ```

- **SOCKS5 代理测试**:

  ```bash
  curl --socks5 your_username:your_password@localhost:41080 http://ipinfo.io/ip
  ```

- **WARP 测试**:

  ```bash
  curl --socks5 your_username:your_password@localhost:41080 https://www.cloudflare.com/cdn-cgi/trace	
  ```
  返回warp=on或者warp=plus代表连接成功
---

## 🛡️ 故障排查

#### 常见问题
- **WARP 连接失败**:
  - 检查 `WARP_TOKEN` 或 `WARP_LICENSE` 配置是否正确。
  - 确认服务器网络可访问 Cloudflare 服务。
- **代理认证失败**:
  - 确认 `PROXY_USER` 和 `PROXY_PASSWORD` 配置一致。
  - 检查客户端代理设置中的认证信息。
- **权限错误**:
  - 确认 Docker 运行用户有权限访问 `/dev/net/tun`。
  - 检查 `cap_add` 配置是否包含 `NET_ADMIN` 和 `SYS_ADMIN`。

#### 日志查看
- **实时查看日志**:
  ```bash
  docker logs -f warp-docker-proxy
  ```
- **查看特定时间段日志**:
  ```bash
  docker logs --since 1h warp-docker-proxy
  ```

---

## 🔄 更新与维护

#### 镜像更新
```bash
docker pull ghcr.io/liuxcserver/warp-docker-proxy:latest
docker-compose down
docker-compose up -d
```

#### 日志清理
内置 `clean-logs.sh` 脚本自动清理过期日志，也可手动执行：
```bash
docker exec warp-docker-proxy /bin/bash /clean-logs.sh
```
---

### 🔒 安全建议

1.  **强密码策略**: 使用复杂密码组合，避免使用默认凭证。
2.  **网络隔离**: 建议将容器部署在专用网络命名空间。
3.  **定期更新**: 及时拉取最新镜像以获取安全补丁。
4.  **访问控制**: 配合防火墙限制代理端口的访问来源。

#  ⚙️Cloudflare Zero Trust 配置指南

---

####  配置入口
登录 Cloudflare Zero Trust 控制台，导航至 `Team & Resources` → `Devices` → `Device profiles`。

####  WARP 连接失败排查
若客户端连接失败，请检查官网配置中使用的协议是否为 `WireGuard`。建议将协议配置调整为 `MASQUE` 协议以提升连接稳定性。

####  手机端连接配置
由于 `MASQUE` 协议暂不支持移动设备，需单独创建适用于手机的配置。

1. 在 `Device profiles` 页面点击 `Create profile`。
2. 填写配置名称与描述。
3. 在 `Build an expression` 部分，设置 `Selector = Operating system`，`Operator = is/in`，`Value = Android/iOS`。
4. 完成设置后，滚动至页面底部点击 `Create profile` 即可。

# 📄 许可证
本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件
