# 详细设计任务需求

## 项目背景
基于已通过7轮审议迭代的需求澄清文档 `1_requirements_analysis_v1.md`（1601行，v1→v2→v3→v3_rev1→v4→v5→v5_rev2→v6→v7），以及U+平台全部任务文档和爱从游参考文件，完成"糖尿病预治智能助手"Web平台的详细设计。

## 需求文档完整路径
`C:\Users\DELL\Desktop\qingruanProject2026\docs\1_requirements_analysis_v1.md`

## 参考文档目录
- `C:\Users\DELL\Desktop\qingruanProject2026\docs\U+\` — U+平台全部任务文档（项目准备→分析设计→开发→部署测试4阶段）
- `C:\Users\DELL\Desktop\qingruanProject2026\docs\爱从游文件\` — A1-A5并行轨道任务、详细设计模板、课程材料

## 技术栈约束（已确定，不可更改）

### 前端
- HTML + CSS + JavaScript（原生，不依赖Webpack/Vite等构建工具）
- Tailwind CSS（CDN引入，存放于/static/lib/）
- Swiper（轮播组件，CDN或本地引入）
- SweetAlert2（弹窗组件）
- Font Awesome（图标库）
- marked.js（Markdown渲染）
- 移动端优先设计（375px基准宽度）
- SPA架构 + iframe子页面（主框架 index.html + /pages/ 子页面）
- 前端源码目录：/src/pages/（HTML文件）、/src/css/（样式）、/src/js/（公共JS）、/src/js/pages/（页面JS）、/static/lib/（第三方库）、/static/images/（预置图片）、/static/uploads/（用户上传）

### 后端
- Node.js + Express（端口3000）
- SQLite数据库（单文件，数据服务器本地存储）
- JWT无状态会话（24小时过期）
- bcrypt密码哈希
- SSE流式代理（fetch + ReadableStream，不使用EventSource，因EventSource不支持自定义请求头携带JWT Token）

### AI层
- Dify平台（工作流 + Agent + 聊天助手）
- DeepSeek大模型（通过Dify API调用）
- 7个Dify应用：
  1. diabetes-risk-prediction（工作流）— 风险预测
  2. life-plan-generator（工作流）— 方案生成
  3. health-article-generator（工作流）— 资讯生成
  4. punch-analysis（工作流）— 打卡分析
  5. diabetes-assistant-agent（Agent）— AI智能助手
  6. admin-manager-agent（Agent）— 智能管理
  7. doctor-chat-{id}（聊天助手 × N位医生）— 医师咨询

### 部署
- 3台Linux服务器（8核16G）：
  - 服务器1（数据服务器）：SQLite + Express(3000) + Nginx(静态文件)
  - 服务器2（系统运行主服务器）：Nginx反向代理 + 负载均衡
  - 服务器3（系统运行备服务器）：Nginx反向代理 + 负载均衡

## 详细设计输出范围（7大章节）

### 1. 系统架构详细设计
- 系统整体架构图（mermaid或ASCII art，展示三层：前端层→Express层→Dify/DeepSeek层）
- iframe SPA主框架架构图（主框架与子页面关系、postMessage通信流程）
- 技术选型详情表（每个技术选择的理由、版本、引入方式）
- 模块划分与依赖关系（9大功能模块 + 公共模块）
- 跨模块通信机制详细设计（postMessage消息类型枚举、数据流图、origin校验实现）
- 前端路由详细设计（hash路由完整映射表、路由守卫伪代码）
- 三条数据操作路径的架构流程图

### 2. 数据库详细设计
- 完整ER图（mermaid，包含所有10张表及其关系）
- 每张表的完整DDL（CREATE TABLE语句，含所有字段、类型、约束、默认值、外键）
- 索引策略（每张表的索引设计及理由）
- 初始数据INSERT脚本（医生3位+、糖尿病类型4类、管理员账号、示例文章2-3篇）
- 数据字典（每张表每个字段的类型、范围、约束、业务含义）

### 3. API接口详细设计
- 完整端点清单（所有14组端点，含HTTP方法、URL、认证要求）
- 每个端点的完整请求体JSON Schema和响应体JSON Schema
- SSE流事件的完整格式定义（event类型、data字段结构）
- 统一错误响应格式及所有错误码枚举
- 分页响应统一格式
- Express代理层请求参数映射表（前端字段名→Dify API参数名）
- postMessage消息协议完整定义（AUTH_SYNC、NAVIGATE、DATA_TRANSFER的完整字段）

### 4. 前端模块详细设计
- 每个HTML页面的组件树（DOM结构伪代码）
- 每个页面的状态管理方案（localStorage/sessionStorage/JS变量的使用边界）
- 每个页面的JS逻辑流程图（mermaid flowchart）
- 公共JS模块设计（api.js请求封装、auth.js JWT拦截器、message.js postMessage工具）
- CSS设计系统（完整CSS变量定义、组件样式规范）
- 交互状态组件设计（加载中骨架屏、空数据引导页、错误重试组件的HTML模板）

### 5. Dify工作流/Agent配置设计
- 每个Dify应用的设计规格：
  - 系统提示词（System Prompt）完整文本
  - 输入变量定义（字段名、类型、必填、示例值）
  - 输出结构定义
  - 知识库配置（如有）
  - 工具定义（Agent类型应用的Text2SQL工具配置，含回调URL模板）
- Dify工作流节点的编排逻辑（mermaid flowchart）
- Agent ReAct/Function Calling模式选择及理由

### 6. 部署详细设计
- Nginx完整配置文件（服务器2/3的反向代理+负载均衡配置、服务器1的静态文件配置）
- Express启动脚本和环境配置
- SQLite数据库文件初始化脚本
- 静态资源目录结构和Nginx location映射
- 负载均衡策略详细说明（Keepalived主备方案）

### 7. 安全详细设计
- JWT鉴权完整流程图（登录→Token颁发→请求携带→过期处理→登出）
- bcrypt密码哈希的盐轮数和工作因子
- /api/admin/execute双认证模式完整实现伪代码
- iframe同源策略约束清单
- XSS防御策略（输出编码、CSP头配置）
- SQL注入防护策略（参数化查询、输入校验）
- CSRF防护策略

## 产出文件
`C:\Users\DELL\Desktop\qingruanProject2026\docs\2_detailed_design_v1.md`

## 关键约束
- 所有设计决策必须与需求文档保持一致（需求文档已通过7轮审议）
- 命名规范遵循需求文档中的约定（如字段名、端点路径、文件路径）
- 数据库表结构以需求文档第5节定义为准，可补充但不可修改已有字段定义
- API端点以需求文档第6节定义为准，可细化但不可修改端点路径和HTTP方法
- 前端实现参考U+平台的代码示例模式（Tailwind CSS类名风格、目录组织方式）
- 部署设计以需求文档7.4节和7.5节为准
