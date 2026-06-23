# 详细设计质量审查报告 (v2, 第2轮)

## 1. 审查概要

| 项目 | 说明 |
|------|------|
| 待审查产出 | `a_v2_copy_from_v1.md` (糖尿病预治智能助手详细设计文档, 4298行) |
| 审查报告产出 | `b_v2_diag_v1.md` (本文件) |
| 迭代轮次 | 第 2 轮 |
| 审查依据 | 用户需求 `requirement.md`、SRS `1_requirements_analysis_v1.md`、迭代历史 `iteration_history.md` |
| 审查日期 | 2026-06-23 |

## 2. 上一轮问题修复验证

第 1 轮诊断报告 (`b_v1_diag_v1.md`) 提出 4 个问题，记录于 `iteration_history.md`。经逐项核实，**全部 4 个问题已在 v2→v3 修订中得到充分修复**：

| 序号 | 问题简述 | 严重程度 | 修复状态 | 核实依据 |
|------|---------|---------|---------|---------|
| 1 | 路由守卫访问控制漏洞 (consultation 在 publicRoutes 中) | 严重 | **已修复** | 1.6.2节：`publicRoutes` 已移除 `'consultation'`；新增 `routeAuthRules` 细粒度子路由权限表；路由守卫新增步骤1.5子路由检查逻辑；未匹配子路由默认要求认证(安全默认拒绝) |
| 2 | Dify工作流假定直连SQLite导致数据通路断裂 | 严重 | **已修复** | 5.2.3节和5.2.4节新增 `user_health_data`/`punch_records` inputs字段；5.3.3节和5.3.4节工作流编排删除"查询数据库"节点，替换为"接收预查询数据"节点；3.6节新增预查询数据注入说明和参数映射 |
| 3 | JS逻辑流程图仅覆盖5/12页面 | 一般 | **已修复** | 4.3节已为缺失的7个页面(index.html、profile.html、punch.html、health-advice.html、admin.html、login.html、change-password.html)补充完整流程图，覆盖率提升至12/12 |
| 4 | 状态管理方案表缺失部分页面 | 一般 | **已修复** | 4.2节补充了 profile/punch/health-advice 三个页面的完整状态规划行，完善了 admin/change-password 的覆盖；news.html 分页状态改为 sessionStorage 持久化 |

**结论**：上一轮发现的全部问题均已解决，无修复遗漏。

## 3. 本轮新发现问题

### 问题1: difyAuth中间件在模块结构中引用但行为未定义 (一般)

- **所在位置**: 1.4节 模块划分 (`server/middleware/difyAuth.js`) 与 7.3节 双认证实现
- **问题描述**: 1.4节目录结构中列出 `difyAuth.js`（Dify API Key校验中间件），但全文未定义该中间件的具体行为——包括：何时使用、校验什么字段、校验失败返回什么、与JWT auth中间件的执行顺序。第7.3节 `/api/admin/execute` 的双认证实现以内联方式处理 API Key 校验（通过 `if (api_key)` 分支），未调用外部中间件。实现者无法确定 (a) 是否需要实现 `difyAuth.js` 文件、(b) 该中间件是用于 `/api/admin/execute` 还是其他端点、(c) 中间件与7.3节内联逻辑的关系。
- **影响**: 后端开发者在创建 `server/middleware/` 目录下的文件时，`difyAuth.js` 是空实现还是重复7.3节逻辑，需要自行判断。若误将内联校验和中间件同时使用，可能导致双路径行为不一致。
- **改进建议**: (1) 明确 `difyAuth.js` 的职责边界——推荐方案为 `/api/admin/execute` 端点的 API Key 路径统一经过此中间件预处理，中间件验证通过后 `req.difyAuth = {userId, mode: 'callback'}` 注入上下文，后续路由处理器根据 `req.difyAuth` 和 `req.user` (JWT) 区分双认证路径；(2) 补充 `difyAuth.js` 的伪代码或行为规格说明；(3) 明确三个中间件(auth.js / admin.js / difyAuth.js)在 `/api/admin/execute` 上的挂载顺序和组合逻辑。

### 问题2: Nginx服务器1的CSP白名单与全本地引入策略不一致 (一般)

- **所在位置**: 6.1.2节 服务器1 Nginx配置, line 3755
- **问题描述**: 服务器1的 CSP 头中 `script-src` 白名单包含 `https://cdn.jsdelivr.net`：
  ```
  add_header Content-Security-Policy "... script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdn.jsdelivr.net; ..."
  ```
  但第1.3节技术选型表明确所有第三方库均为本地引入（`/static/lib/` 目录下的 tailwindcss.js、swiper-bundle.min.js、sweetalert2.min.js、marked.min.js、Font Awesome CSS/webfonts），无任何 CDN 依赖。CSP 中的 CDN 白名单条目实际不会被任何请求命中，属于无效配置。
- **影响**: (1) 部署人员可能误解为"系统依赖 jsdelivr CDN"，从而在网络隔离环境中产生不必要的网络策略调整；(2) CSP 策略实际比"全本地"架构隐含的更宽松——允许从外部 CDN 加载脚本，增加了不必要的攻击面。功能层面不影响运行。
- **改进建议**: 从服务器1 CSP 的 `script-src` 中删除 `https://cdn.jsdelivr.net`，与"全本地"引入策略保持一致。

### 问题3: health-advice.html 空数据状态的HTML模板缺失 (轻微)

