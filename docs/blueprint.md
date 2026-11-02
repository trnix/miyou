# 米柚原生重写 · 移植蓝图

> 版本 v1.9 ｜ 2026-11-02（v1.0/v1.1 见 2026-10-30，v1.2–v1.8 同月）
> 定位：重写版的需求基线。后续开发任务拆解、验收均以本文档为准；变更需修订本文档并升版本号。
> 依据：米游社 APK 逆向分析报告、「米柚开发」资料包、docs/handover.md、真机实测、上游开源实现源码核验记录（TeyvatGuide、dsh-mys-checkin）。

## v1.9 变更摘要

- **扫码登录修配（真机 -10001 后的上游对齐）**：v1.8 按 TeyvatGuide 组的头组（DS2 签名 + bll8iq97cem8）真机实测 retcode -10001，证该组合在当前线路上已被拒绝。换用仍在维护的上游 `dsh-mys-checkin`（2026-10 发布）实证组合：**通行证 QR 流程不签名**（无 DS、不依赖 device_fp）；App 通道 `x-rpc-app_id=ddxf5dufpuyo` + `client_type=3` + UA `HYPContainer/1.3.3.182`，创建失败自动回退 Web 通道（miyoushe 域名、`/web/` 路径、`client_type=4`、`x-rpc-channel=miyousheluodi`）。过期码 -3501/-3505（原 -106 属旧线）。确认后按 `token_type` 语义解析 tokens（1 stoken / 2 ltoken / 4 cookie_token，`v2_` 前缀进 `_v2` 键），并用 `user_info.aid/mid` 补齐全部身份别名（stuid/ltuid/ltuid_v2/account_id/account_id_v2、mid/ltmid_v2/account_mid_v2）；取消独立的 stoken→ltoken 换发步骤（上游在 App 通道直接下发）。
- **双上游参照备忘**：TeyvatGuide 的扫码头组较旧（-10001 实证），但 `user/api/getUserFullInfo`（DS2 X4）与战绩 DS 方案仍可参照；dsh-mys-checkin 的 DS1 签到盐与其 2.109.0 版本线配套，供 R5/R7 备用。

## v1.8 变更摘要

- **R4 扫码登录第一阶段实装**：链路与请求头对齐 TeyvatGuide 源码——`createQRLogin` → `queryQRLoginStatus` 轮询（Init/Created/Scanned → Confirmed）；确认后 `tokens[0].token` 为 stoken。（v1.9 修配）
- **DS 签名 salt 落地**：K2/LK2/X4/X6 取自 TeyvatGuide 公开仓库（配套版本线 2.115.0），`DsSign.SIGN_VERSION` 与 `Endpoints.APP_VERSION` 解耦。二维码用系统内置 `QRCode` 组件。
- **历史结论纠偏**：record 域 -10001 存在歧义（或 Cookie 过期/或需 DS），不作为「必须 stoken」唯一证据；R3 移除是范围取舍，其「两个猜测 URL 404」不构成消息接口不存在的技术结论。

## v1.7–v1.2 摘要（压缩存档）

- v1.7：R3 消息中心移除（浏览器直测候选端点 404）；确立总原则「接口预验」。
- v1.6：R3 曾以推测端点尝试接入，后证伪。
- v1.5：评论浏览实装（getPostReplies）；图标链路修复（删除 CI 覆盖资源的 Restore 步骤）。
- v1.4：R2 帖子详情；派蒙图标注记（米哈游版权、自用不分发）。
- v1.3：光感四档改开关。
- v1.2：uiMaterial 解禁；崩坏3 频道下架（gids=3 实为崩坏学园2）；材质方案改实测可用参数。详见 git 历史。

## 0. 总原则

1. 蓝图对标官方：信息架构、模块边界、页面流以官方 App 为参照；实现为纯 ArkTS/ArkUI 干净重写，不使用官方任何代码、bundle 与素材。
2. 只读先行：前期不实现任何远端写入。网络层已具 DS1/DS2 签名与完整 Cookie 能力，写功能归入 R7 灰度，开启前单独风险评估与用户明示。
3. 防御性实现：接口字段缺失/变动不得导致崩溃；统一 snake_case→camelCase 映射层 + 缺省兜底。
4. 官方材质 API 启用规则：`uiMaterial.ImmersiveMaterial` 为 API 26 正式能力，允许使用；必须配能力探测与属性顺序规则（3.2.7）。
5. 资产约束：bundleName 固定 `com.miyou.app`；图标为米哈游版权素材、仅限自用不分发（见 v1.4）。
6. **接口预验原则（v1.7）**：新模块动工前必须先以最低成本验证数据接口可达或拿到可追溯的上游实作源码。拿不到证据不排进迭代。
7. **上游证据优先（v1.8）**：接口行为存疑时，以可定位到具体文件的上游开源实现为准；只引用结论不贴出处的二手文档不得作为实现依据。**多个上游并存时以「仍在维护、近期发布」者优先**（v1.9 补注：TeyvatGuide 扫码头组过旧即为例证）。

