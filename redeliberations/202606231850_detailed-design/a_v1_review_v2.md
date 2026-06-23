# OOD 设计方案审查报告（v2）

## 审查结果

**APPROVED**

## 逐维度审查

### 1. 类型系统可行性

**[通过]** 本设计方案面向 JavaScript/Node.js 技术栈，该语言为动态类型系统。设计中涉及的类型形态选择（class/object/Map/Array/primitive types）与 JavaScript 的类型系统能力完全匹配。抽象之间的协作关系（Express 中间件链、Service 层调用、模块导出导入）均在 JavaScript 运行时约束范围内。设计不涉及泛型抽象，无类型系统层面的阻塞性问题。

**[通过]** 数据模型层面的类型约束（SQLite CHECK 约束、TEXT/INTEGER/REAL 类型、外键关系）与 SQLite 3 的类型系统能力完全兼容。所有 DDL 语句中的类型声明和约束定义均为 SQLite 原生支持的能力。

### 2. 标准库与生态覆盖

**[通过]** 设计方案依赖的技术组件均在目标生态覆盖范围内：

- **后端**：Express 4.x、better-sqlite3 9.x、jsonwebtoken 9.x、bcryptjs 2.x、multer 1.x、dotenv 16.x——均为 npm 生态中成熟稳定的包，不存在假设不可用的情况。
- **前端**：Tailwind CSS 3.x CDN、Swiper 11.x、SweetAlert2 11.x、Font Awesome 6.x、marked.js 12.x——均为通过本地 `/static/lib/` 或 CDN 引入的前端库，与"不依赖构建工具"的约束兼容。
- **AI 层**：Dify 平台 HTTP API + DeepSeek 模型推理——通过 HTTP 协议集成，不依赖特定语言 SDK。
- **部署**：Nginx 1.24+、Keepalived 2.x、Node.js 18 LTS——均为 Linux 服务器标准组件。

**[通过]** 设计中的自定义抽象（postMessage 消息总线、JWT 拦截器、SSE 代理透传）均基于平台原生 API（window.postMessage、fetch、ReadableStream），不依赖未验证的第三方能力。

**[通过]** 之前 v1 审查中标识的"Dify 平台能力验证任务与备选方案缺失"问题已修复：新增 5.5 节定义了完整的前置验证任务（验证目标、方法、端点、标准、时机）和备选方案（session_id 映射表的完整设计，含数据结构、生命周期、difyService.js 注入点、/api/admin/execute 参数适配、风险提示、启用条件）。

### 3. 语言特性可行性

**[通过]** 错误处理策略与 JavaScript/Node.js 的错误处理能力匹配：Express 全局错误中间件 + try/catch 异步错误捕获 + 统一 JSON 错误响应格式。SSE 流内错误事件处理策略（按 event 字段分类处理，工具调用失败/知识库异常/安全审核拦截等分类处置）已在 6.4 节定义。

**[通过]** 并发设计：采用 Node.js 事件驱动 + 异步 I/O 模型，SSE 流通过 fetch + ReadableStream 实现（不使用 EventSource，因其不支持自定义请求头携带 JWT Token），与 Node.js 的流式处理能力兼容。SQLite 通过 better-sqlite3 同步 API 访问（单文件数据库，无并发写入竞争）。

**[通过]** 资源管理方案可行：SQLite 单文件数据库通过 better-sqlite3 连接管理；用户上传文件通过 multer 处理并存储至本地文件系统；会话状态通过 JWT 无状态管理（无需服务端 session 存储）；备选方案的 session_id 映射表使用内存 Map（含定时清理策略）。

**[通过]** 模块/包结构设计符合 Node.js + 原生前端的标准组织方式：Express 按 routes/middleware/services/db 分层；前端按 pages/css/js/js-pages 分层；公共模块（api.js, auth.js, message.js, ui.js）不依赖页面模块；iframe 子页面仅通过 postMessage 经主框架中转通信。

### 4. 设计一致性

**[通过]** 此前 v1 审查中标识的所有 6 个问题均已得到充分修复：

