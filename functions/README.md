# CloudBase 云函数

## authUserPass（用户名密码登录/注册）

支持 `register` 和 `login`，用户信息存储在 `users` 集合。

### 部署步骤

1. 登录 [CloudBase 控制台](https://console.cloud.tencent.com/tcb)
2. 进入云函数，新建函数 `authUserPass`
3. 上传 `authUserPass` 目录代码
4. 下载自定义登录私钥（控制台 → 登录设置 → 生成私钥），重命名为 `tcb_custom_login.json` 放入函数目录
5. 安装依赖：`cd authUserPass && npm install`
6. 部署

### 数据库

- 需创建 `users` 集合
- 建议为 `username` 字段创建唯一索引

---

## authPhoneLogin（手机验证码，可选）

手机验证码登录。需配置 `CLOUDBASE_PUBLISHABLE_KEY` 和手机号登录方式。