## 1. 信息架构（对标官方）

```
米柚
├── 首页（游戏频道 tabs：原神·星铁·绝区零；频道内含子版与发现流）
├── 社区（版区浏览：官方资讯 / 攻略 / 同人 / 酒馆等子版块）
├── 消息（占位说明页：官方未开放通知/私信接口，引导官方 App）
└── 我的（资料区 / 角色卡 / 战绩 / 实时便签 / 设置）
```

说明：底栏维持 4 键悬浮玻璃胶囊；消息 tab 保留占位以维持底栏手势直觉（v1.7）。崩坏3 频道暂缺原因见 v1.2。

## 2. 功能模块总表

| # | 模块 | 官方参照 | 米柚取舍 | 优先级 | 读/写 | 状态/数据基础 |
|---|---|---|---|---|---|---|
| 1 | 启动与主壳 | SplashActivity / HyperionMainActivity | ArkUI 四标签 + 光感玻璃顶/底栏 | P0 | 读 | ✅ M0 完成 |
| 2 | 登录 | PorteLoginActivity / PorteQRConfirmActivity | 网页登录 + 扫码登录（v1.9 双通道无签名实现） | P0 | 读* | ✅ 网页登录完成；◐ 扫码待真机验收 |
| 3 | 首页信息流 | 频道页（图4） | 游戏频道 tabs + 发现卡片流；崩坏3 暂下架 | P0 | 读 | ✅ R1 完成 |
| 4 | 帖子详情 | PostDetailActivity | 结构化富文本按块渲染，未知块降级 | P0 | 读 | ✅ R2 完成 |
| 5 | 设置 | MysSettingsActivity | 沉浸光感开关 / 账号 / 缓存 / 关于 | P0 | 读 | ✅ 光感开关完成；其余随迭代 |
| 6 | 版区浏览 | TopicActivity | 游戏版区 + 子版块列表 | P1 | 读 | R6 |
| 7 | 评论浏览 | CommentDetailActivity | 热门评论 + 分页；楼中楼 R6 | P1 | 读 | ◐ 热评与分页完成（v1.5） |
| 8 | 我的角色/战绩 | game_record + 我的页角色卡 | 角色卡轮播 + 三游戏战绩 | P1 | 读 | R5；认证需求待 stoken/DS 双轮核验（v1.8 纠偏） |
| 9 | 实时便签+服务卡片 | AppWidgetProvider | 便签页 + Form Kit 卡片 | P1 | 读 | R5 |
| 10 | 图片浏览 | PictureViewerActivity | 图片网格 + 缩放预览 | P1 | 读 | ◐ 基础全屏预览完成；缩放/网格归 R6 |
| 11 | 消息中心 | MsgListActivity | **不做**（v1.7 裁定）：tab 保留说明占位 | — | — | 移除，不再排期 |
| 12–16 | 视频 / 搜索 / 用户主页 / 合集 / 计算器抽卡 | — | R6 及以后 | P2 | 读 | — |
| 17–26 | 写功能 / IM / 支付 / 游戏中心 / 合规职能 / 扫码 / 自更新 / 推送 | — | 不做或 R7 灰度 | — | — | 见历史版本 |

## 3. 视觉与交互规范：沉浸光感玻璃

### 3.1 开关映射（设置页「沉浸光感」）

| 状态 | 视觉效果 | 技术参数 |
|---|---|---|
| 关闭 | 纯色不透明 | REGULAR + interactive=false + 不透明 #FFF7F8FA 遮罩 |
| 开启（默认） | 厚重光感 | THICK + interactive=true + lightEffect(White) + 0.5vp 半透明白边 |

### 3.2 实现要点（实测结论持续累积）

