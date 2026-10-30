# 米柚原生重写 · 移植蓝图

> 版本 v1.0 ｜ 2026-10-30
> 定位：重写版的需求基线。后续开发任务拆解、验收均以本文档为准；变更需修订本文档并升版本号。
> 依据：米游社 2.117.0 APK 逆向分析报告（官方模块地面真实）、「米柚开发」资料包（API 端点清单 / 登录鉴权 / 鸿蒙技术方案）、docs/handover.md（0.4.0 经验与已验证接口）。

## 0. 总原则

1. 蓝图对标官方：信息架构、模块边界、页面流以官方 App（逆向报告第 3 节模块划分）为参照；实现为纯 ArkTS/ArkUI 干净重写，不使用官方任何代码、bundle 与素材。
2. 只读先行：前期不实现任何远端写入（发帖/评论/回复/点赞/关注/收藏/签到/反馈）。网络层预留 DS1/DS2 签名与完整 Cookie 能力，写功能归入 M4 灰度，开启前单独风险评估与用户明示。
3. 防御性实现：接口字段缺失/变动不得导致崩溃（0.4.0 闪退教训）；统一 snake_case→camelCase 映射层 + 缺省兜底。
4. 实验性 API 黑名单：`@ohos.arkui.uiMaterial`（0.4.0 真机闪退根因，永久禁用）。
5. 资产约束：bundleName 固定 `com.miyou.app`（签名 Profile 绑定，不可改）；公开分发不使用「米游社」名称与米哈游素材图标。

## 1. 信息架构（对标官方）

```
米柚
├── 首页（Tabs：推荐 / 关注 / 游戏频道：原神·星铁·绝区零·崩坏3）
├── 社区（版区浏览：官方资讯 / 攻略 / 同人 / 酒馆等子版块）
├── 消息（只读：回复 / 赞 / @我 / 系统通知，需登录）
└── 我的（我的角色 / 战绩 / 实时便签 / 设置）
```

说明：官方顶层含「发布」中枢按钮，米柚只读定位不设置；官方「游戏中心」独立入口不保留。

## 2. 功能模块总表