**一般问题 1（管理员首次登录强制修改密码机制缺失）—— 已修复**：
- users 表 DDL 新增 `password_changed TEXT NOT NULL DEFAULT '0' CHECK(password_changed IN ('0', '1'))` 字段（2.2 节）
- ER 图新增 `password_changed` 字段（2.1 节）
- 数据字典补充 `password_changed` 字段业务含义说明（2.5 节）
- 种子 SQL 管理员记录追加 `password_changed='0'`（2.4 节）
- POST /api/auth/login 响应 Schema 新增管理员首次登录响应体，含 `must_change_password: true` 标志（3.2.2 节）
- PUT /api/user/password 端点新增管理员首次登录强制修改密码场景说明（3.2.6 节）
- 路由守卫伪代码新增管理员首次登录拦截逻辑（1.6.2 节）
- Hash 路由映射表新增 `#/change-password` 路由（1.6.1 节）
- 目录结构新增 change-password.html 文件（1.4 节）
- 新增 4.1.12 节 change-password.html 完整 DOM 结构
- 状态管理方案表补充 `must_change_password` 状态存储（4.2 节）

**一般问题 2（Dify 平台能力验证任务与备选方案缺失）—— 已修复**：
- 新增 5.5.1 节"前置验证需求"，定义完整验证任务（验证目标、验证方法含6步操作、验证端点、验证标准、验证时机、责任人）
- 新增 5.5.2 节"备选方案：Express 服务端 session_id→user_id 映射表"，含：映射表数据结构（Map<string, {userId, createdAt}>）、session_id 生成策略（crypto.randomUUID()）、difyService.js 中的注入点（完整伪代码）、映射表清理策略（登出清除 + 每30分钟定时扫描24小时过期条目）、/api/admin/execute 端点的参数适配（session_id 替代 user_id 的请求体格式 + 反查伪代码）、风险提示（进程重启丢失 + SQLite 持久化可选方案）、启用条件（仅验证失败时启用）

**轻微问题 3（life_plans 表 plan_type 的'其他'枚举值无功能需求支撑）—— 已修复**：
- 数据字典 plan_type 字段说明新增注释："当前版本仅使用'饮食'和'运动'两种类型，'其他'为预留扩展值，当前版本前端不渲染此类型的方案项UI"（2.5 节）

**轻微问题 4（Nginx CORS 配置与同源部署不一致）—— 已修复**：
- 服务器 2/3 Nginx 配置中 CORS 配置块上方新增 4 行安全注释，说明生产环境同源部署时可移除、开发调试时应用白名单替代 `$http_origin`（6.1.1 节）

**轻微问题 5（CSS 类名 `rounded-button` 未在 CSS 变量中定义）—— 已修复**：
- CSS 变量定义新增 `--radius-button: 12px;` 变量（4.5.1 节）
- 组件样式规范表中所有 `rounded-button` 替换为 Tailwind 标准工具类 `rounded-lg`（4.5.2 节）

**轻微问题 6（部分页面 DOM 结构过于简略）—— 已修复**：
- 原 4.1.6 节拆分为 4.1.6-4.1.12 共 7 个子节，为 profile.html、risk.html（完整三步向导 + 进度指示器 + 中间状态容器）、punch.html（日期筛选器 + AI 分析统计卡片 + 趋势图区域 + 加载更多）、health-advice.html（可展开卡片 + 旋转箭头动画 + marked.js 渲染区）、login.html（登录/注册双视图 + 实时校验提示）、admin.html（对话视图 + 操作日志列表视图切换）提供完整 DOM 结构，含 CSS class 名、交互元素和状态容器
- 新增 change-password.html 完整 DOM 结构（锁图标 + 提示文案 + 新密码/确认密码表单 + 提交按钮）

**[通过]** 各抽象的职责描述清晰无歧义：14 个 Express 路由文件、2 个 Service 模块、3 个数据库模块的职责划分明确。9 大功能模块的 HTML/JS 文件与模块功能一一对应。

**[通过]** 协作关系形成闭环：三条数据操作路径（常规 CRUD、AI 驱动 Text2SQL、AI 内容生成持久化）的架构流程图覆盖了所有数据读写的完整链路。postMessage 消息总线的 7 种消息类型覆盖了主框架与 iframe 之间的所有通信场景。

