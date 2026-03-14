# 登录与 CloudBase 配置

Hi-Doo 绘读 使用 **腾讯云开发 CloudBase Auth**，支持用户名密码登录/注册。

## 环境变量

| 变量 | 说明 |
|------|------|
| `CLOUDBASE_ENV_ID` | 云开发环境 ID |
| `CLOUDBASE_APP_ACCESS_KEY` | 应用访问凭证 Key |
| `CLOUDBASE_APP_ACCESS_VERSION` | 应用访问凭证 Version |

## 用户名密码登录

1. 部署云函数 `authUserPass`（见 `functions/authUserPass/`）
2. 下载自定义登录私钥，重命名为 `tcb_custom_login.json` 放入云函数目录
3. 在 CloudBase 控制台创建 `users` 集合
4. 建议为 `username` 字段创建唯一索引

### 用户名规则

- 2-48 位，字母或数字开头
- 支持字符：字母、数字、`-_.:+@`

### 密码规则

- 6-32 位

## 用户同步

登录成功后，用户信息自动同步到 `users` 集合。

## 数据库集合

- `books`：书籍信息
- `read_logs`：阅读记录
- `users`：用户信息（username、password_hash、登录后同步）
tovi