| # | 模块 | 官方参照（逆向报告） | 米柚取舍 | 优先级 | 读/写 | 数据基础 / 备注 |
|---|---|---|---|---|---|---|
| 1 | 启动与主壳 | SplashActivity / HyperionMainActivity | ArkUI Tabs 四标签 + 光感玻璃顶/底栏（见第 3 节） | P0 | 读 | 官方「发布」入口不设置 |
| 2 | 登录 | PorteLoginActivity / PorteQRConfirmActivity | 网页登录（user.mihoyo.com，Cookie 捕获）为主；扫码登录、Cookie 导入备选；多账号槽 | P0 | 读* | *仅建立本地会话，不接触账密；0.4.0 已验证 |
| 3 | 首页信息流 | RN bundle（base + 子 bundle） | 推荐/关注/四游戏频道切换 | P0 | 读 | `bbs-api-static webHome` / `getNewsFeed`（0.4.0 已验证） |
| 4 | 帖子详情 | PostDetailActivity / UgcPostDetailActivity | 结构化富文本渲染（段落/图片/视频/链接块按块映射），未知块降级不崩 | P0 | 读 | `getPostFull`（0.4.0 已验证） |
| 5 | 设置 | MysSettingsActivity | 光感强度调节 / 多账号管理 / 清缓存 / 关于 | P0 | 读 | 本地 preferences |
| 6 | 版区浏览 | TopicActivity / RelateTopicActivity | 游戏版区 + 子版块列表 | P1 | 读 | `getNewsList` / forum 接口 |
| 7 | 评论浏览 | CommentDetailActivity / CommentReplyActivity | 热门评论 + 分页；楼中楼展开远期再说 | P1 | 读 | `getPostReplies`（热评已验证，失效需降级） |
| 8 | 我的角色/战绩 | game_record 体系 | 角色卡 + 原神/星铁/绝区零战绩面板 | P1 | 读 | `game_record/*`（Cookie+DS） |
| 9 | 实时便签+服务卡片 | 6×AppWidgetProvider（原神/星铁/绝区零） | 便签页 + Form Kit 服务卡片（体力/开拓力，1x2/2x2/2x4） | P1 | 读 | `widget/v2` / `dailyNote` / hkrpg `note`；刷新 ≥30min |
| 10 | 图片浏览 | PictureViewerActivity / ImagesViewerActivityV2 | 图片网格 + 缩放预览 | P1 | 读 | 帖内图片直链 |
| 11 | 视频播放 | VideoDetailActivity（ijkplayer） | Video 组件播放（0.4.0 仅提示未实现） | P2 | 读 | 帖内视频直链 |
| 12 | 搜索 | GlobalSearchActivity | 帖子/用户/版区搜索 | P2 | 读 | wapi search |
| 13 | 消息中心 | MsgListActivity | 回复/赞/@/系统通知（只读拉取） | P2 | 读 | 需登录态 |
| 14 | 用户主页 | UserHomePageActivity / UserProfileActivity | 资料卡 + TA 的帖子列表 | P2 | 读 | — |
| 15 | 合集/专题 | CollectionDetailActivity 等 | 合集详情浏览 | P2 | 读 | — |
| 16 | 计算器/抽卡分析 | event 网关（e20200928calculate / rpgcalc / gacha_record） | 养成计算器 + 抽卡分析（authkey） | P2 | 读 | api-takumi event 网关 |
| 17 | 每日签到 | event/luna/sign（DS2 6X） | 写-灰度：需 DS2(6X) + 风控评估 | P3 | 写 | M4 独立评审 |
| 18 | 点赞/关注/收藏 | postUpvote 等 | 写-灰度 | P3 | 写 | M4 独立评审 |
| 19 | 发帖/创作中心 | PublishActivity / DraftBoxActivity | 不做（早期）；M4 之后重新评估 | — | 写 | 风控最重 |
| 20 | IM 单聊 | SingleChatActivity（自研 IM） | 不做：私有协议，逆向成本高 | — | — | — |
| 21 | 支付/米游币 | CashierActivity / 米游币中心 | 不做：第三方无支付场景 | — | — | — |
| 22 | 游戏中心 | GameCenterActivity | 不做：游戏分发属官方职能 | — | — | — |
| 23 | 青少年/举报/申诉 | HyperionMainTeenageActivity / HyperUserReportActivity | 不做：官方合规职能 | — | — | — |
| 24 | 扫码 | ScanActivity（MLKit barhopper） | 不做：无互扫场景；登录由 #2 覆盖 | — | — | — |
| 25 | 自更新 | DownloadIntentService + REQUEST_INSTALL_PACKAGES | 不做：鸿蒙无静默安装；Release 页手动更新 | — | — | — |
| 26 | 推送 | JPush + 小米/华为/OPPO/vivo 通道 | 不做远程推送；本地通知（体力提醒）随 M2 | P2 | 读 | Notification Kit |

## 3. 视觉与交互规范：沉浸光感玻璃

设计目标：顶栏与底栏呈现鸿蒙沉浸光感玻璃拟态，与系统状态栏/导航条视觉融合，用户可在设置中调节光感强度。

### 3.1 档位映射（设置页「光感强度」）

| 档位 | 视觉效果 | 技术参数 |
|---|---|---|
| 关闭 | 纯色不透明 | 实色 backgroundColor，无模糊 |
| 弱 | 轻磨砂 | `backgroundBlurStyle(BlurStyle.Thin)` + 背景 alpha 0.72 |
| 中（默认） | 标准玻璃 | `backgroundBlurStyle(BlurStyle.Regular)` + alpha 0.60 + 0.5vp 分隔线 |
| 强 | 厚重光感 + 高光描边 | `backgroundBlurStyle(BlurStyle.Thick)` + alpha 0.45 + `shadow` + 0.5vp 高光描边 |

