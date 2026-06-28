# 前端 P1/P2 任务实现概览

## 完成内容

依据 `todo.md` 与 `docs/2_detailed_design_v3.md`，完成了 P1 占位页面、P2 公共组件开发，并统一了项目视觉风格。

### P1 — 占位页面（4 个）

| 文件 | 说明 |
|------|------|
| `src/views/NewsView.vue` | 健康资讯列表：分类标签、分页加载、AI 生成资讯（含免责声明与分类选择）、错误/空态/加载态 |
| `src/views/HealthAdvice.vue` | 健康建议列表：手风琴展开、Markdown 渲染、分页、空态引导打开 AI 助手 |
| `src/views/ChangePassword.vue` | 管理员强制密码修改：表单校验、提交、成功后清除 mustChangePassword 并跳转 |
| `src/views/Admin.vue` | 智能管理后台：自然语言对话（SSE 流式）、操作日志分页、视图切换 |

### P2 — 公共组件（7 个）

| 文件 | 说明 |
|------|------|
| `src/components/TabBar.vue` | 底部 5 Tab 导航栏（可复用、响应式、安全区适配） |
| `src/components/FabButton.vue` | FAB 悬浮按钮（全局 AI 助手入口） |
| `src/components/AiChatDialog.vue` | AI 助手对话弹窗：遮罩、SSE 流式、Markdown、免责声明、未登录引导、推荐问题 |
| `src/components/SkeletonLoader.vue` | 通用骨架屏（card/list/text/article/avatar 等模式） |
| `src/components/ErrorRetry.vue` | 错误重试组件 |
| `src/components/EmptyState.vue` | 空数据引导组件 |
| `src/components/DisclaimerBar.vue` | 医学免责标识条 |

### 配套 API 与状态扩展

- `src/composables/useArticleApi.ts`：文章生成类型守卫与接口
- `src/composables/useAdviceApi.ts`：健康建议列表接口
- `src/composables/useAdminApi.ts`：管理员日志与 SSE 对话接口
- `src/composables/useUserApi.ts`：密码修改接口
- `src/stores/chatStore.ts`：新增 `sendAssistantMessage`、`sendAdminMessage`、`releaseActiveController`，支持多会话模式
- `src/types/api.ts`：新增 `ArticleGenerateCategorySelection`、`ArticleGenerateResponse`、`HealthAdvice`、`AdminLog`、`ChangePasswordRequest` 等类型

### 工程修复

- `src/App.vue`：抽取 TabBar 组件，接入 FabButton + AiChatDialog，使用项目 CSS 变量体系重写样式
- 修复了 `vue-tsc -b` 编译过程中暴露的前端既有类型错误：
  - `src/composables/useMarkdown.ts`
  - `src/utils/enumLabels.ts`
  - `src/utils/sanitize.ts`
  - `src/views/LifePlan.vue`
  - `tsconfig.node.json` 模块解析配置

## 验证结果

```bash
npm run build:client
```

TypeScript 检查与 Vite 生产构建均通过，生成 `dist/` 产物。

## 约束遵循

- 仅修改前端代码，未改动 `server/` 后端代码
- 仅阅读设计文档，未修改 `docs/2_detailed_design_v3.md` 或 `todo.md`
- 使用项目已有的 CSS 变量体系（`src/assets/variables.css`）与 Font Awesome 图标
- 组件与页面均包含加载态、错误态、空态，并遵循响应式与安全区适配
