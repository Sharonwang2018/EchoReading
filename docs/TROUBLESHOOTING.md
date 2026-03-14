# 常见问题

## 扫码页面黑屏

手机通过 HTTP 访问时，浏览器出于安全策略不允许使用相机（`getUserMedia` 需要 HTTPS）。

**解决**：用 HTTPS 访问，见下方「存书 Load failed」的 ngrok 或 mkcert 方案。

## `ClientException: Load failed` / 存不了书

iPhone 访问自签名证书（`https://10.0.0.138:3000`）时，页面能打开但 `fetch` 请求常被拒绝，导致扫码可 succeed、存书失败。

### 方案一：ngrok（推荐，最快）

无需在手机上安装证书：

1. 安装 ngrok：`brew install ngrok` 或从 https://ngrok.com 下载
2. 终端 1 启动服务：`./run_all.sh`（或 `cd api && HTTPS=1 npm start`）
3. 终端 2 运行：`./scripts/run_with_ngrok.sh`
4. 手机浏览器访问 ngrok 输出的 `https://xxx.ngrok-free.app`（扫码和存书均可用）

### 方案二：mkcert + iPhone 信任证书

1. Mac 上：`brew install mkcert && mkcert -install`
2. 重新生成证书：`./scripts/gen_certs.sh`
3. 将 mkcert 根证书传到 iPhone：`open $(mkcert -CAROOT)`，用 AirDrop 发送 `rootCA.pem` 到手机
4. iPhone 上：点击 `rootCA.pem` 安装描述文件 → 设置 → 通用 → 关于本机 → 证书信任设置 → 启用该根证书
5. 手机访问 `https://10.0.0.138:3000`

### 其他检查

- 确认 API 已启动，手机与电脑在同一 WiFi
- `10.0.0.138` 需为本机局域网 IP（`ipconfig getifaddr en0` 查看）