- **所在位置**: 4.3节 health-advice.html 流程图 与 4.6.3节 空数据引导页
- **问题描述**: health-advice.html 流程图第1个分支明确引用空数据状态——"数据为空: 展示空状态('还没有健康建议，去AI助手对话中获取吧')"。但第4.6.3节仅提供了打卡记录为空和方案为空两种空数据HTML模板，缺少健康建议列表为空的对应HTML模板（包含引导文案和跳转至AI助手的CTA按钮）。
- **影响**: 前端开发者在实现 health-advice.html 的空数据状态时需自行编写HTML模板，可能与其他空状态样式不一致。不影响功能实现，但影响开发效率和UI一致性。
- **改进建议**: 在4.6.3节补充健康建议空数据HTML模板（结构与打卡/方案空状态一致，文案为"还没有健康建议，去AI助手对话中获取吧"，CTA按钮跳转触发FAB弹窗）。

### 问题4: 4.3节流程图格式为ASCII文本而非mermaid (轻微)

- **所在位置**: 4.3节 全部12个页面的JS逻辑流程图
- **问题描述**: 用户需求第79行明确要求"每个页面的JS逻辑流程图（mermaid flowchart）"。但当前产出中所有12个页面的流程图均使用ASCII文本格式（以缩进箭头表示分支），而非 mermaid 语法。例如：
  ```
  页面加载 -> 检查sessionStorage缓存(1小时有效期)
    -> 缓存命中? 是: 直接渲染
    -> 缓存未命中:
  ```
  而非 mermaid 的 `flowchart TD` / `graph` 语法。
- **影响**: 功能等价——流程图逻辑清晰可读，开发者可据此实现。不阻塞编码。但在严格审查视角下，格式与需求声明不匹配。
- **改进建议**: 将ASCII流程图转换为mermaid flowchart语法（`flowchart TD`）。若保持ASCII格式，则应在文档中说明格式选择的理由（如：纯文本编辑器兼容性、Git diff友好等），并与需求方确认接受此偏差。

## 4. 整体质量评价

### 需求响应充分度

文档完整覆盖了需求中指定的7大章节（系统架构、数据库、API接口、前端模块、Dify配置、部署、安全），每个章节的子项均有对应产出。技术选型遵循需求规定的技术栈（原生HTML/CSS/JS、Tailwind CSS CDN引入、Express+SQLite、Dify+DeepSeek），未偏离约束。

所有设计决策与SRS保持一致——包括10张数据表的字段定义、14组API端点的路径和方法、3条数据操作路径、双认证模式等核心设计。Dify工作流/Agent的7个应用全部给出了系统提示词、输入变量、输出结构和知识库配置。

### 深度与完整性

- **数据库设计**: DDL可直接执行，索引策略有明确理由，初始数据INSERT脚本覆盖4类预置数据（管理员、医生、糖尿病类型、科普文章），数据字典字段级完整。达到编码级。
- **API设计**: 32个端点变体均有完整的请求/响应JSON Schema，SSE流事件格式定义了7种event类型，错误码枚举覆盖13种HTTP状态，参数映射表含预查询数据注入说明。达到编码级。
- **前端设计**: 12个页面的DOM结构包含CSS class名和交互元素层级，状态管理方案覆盖localStorage/sessionStorage/内存变量三种存储边界，公共JS模块（api.js/auth.js/message.js/ui.js）有完整的函数签名规格，CSS变量定义完整，交互状态组件（骨架屏/空数据/错误/Token过期）有完整HTML模板。达到编码级。
- **Dify配置**: 7个应用的System Prompt完整可复制使用，input/output结构定义清晰，工作流节点编排图覆盖关键路径。达到配置级。
- **部署设计**: Nginx完整配置文件可直接部署（已标注生产环境切换注意事项），Keepalived主备配置含vrrp_script健康检查，数据库备份crontab完整。达到部署级。
- **安全设计**: JWT/bcrypt/XSS/SQL注入/CSRF均有具体措施和伪代码。

### 可直接指导编码实现的程度

文档整体达到"可直接指导编码实现"的详细程度。核心阻塞项均已消除：
- 数据库DDL + 种子SQL可直接执行建库
- API端点Schema可直接用于前后端联调
- 前端DOM结构 + CSS变量 + 公共JS模块可直接编写HTML/JS/CSS
- Dify System Prompt可直接复制到Dify平台创建应用
- Nginx配置可直接部署到服务器

新发现的4个问题均为非阻塞性——2个一般问题（difyAuth中间件未定义、CSP白名单不一致）在编码实现中可快速填补，2个轻微问题（空状态模板缺失、流程图格式）不影响核心开发路径。

## 5. 问题汇总

| 序号 | 问题 | 位置 | 严重程度 | 类型 |
|------|------|------|---------|------|
| 1 | difyAuth中间件在模块结构中引用但行为未定义 | 1.4节 / 7.3节 | 一般 | 设计缺口 |
| 2 | Nginx服务器1 CSP白名单与全本地引入策略不一致 | 6.1.2节 | 一般 | 配置不一致 |
| 3 | health-advice空数据状态HTML模板缺失 | 4.3节 / 4.6.3节 | 轻微 | 完整性遗漏 |
| 4 | 4.3节流程图格式为ASCII文本而非mermaid | 4.3节 | 轻微 | 格式偏差 |

## 6. 修订说明（v1）

本轮为首轮审查，无前序质询文件需要回应。