1. `setWindowLayoutFullScreen(true)`；底部安全区须同时查 `TYPE_SYSTEM` 与 `TYPE_NAVIGATION_INDICATOR` 取最大值，监听 `avoidAreaChange` 并在 onWindowStageDestroy 释放。
2. 沉浸结构为三层叠加：底色 → 全屏内容层 → 顶部覆盖层；非首页用顶端 padding 避让，首页用 List contentStartOffset/EndOffset 做首尾避让。
3. 全屏透明覆盖容器必须 `hitTestBehavior(HitTestMode.None)`。
4. 系统栏透明 + 深色内容色。
5. 光感开关 AppStorage + preferences 持久化（glassLevel 0/3），StorageLink 联动即时生效。
6. 底栏悬浮圆角胶囊（margin 16、padding 8、圆角 32、shadow、描边）。
7. **属性顺序**：`backgroundColor` 必须写在 `systemMaterial` 之前，违者磨砂被整段覆盖。

### 3.3 官方 UI 对齐规范（存档）

信息流卡片 / 我的页 / 频道页结构拆解见 v1.2–v1.5 版（git 历史）。配色：主蓝 `#00C3FF`、页面底 `#F7F8FA`、标题 `#101828`、摘要 `#667085`。

## 4. 技术底座需求（含实证）

- 包名 `com.miyou.app`；目标 API 26。
- 网络层版本线三条并存，各自服务于不同链路：`Endpoints.APP_VERSION=2.117.0`（x-rpc 基线读接口）；`QrLoginApi` 内部 `2.109.0`（扫码头组，与其上游配套）；`DsSign.SIGN_VERSION=2.115.0`（DS salt 配套）。**三者不可混用**。
- Cookie（实证）：v2 键为主体；多域拼接按键去重、丢空值；扫码后补齐 stuid/stoken/mid 系列及全部身份别名。
- 认证等级（v1.8 纠偏后）：bbs 读接口 ltoken Cookie 即可；record 域认证需求待 R5 双轮核验。
- 设备身份：device_id 首启生成持久化；device_fp 在线获取持久化；**通行证扫码链路不发送 device_fp**（v1.9 上游实证）。
- 签名：DS1/DS2 已实装并填入社区 salt；**通行证 QR 流程不签名**（v1.9）。
- 错误处理：-100/-10001 跳登录；1034/限流指数退避；扫码 -3501/-3505 为二维码过期，自动刷新。
- 渲染：未知块/缺字段降级；`post.content` 可能为 HTML，须有兜底解析。
- 消息接口（v1.7）：不投入抓包取证。

## 5. 开发顺序（R1–R7）

| 序 | 模块 | 状态 | 验收标准 |
|---|---|---|---|
| R1 | 频道发现信息流 | ✅ | 三频道切换、卡片按 3.3 规范、下拉刷新、弱网降级 |
| R2 | 帖子详情 + 评论浏览 | ✅ | 完整渲染不崩、图片可放大、热门评论可翻页 |
| R3 | ~~消息中心~~ | 取消（v1.7） | tab 占位说明页不误导用户即为达标 |
| R4 | 扫码登录 + stoken | ◐ v1.9 修配后待真机 | 二维码生成经 App/Web 通道；确认后凭据（token_type 语义）落库；过期自动刷新；成功后探活 record 域转 0 或给出下一步证据 |
| R5 | 我的角色/战绩/便签/卡片 | 待开工 | Cookie 组合与 DS 签名双轮核验后定实现方案；角色卡数据完整、卡片 ≥30min 刷新 |
| R6 | 只读补全 | 待开工 | 搜索、用户主页、合集、楼中楼、视频、版区浏览 |
| R7 | 写功能灰度（远期） | 未评审 | 风控评估 + gt4 兜底 + 小号灰度 + 用户明示开关 |

## 6. 风险与边界

- 接口时效：渲染层兜底 + 版本/salt 集中配置化是生命线；salt 与头组变更时以仍在维护的上游为参照对齐。
- 接口可达性前置验证（v1.7）：公开社区无文档的接口先做零成本预验，预验不过即移出排期。
- 上游时效差（v1.9 新增）：同一接口不同上游的实现可能分属不同年代，静仓库的扫码头组可能已失效；采纳前看这个上游「最后一次提交是否近期、README 是否声明功能可用」。
- 账号风控：device_fp/device_id 成对稳定；触发 gt4 走 Web 兜底。扫码登录属官方支持流程，风控低于账密方式。
- 合规：非官方、仅查看授权数据、不接触账密；Cookie 仅存本机；图标为米哈游版权素材、仅限自用不分发。
- 签名资产：7 个 Actions 变量为唯一签名链路来源，任何重构不得输出其明文。

—— 蓝图以上。开发中如与本文档冲突，先改文档再改代码。
