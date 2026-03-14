# Hi-Doo 绘读：Supabase → 腾讯云开发 CloudBase 迁移方案

## 一、架构概览

| 原 Supabase | 迁移后 CloudBase |
|-------------|------------------|
| Supabase Auth（匿名 + 手机号 OTP） | CloudBase Auth（匿名 + 自定义登录/云函数） |
| Postgres `books` 表 | CloudBase 集合 `books` |
| Postgres `read_logs` 表 | CloudBase 集合 `read_logs` |
| Supabase Storage `read-audios` | CloudBase 存储 / COS |
| `supabase_flutter` | `cloudbase_ce` |

---

## 二、Cover 图片与 BookApiService

### 2.1 Cover 来源

- **BookApiService**（`lib/services/book_api_service.dart`）从 **Open Library API** 获取书籍信息，包括 `coverUrl`。
- `coverUrl` 是外部 URL（如 `https://covers.openlibrary.org/...`），**不经过 Supabase Storage**。
- 存入 `books` 表时，`cover_url` 字段保存的就是该外部 URL。

### 2.2 迁移后处理

- **方案 A（推荐）**：继续使用 Open Library 的 cover URL，`books` 集合中 `cover_url` 仍存外部链接，无需上传 COS。
- **方案 B**：若需自托管封面（防盗链、加速等），可在保存书籍时下载图片并上传到 CloudBase 存储，再将 COS URL 写入 `cover_url`。

---

## 三、read_logs 与 Reading Journal 流程

### 3.1 read_logs 使用位置

| 操作 | 文件 | 说明 |
|------|------|------|
| **insert** | `recording_screen.dart` | 复述模式：录音 → 转写 → 上传 → 插入 read_log |
| **insert** | `read_logs_service.dart` | 共读模式：仅插入一条 shared_reading 记录 |
| **update** | `reading_journal_detail_screen.dart` | 生成 AI 点评后更新 `ai_feedback` |

### 3.2 read_logs 字段

```json
{
  "id": "uuid",
  "user_id": "auth_user_id",
  "book_id": "book_id",
  "session_type": "retelling" | "shared_reading",
  "audio_url": "https://...",
  "transcript": "转写文本",
  "ai_feedback": "{\"comment\":\"...\",\"logic_score\":4}",
  "language": "zh",
  "created_at": "2025-03-06T12:00:00.000Z"
}
```

### 3.3 Reading Journal 流程

1. **扫码录入** → `ScanBookScreen` → `BookApiService.fetchByIsbn` → `BookConfirmScreen`
2. **确认书籍** → `BooksService.upsertBook` → 存入 `books`
3. **选择模式**：
   - **复述模式**：`RecordingScreen` → 录音 → 上传 → 转写 → `_saveReadLog` 插入 `read_logs`
   - **共读模式**：`SharedReadingScreen` → `ReadLogsService.createSharedReadingLog` 插入 `read_logs`
4. **详情页**：`ReadingJournalDetailScreen` 接收 `book` + `readLog`，可生成 AI 点评并 `update` read_log

> 当前代码中 **没有** 从数据库查询 read_logs 列表的逻辑；`ReadingJournalDetailScreen` 的 `readLog` 由外部传入（如分享链接、后续列表页等）。

---

## 四、数据模型映射

### 4.1 books 集合

| Postgres 字段 | CloudBase 字段 | 说明 |
|---------------|----------------|------|
| id | _id | 文档 ID，CloudBase 可自动生成 |
| isbn | isbn | 唯一索引，用于 upsert 判断 |
| title | title | |
| author | author | |
| cover_url | cover_url | 外部 URL 或 COS URL |
| summary | summary | |

**Upsert 逻辑**：CloudBase 无原生 upsert，需先 `where('isbn', '==', isbn).get()`，有则 `doc(id).update()`，无则 `add()`。

### 4.2 read_logs 集合

| Postgres 字段 | CloudBase 字段 | 说明 |
|---------------|----------------|------|
| id | _id | 文档 ID |
| user_id | user_id | |
| book_id | book_id | |
| session_type | session_type | |
| audio_url | audio_url | |
| transcript | transcript | |
| ai_feedback | ai_feedback | JSON 字符串 |
| language | language | |
| created_at | created_at | ISO8601 字符串 |

---

## 五、存储迁移

### 5.1 录音文件

- **原路径**：`read-audios/{user_id}/{timestamp}_{random}.m4a` 或 `.webm`
- **新路径**：CloudBase 存储 `read-audios/{user_id}/{timestamp}_{random}.m4a`
- **实现**：`upload_audio_io.dart` / `upload_audio_stub.dart` 改为调用 CloudBase Storage `uploadFile`

### 5.2 封面（可选）

- 若采用方案 B，需实现 `uploadCoverToCloudBase`，在 `BooksService.upsertBook` 中调用。

---

## 六、认证迁移

| Supabase | CloudBase |
|----------|-----------|
| `signInAnonymously()` | `CloudBaseAuth.signInAnonymously()` |
| `signInWithOtp(phone)` | 云函数自定义登录 或 等待 cloudbase_ce 支持 |
| `verifyOTP` | 同上 |
| `auth.currentUser` | `CloudBaseAuth.getUser()` |
| `signOut()` | `CloudBaseAuth.signOut()` |

> **注意**：`cloudbase_ce` 标注手机号认证为「即将支持」。短期可先用匿名登录，或通过云函数实现自定义 token 登录。

---

## 七、环境配置

使用 `lib/env_config.dart` 集中配置：

```dart
class EnvConfig {
  static const String envId = String.fromEnvironment('CLOUDBASE_ENV_ID');
  static const String appAccessKey = String.fromEnvironment('CLOUDBASE_APP_ACCESS_KEY');
  static const String appAccessVersion = String.fromEnvironment('CLOUDBASE_APP_ACCESS_VERSION');
}
```

启动时传入：`--dart-define=CLOUDBASE_ENV_ID=xxx --dart-define=...`