**[通过]** 行为契约描述完整：每个 API 端点提供了完整的请求/响应 JSON Schema（含字段名、类型、约束、示例值），SSE 流事件格式逐字段定义，错误码完整枚举（11 个错误码覆盖所有场景），分页响应统一格式，postMessage 消息协议完整字段定义。可直接指导 Express 路由和服务端逻辑编写。

**[通过]** 模块间依赖方向合理：公共模块（api.js, auth.js, message.js, ui.js）不依赖任何页面模块；iframe 子页面可依赖公共模块，不可依赖其他页面模块；页面模块间通过 postMessage 经主框架中转通信，无直接依赖。后端三层架构（routes → services → db）依赖方向单向，无循环依赖风险。

**[通过]** 对照 SRS（`1_requirements_analysis_v1.md`）检查，设计文档与 SRS 在各约束维度保持一致：技术栈选择（前端原生 HTML/CSS/JS + Tailwind CDN，后端 Node.js + Express + SQLite，AI 层 Dify + DeepSeek）、数据库表结构（10 张表的字段定义与 SRS 第 5 节一致）、API 端点（14 组端点与 SRS 第 6 节一致，方法/路径/认证要求完全匹配）、部署架构（3 台服务器角色分工与 SRS 第 7.4 节一致）、安全策略（JWT + bcrypt + 双认证模式与 SRS 第 4.10 节一致）。未发现与 SRS 的不一致之处。

### 5. 设计质量

**[通过]** 职责划分遵循单一职责原则：Express 路由层（routes/）负责 HTTP 请求处理和参数校验，服务层（services/）负责 Dify API 调用封装和 SSE 流代理，数据层（db/）负责 SQLite 连接和查询。前端公共模块按职责分离为 api.js（请求封装）、auth.js（JWT 工具）、message.js（postMessage 工具）、ui.js（UI 组件工具），各行其道。

**[通过]** 抽象层次恰当：设计文档处于详细设计级别——提供了可执行的 DDL/SQL、完整 JSON Schema、DOM 结构伪代码、CSS 变量定义、Nginx 完整配置。既不遗漏关键实现细节（如索引策略、初始数据 INSERT 语句、错误码枚举），也不过早进入代码级别（未提供完整的 `.js`/`.html` 源代码文件，符合详细设计文档的定位）。

**[通过]** 设计便于后续实现：数据库层提供可直接执行的 SQL 脚本；API 层每个端点有完整的请求/响应 Schema 可直接指导 Express 路由编写；前端组件树提供完整的 DOM 结构和 CSS class 名可直接指导 HTML/CSS 编写；Dify 配置层提供完整的系统提示词文本和输入/输出变量定义可直接指导 Dify 平台配置。各页面 JS 逻辑流程图（mermaid）为前端开发者提供了清晰的交互逻辑参考。

**[通过]** 设计便于单元测试：Express 的 routes/services/db 三层分离使得 Service 层可独立 mock 测试（mock Dify API 响应和 SQLite 查询结果），中间件可独立测试（传入 mock req/res/next）。前端公共模块（api.js, auth.js, message.js, utils.js）均为纯函数或可独立实例化的工具模块，便于单元测试。iframe 子页面的页面 JS 通过依赖注入公共模块，可隔离测试。

**[轻微]** change-password.html 路由（`#/change-password`）在 SRS 的访问控制矩阵中标注为"需登录"（无 admin 要求）。路由守卫伪代码（1.6.2 节）仅对 admin 角色且 `must_change_password=true` 的用户强制跳转至该页面，但未拦截普通用户直接访问该路由。虽然后端 PUT /api/user/password 端点会根据 `password_changed` 状态拒绝非管理员的强制密码修改请求（安全性由后端保障），但前端层面可增加路由守卫规则以在非 admin 用户访问时重定向至首页，进一步提升用户体验的一致性。此问题不影响设计可行性，不阻塞通过。

## 修改要求

无。所有 v1 审查中标识的严重和一般问题均已充分修复，当前未发现新的严重或一般问题。上述轻微问题可在后续实现阶段按需处理。