### 3.2 实现要点

1. EntryAbility 调 `setWindowLayoutFullScreen(true)`；顶栏/底栏容器用 `expandSafeArea` 延伸玻璃背景，内容区显式安全区 padding——杜绝 0.4.0「顶栏与状态栏重叠不可点」的回归。
2. 档位状态：`AppStorage` 持有 + preferences 持久化；顶/底栏组件以 `@StorageLink` 绑定，切换即时生效、无闪烁。
3. 底栏沿用 0.4.0 悬浮圆角胶囊形态（真机反馈良好），材质由纯色升级为玻璃；底栏避让手势小白条。
4. 深浅色模式随系统；玻璃档位与深浅色正交，互不影响。
5. 永久禁用 `@ohos.arkui.uiMaterial`（见总原则 4）。

## 4. 技术底座需求

- 包名：`com.miyou.app` 不变；目标 API 26（HarmonyOS 7）。
- 网络层（独立 HAR）：x-rpc 头基线 `app_version=2.117.0`、`client_type=5`、`verify_key=bll8iq97cem8`、UA 含 `Hyperion`；版本号与 salt 全部配置化，失效可热更。
- 设备身份：`device_id` 首启生成持久化；`device_fp` 经 `public-data-api device-fp/getFp` 获取，二者成对稳定，避免风控误判。
- 签名：DS1/DS2 通用实现（CryptoArchitecture Kit MD5）；GET query 排序 urlencode 后参与签名。
- 会话：Cookie 全字段落库（stuid/stoken/mid/login_ticket/ltuid/ltoken/cookie_token），加密 preferences；写接口所需字段不留短板（为 M4 预留）。
- 错误处理：retcode -100/-10001 统一跳登录；-3235 引导短信验证；1034/限流指数退避。
- 渲染：结构化内容按块映射组件；未知块/缺字段降级占位，不得崩溃。

## 5. 里程碑

| 里程碑 | 内容 | 验收标准 |
|---|---|---|
| M0 工程基座 | 新骨架（bundleName 沿用）、CI 重建并验证签名链路、网络层 HAR、网页登录 + getGameRecordCard 探活 | main 构建绿、Release 出签名 HAP；真机登录后探活返回角色数据 |
| M1 只读核心 + 光感外壳 | 光感玻璃顶/底栏 + 四档调节 + 设置页、首页信息流（推荐/四频道）、帖子详情、图片浏览 | 列表/详情全程不崩；弱网有降级提示；四档强度切换即时无闪烁；安全区无重叠 |
| M2 战绩与卡片 | 我的角色、原神/星铁/绝区零战绩、实时便签、Form Kit 服务卡片、评论浏览 | DS 签名接口通过；卡片 ≥30min 刷新；便签本地提醒可开关 |
| M3 只读补全 | 搜索、消息中心、用户主页、视频播放、版区子版块、计算器/抽卡分析（评估后排期） | 对应模块验收用例通过 |
| M4 写功能灰度（远期） | 每日签到（DS2/6X）、点赞/关注 | 前置：风控评估 + gt4 Web 兜底验证 + 小号灰度 + 用户明示开关；单独评审通过后实施 |

## 6. 风险与边界

- 接口时效：全部 API 为社区逆向，随时可能失效；渲染层兜底 + 版本/salt 配置化是生命线。
- 账号风控：device_fp/device_id 必须成对稳定；登录或查询触发 gt4 滑块时走 Web 组件兜底（gt4 为纯 H5，无平台差异）。
- 合规：README 与关于页保留「非官方、仅查看授权数据」声明；不收集账密；Cookie 仅存本机。
- 签名资产：7 个 Actions 变量为唯一签名链路来源，任何重构不得输出其明文。

—— 蓝图以上。开发中如与本文档冲突，先改文档再改代码。
