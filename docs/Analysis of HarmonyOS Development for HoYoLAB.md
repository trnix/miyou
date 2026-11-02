# 米游社 (MiHoYo BBS / Hyperion) 2.117.0 → HarmonyOS 移植分析

> 源包：`mihoyobbs_2.117.0_miyousheluodi.apk`（135.6 MB）
> 包名：`com.mihoyo.hyperion` | 版本名 `2.117.0` | versionCode `2117000`
> 生成日期：2026-10-29

---

## 1. 总览

| 项 | 值 |
|---|---|
| 应用名 | 米游社（米游社 / 米游社社区） |
| 包名 | `com.mihoyo.hyperion` |
| versionName / versionCode | `2.117.0` / `2117000` |
| minSdkVersion | 26 (Android 8.0) |
| targetSdkVersion | 32 (Android 12L) |
| compileSdkVersion | 34 (Android 14) |
| ABI | arm64-v8a, armeabi-v7a（**无 x86/x86_64**） |
| UI 框架 | **React Native + Hermes**（主界面） + Native Android（登录/支付/社区原生页面） + Jetpack Compose（局部 tooling） |
| 构建链 | Android Gradle Plugin 8.6.1 |
| 组件规模 | Activity 176、Service 25、Receiver 27、Provider 14 |
| 权限数 | 39 |

结论先行：这不是"纯 RN app"，而是**RN 容器承载论坛/内容模块，原生 Android 承载登录、支付、账号体系、推送、小部件、风控、音视频**的混合 app。移植到 HarmonyOS 不能靠 RN-for-Harmony 直接跑通，需要按模块拆分、重写原生能力。

---

## 2. 技术栈与原生依赖

### 2.1 JS / RN 层
- `libreactnative.so`、`libhermes.so`、`libjsi.so`、`libfbjni.so`
- Hermes 字节码：`assets/rncache-split/base.android.bundle`（Hermes bytecode, version 96），以及两个子 bundle：
  - `ugc-community-level-detail/index.android.bundle`
  - `mx-community-ys-squad/index.android.bundle`
- `rn-config.json` 控制子 bundle 版本/hash（热更新/RN CodePush 风格）
- Reanimated / Worklets / react-native-svg / safe-area-context：`libreanimated.so`、`libworklets.so`、`libreact_codegen_rnsvg.so`、`libreact_codegen_safeareacontext.so`
- 原生桥接声明：`assets/js/NativeCalculator.ts`、`NativeMHYAppInfo.ts`

→ 这套 RN 代码一旦转到 OHOS，**必须用 OHOS 对 RN 的 native 适配层**（或重写为 ArkUI），且 Hermes 字节码 v96 需对应引擎版本。

### 2.2 网络 / Web
- `libcronet.143.0.7445.0.so`（Chromium Cronet 143，强依赖）— WebView/网络层
- `libbdvideouploader.so`（字节跳动视频上传）
- `libvolc_log.so`（火山引擎日志）
- WebView 监控/Caching: `assets/mihoyo_web_cache/*`、`webview_monitor_js_file/*`、`web_vitals.js`
- `libpag.so` (PAG 动画，腾讯 libpag)
- `libijkplayer.so` / `libijkffmpeg.so` / `libijksdl.so` / `libffavc.so`（ijkplayer 音视频）
- `libByteVC1_dec.so` (字节视频解码)

### 2.3 图像/渲染
- `libimagepipeline.so`、`libnative-imagetranscoder.so`、`libnative-filters.so` (Fresco 图像管线)
- `libGlide-webp` (WebP 解码)
- `libavif_android.so` (AVIF)
- `libpayload?` pag

### 2.4 数据/存储
- `libmmkv.so` (MMKV KV 存储)
- `libvolc_log` (火山)
- SQLite (Room)

### 2.5 安全/风控
- Alibaba SG：`libsgmain.so` / `libsgmainso-5.5.75.so` / `libsgmiddletier.so` / `libsgsecuritybody.so` 等（阿里无线安全/SG）
- `libMHYComboCrypto.so`、`libEncryptorP.so`（米哈游自研加密）
- `libdddd.so`、`libxxxx.so`、`libxxxxxx.so`（混淆/校验 native lib，名称已混淆）

### 2.6 推送
- JPush (极光)：`cn.jpush.android.service.PushService`、`JPushReceiver`
- Xiaomi Push：`com.xiaomi.push.service.XMPushService`、`MihoyoXMPushReceiver`
- Huawei HMS Push：`com.huawei.hms.support.api.push`、`MihoyoHWPushService`、`JHonorService`
- Oppo/HeyTap：`com.heytap.msp.push.service.*`、`PluginOppoPushService`
- Vivo：`com.vivo.push.sdk.service.CommandClientService`、`MihoyoViVoPushReceiver`
- Asus push receiver

### 2.7 登录/账号/实名/风控
- 米哈游账号平台：`com.mihoyo.platform.account.miyosummer.*`（Porte 登录、QR 登录、Auth）
- 华为登录/认证：`cn.cyberidentity.certification.AUTH`、`cn.huawei.hms.activity.*`
- 腾讯 QQ / 微信：`com.tencent.connect.common.AssistActivity`、`com.tencent.tauth.AuthActivity`、`WXEntryActivity`、`WXPayEntryActivity`
- 支付宝：`com.alipay.sdk.app.*`
- Shanyan (闪验): `com.chuanglan.shanyan_sdk.view.CmccLoginAuthActivity`
- CtaApiLib / msaoaid (OAID、MSA): `libCtaApiLib.so`、`libmsaoaidauth.so`、`libmsaoaidsec.so`
- Ali Biometrics (实人认证): `com.alibaba.security.biometrics.*`、`com.alibaba.security.realidentity.*`、`libALBiometricsJni.so`、`libaab.so`、`libfacedevice.so`
- DTF face: `com.dtf.face.ui.*`、`toyger.face.dat`、`libtoyger.so`、`libfacedevice.so`
- ZKFV / BIO: `libzkfv_tj.so`

### 2.8 支付
- 米哈游 SDK 支付：`com.mihoyo.sdk.payplatform.cashier.CashierActivity`
- 支付宝 SDK：`com.alipay.sdk.app.*`
- 微信支付：`WXPayEntryActivity`
- Apple Pay (APay)：`com.alipay.sdk.app.APayEntranceActivity` (或 Apple Pay for CN)

### 2.9 埋点/APM
- 字节跳动 APMPlus：`com.bytedance.apm6.*`、`com.bytedance.applog.*`
- `com.bytedance.frameworks.core.apm.contentprovider.MonitorContentProvider`

### 2.10 ML/识别
- MLKit (条码): `com.google.mlkit.common.internal.MlKitComponentDiscoveryService`、`libbarhopper_v3.so`、`mlkit_barcode_models`
- Face model: `faceContinuity.bin`、`fdmodel.bin`、`ldClassifier.bin`、`ldmodel.bin`

### 2.11 频道/小部件
- 主屏小部件 (AppWidgetProvider)：`GenshinCalendarWidgetProvider`、`StarRailCalendarWidgetProvider`、`NapAvatarWidgetProvider`、`NapWidgetProvider`、`StarRailWidgetProvider`、`GenshinWidgetProvider`
- `WidgetPackageReplacedReceiver`

### 2.12 视频/图片验证码
- Geetest gt4: `assets/gt4.js`、`gt4-loading.gif`、`gt4-index.html`

### 2.13 国产 ROM 适配
- OPPO/Oplus: `com.coloros.mcs.permission.RECIEVE_MCS_MESSAGE`、`oplus.permission.settings.LAUNCH_FOR_EXPORT`
- 华为/荣耀: `com.hihonor.*`、`com.huawei.hms.*`
- vivo 通知徽标: `com.vivo.notification.permission.BADGE_ICON`
- Asus supplementary DID: `com.asus.msa.SupplementaryDID.ACCESS`
- 免费 ME (freemme) MSA: `freemme.permission.msa`

### 2.14 蓝牙/其他
- `android.permission.BLUETOOTH`
- `REQUEST_INSTALL_PACKAGES`（下载 APK 更新米游社/游戏）
- `SYSTEM_ALERT_WINDOW`（悬浮窗）
- `RECEIVE_BOOT_COMPLETED`
- `FOREGROUND_SERVICE`

---

## 3. 功能模块划分（按 Activity 命名推断）

| 模块 | 关键 Activity/Service | 备注 |
|---|---|---|
| 启动/闪屏 | `SplashActivity` (main launcher) | 需重写启动页 |
| 主壳 | `HyperionMainActivity` | RN 容器 + 原生导航 |
| 账号/登录 | `PorteLoginActivity`、`PorteAuthActivity`、`PorteQRConfirmActivity`、`CertificationActivity`、`InitAccountActivity`、`EditUserInfoActivity` | 米哈游自研 Porte 登录体系 |
| 用户资料 | `UserHomePageActivity`、`UserProfileActivity`、`FollowActivity`、`FansActivity`、`RecommendActivity` | |
| 会员/商品 | 通过 RN | |
| 话题/版块 | `TopicActivity`、`RelateTopicActivity` | |
| 帖子 | `PostDetailActivity`、`PostPictureDetailActivityV2`、`UgcPostDetailActivity`、`PostRouterActivity` | 图文、UGC |
| 视频 | `VideoDetailActivity`、`VideoUploadActivity`、`DeeplinkVideoDetailActivity`、ijkplayer | |
| 图片查看 | `PictureViewerActivity`、`ImagesViewerActivityV2`、`PostPictureDetailActivityV2` | |
| 编辑器/发布 | `PublishActivity`、`PostFeedbackEditActivity`、`DraftBoxActivity`、`LotteryEditActivity`、`PostAddVoteActivity` | RN + native |
| 评论 | `CommentDetailActivity`、`CommentReplyActivity` | |
| 消息/IM | `SingleChatActivity`、`MsgListActivity`、`MsgUnfollowActivity`、`VillaChatCustomEmoticonManagerActivity` | 自研 IM |
| 搜索 | `GlobalSearchActivity` | |
| 游戏中心 | `GameCenterActivity`、`GameDetailActivity`、`GameLoginActivity`、`GameOrderHistoryActivity`、`GameWebViewActivity2` | 嵌入游戏启动/登录 |
| 设置 | `MysSettingsActivity`、`PrivacySettingsComposeActivity`、`NotificationSettingComposeActivity`、`SecuritySettingActivity`、`AboutMysActivity` | Compose UI 出现 |
| 青少年模式 | `HyperionMainTeenageActivity`、`TeenageTipsActivity`、`TeenagePasswordActivity` | |
| 投诉/举报 | `HyperUserReportActivity`、`HyperReportSuccessActivity`、`AppealActivity`、`AiReportActivity` | |
| WebView 容器 | `MiHoYoWebActivity`、`UrlCheckDialogActivity` | 大量 H5 页面 |
| WebPay | `CashierActivity` | |
| 小组件 | `GenshinCalendarWidgetProvider` 等 (Remote Views) | 必须重写 |
| 扫码 | `ScanActivity` (ZXing/MLKit barhopper) | |
| C2C/插入 | `InstantAddActivity`、`InstantForwardDelegateActivity`、`HalfScreenTopicSelectActivity` | |
| 集合/专题 | `CollectionDetailActivity`、`CollectionManageActivity`、`CollectionSortActivity`、`CreateCollectionActivity` | |
| 个人主页装修 | `AvatarFrameEditActivity`、`AvatarCircleSelectActivity`、`EditNicknameActivity` | |
| RN 容器 | `MYSReactActivity` | 单 Activity 承载 RN |
| 三方登录回调 | `WXEntryActivity`、`WXPayEntryActivity`、`AuthActivity` (QQ)、`H5PayActivity` | |
| UMeng? | - | |
| 更新器 | `VersionCheckActivity?` / `DownloadIntentService` (下载更新包) | REQUEST_INSTALL_PACKAGES |

---

## 4. 第三方服务依赖矩阵

| 类别 | 服务 | 用途 | 鸿蒙替代 | 风险 |
|---|---|---|---|---|
| 推送 | JPush / 小米/华为/Oppo/Vivo | 多通道推送、角标、通知 | 鸿蒙 Push Kit / 分布式通知；第三方推送 SDK 多数不支持 OHOS | 高 |
| 登录 | 米哈游 Porte、微信/QQ、支付宝、闪验、华为 | 账号/SSO/短信 | 鸿蒙 Account Kit / Huawei ID；微信/QQ/支付宝 OHOS SDK 是否提供 | 高 |
| 支付 | 米哈游 Cashier、支付宝、微信 | 充值/ gating | 鸿蒙 Pay Kit + 各自 OHOS 版 SDK；无则走网页支付 | 高 |
| 实人认证 | 阿里 biometrics / DTF face / Toyger | 实名认证 | 需厂商提供 OHOS SDK 或走 H5 | 高 |
| 风控/安全 | Alibaba SG、msa/OAID、CtaApi | 设备指纹、风控 | 鸿蒙 Device Security / OAID 等价 API；SDK 需 OHOS 版 | 高 |
| 网络 | Cronet 143 | HTTP/gRPC/QUIC | 鸿蒙 @ohos.net.http 或保留 Cronet（需 OHOS 构建） | 中 |
| 图片/媒体 | Fresco、Glide、ijkplayer、PAG、AVIF、ByteVC1 | 媒体 | ArkUI Image + OHOS 媒体库/AVCodec | 中高 |
| 存储 | MMKV | KV | `@ohos.data.preferences` / 分布式 KV | 低 |
| 埋点 | ByteDance APMPlus/AppLog | 埋点/APM | 自研上报或 vendor OHOS SDK | 中 |
| ML | MLKit (条码扫描) | 扫码 | 鸿蒙 Scan Kit / Barcode | 低 |
| 验证码 | Geetest gt4 | 人机验证 | H5/Web 无平台差异 | 低 |
| 小部件 | RemoteViews + AppWidgetProvider | 桌面小组件 | 鸿蒙 Form Kit | 高（需重写） |
| 更新器 | REQUEST_INSTALL_PACKAGES + DownloadIntentService | APK 自更新 | 鸿蒙不开放静默安装；需引导应用市场/系统安装器 | 高 |

---

## 5. 鸿蒙 (HarmonyOS) 移植关键缺口

### 5.1 平台/ABI
- 原生 so 仅 arm64-v8a/armeabi-v7a，**无鸿蒙 .so**。所有 native lib（RN、Hermes、Cronet、ijkplayer、PAG、Alibaba SG、米哈游 crypto、Face/Toyger、MSA/OAID、MMKV…）需要：
  - 各 vendor 提供 OHOS 版，或
  - 用 OHOS 原生能力替换，或
  - 通过 NAPI 跨编译（工程量巨大，Alibaba SG / Face SDK 闭源不可编）。

### 5.2 minSdk 26 vs OHOS API
- Android minSdk 26 已清掉大量旧 API；但 targetSdk 32 的若干行为（通知权限 POST_NOTIFICATIONS、运行时权限、后台限制）在 OHOS 上有等价但不同的模型：**鸿蒙权限在 module.json5 声明 + 运行时 requestPermissionsFromUser**，FG Service / 后台任务模型不同。

### 5.3 React Native for Harmony
- RN on Harmony (OpenHarmony) 通过 `@react-native-oh/react-native-harmony` 适配。Hermes 字节码 v96 与之对应版本强耦合；子 bundle 热更新（rncache-split）需重新验证。且 RN 能力（Camera、Push、Pay、Biometrics 等）需要一一用 OHOS 模块替换，原生模块（NativeCalculator、NativeMHYAppInfo）需用 NAPI 重写。

### 5.4 通知/推送架构
- 鸿蒙不支持 Android 的多厂商通道 SDK（小米/OPPO/Vivo/HMS 仅华为系）。需要接入 **Push Kit**（华为 HMS Push 升级版）+ OHOS 通知；角标策略不同（`com.hihonor.android.launcher.permission.CHANGE_BADGE` 等不再适用）。

### 5.5 小部件
- Android `AppWidgetProvider`/RemoteViews → **Form Kit**（服务卡片），布局/更新机制完全重写；6 个小组件全部重做。

### 5.6 自更新
- `REQUEST_INSTALL_PACKAGES` 不在 OHOS 存在。更新策略改为：引导用户到应用市场，或在企业/分发场景走分发包。需要调整 `DownloadIntentService` / 升级逻辑。

### 5.7 实人认证 & 风控
- 阿里云实人认证、DTF Face、Shanyan、OAID/MSA、Alibaba SG 多为 Android 专属 SDK。除非厂商提供 OHOS 版，否则只能走 H5/云函数方案，失败率与体验下降。

### 5.8 媒体/图片
- Fresco/iijkplayer/PAG/ByteVC1 在 OHOS 需对应替代（OHOS AVCodec、`@ohos.multimedia.media`、OHOS PAG）；WebP/AVIF 解码需 OHOS ImageSource 支持版本确认。

### 5.9 系统能力映射
- `SYSTEM_ALERT_WINDOW` 悬浮窗：OHOS 无直接等价，需 `@ohos.window` + 特殊权限或放弃。
- `GET_TASKS`：OHOS 不开放。
- `WRITE_SETTINGS`：OHOS 设置写入受限。
- `RECEIVE_BOOT_COMPLETED` → `ohos.permission.RECEIVE_BOOT_COMPLETED`（需申请，且 Stage 模型下 Ability 启动路径不同）。
- 文件访问：Android `FileProvider`/SAF → OHOS `fileuri`/`@ohos.file.fs` 沙箱，需要重新设计文件分享路径。
- 剪贴板/分享：`@ohos.pasteboard`、Share Kit。

---

## 6. 推荐移植路径

1. **评估/决策阶段**（1–2 周）：确认 RN-for-Harmony 版本与 Hermes v96 兼容性；盘点所有 native 模块（NativeCalculator、NativeMHYAppInfo、支付/登录/Push/Face SDK 是否有 OHOS 版）；向厂商询 OHOS SDK 可得性。
2. **骨架层**（2–4 周）：DevEco Studio 工程；module.json5 权限/Ability 定义；基础网络（Cronet 或 OHOS http）、图片/视频/存储 替代层；mmkv→preferences。
3. **账号&登录**（3–5 周）：米哈游 Porte 登录 OHOS 版 or WebView 容器化；微信/QQ/支付宝 OHOS SDK 接入；实名认证 H5 兜底。
4. **推送**（2–3 周）：Push Kit + 重新设计通知 channels。
5. **RN 容器迁移**（3–6 周）：RN-for-Harmony + 重建原生模块；base/sub bundle 热更新验证；Reanimated/Worklets 适配。
6. **社区内容模块**（4–8 周）：帖子详情/视频/图片/UGC 组件、IM 聊天（SingleChat）、消息中心。
7. **游戏中心**（2–3 周）：游戏启动/登录桥接（可能仅跳转应用市场）。
8. **支付**（2–3 周）：Cashier + OHOS Pay/网页支付兜底。
9. **小部件**（2–3 周）：Form Kit 重构 6 个 widget。
10. **设置/青少年/隐私/更新器**（2 周）：权限写入/更新器改造。
11. **测试&发布**：真机（Mate 60+/Harmony NEXT）QA、审核、分发。

粗估总工期：**4–6 个月**（强依赖厂商 OHOS SDK 可得性；若无 OHOS SDK 则 +50% 兜底 H5/云化）。

---

## 7. 需在移植前向厂商/团队确认的问题（阻断项）

1. 米哈游 SDK（Porte 登录、Cashier 支付、推送聚合、更新器）是否有 HarmonyOS 版本？
2. 阿里云实人认证 / DTF Face / Toyger 是否支持 OHOS？无则走 H5。
3. 微信/QQ/支付宝的 OHOS SDK 是否已有（最低版本要求）？
4. JPush 是否支持 OHOS； otherwise 改 Push Kit。
5. Cronet 143 是否需要自编 OHOS .so，或改用 OHOS http 客户端。
6. ijkplayer / PAG 是否有 OHOS 构建（或换 OHOS 媒体库）。
7. Alibaba SG / MSA / OAID 是否有 OHOS 版；否则替换为 OHOS Device Security。
8. Geetest gt4 Web 验证码在 OHOS WebView 是否正常（WebView 内核差异）。

---

## 8. 验证清单（建议）

- [ ] 启动/闪屏 → 主页（RN 容器启动时间 ≤ 2s 于 Mate 60）
- [ ] 登录全链路：Porte 账号、微信/QQ、短信（闪验）、华为账号、实名认证
- [ ] 推送：前台/后台/杀死态通知到达、角标
- [ ] 媒体：帖子图片/视频播放、上传、PAG 动画
- [ ] 支付：米游币充值、游戏内购流转
- [ ] IM：单聊收发、图片/语音
- [ ] 小部件：6 个小组件渲染与点击跳转
- [ ] 更新器：引导下载/安装新版本
- [ ] 青少年模式/隐私设置/权限授权矩阵
- [ ] 弱网与离线缓存（rncache bundle）

---

## 附录 A：组件清单摘要

- Activities: 176（含 luck.picture/lib、yalantis.ucrop、alipay、wechat、huawei hms、jpush、sina weibo、alibaba biometrics/realidentity、dtf face、shanyan 等三方）
- Services: 25（推送服务族：JPush/Xiaomi/Huawei/Oppo/Vivo/HeyTap + WorkManager + DownloadService + Volc engine + MLKit discovery + MlKit + AGConnect）
- Receivers: 27（含 6 个 AppWidgetProvider、Push receivers for 各 vendor、WorkManager、ProfileInstaller）
- Providers: 14（FileProvider 系列、JPush InitProvider、MLKit/AGConnect/Huawei InitProvider、Startup InitializationProvider、MonitorContentProvider、FeatureFlag）

## 附录 B：原生 .so 清单（arm64-v8a）

关键：`libreactnative.so`、`libhermes.so`、`libcronet.143.0.7445.0.so`、`libijkplayer/ffmpeg/sdl`、`libpag.so`、`libmmkv.so`、`libreanimated.so`、`libworklets.so`、`libfbjni.so`、`libjsi.so`、`libimagepipeline.so`、`libsgmain*.so`/`libsgsecuritybody*.so`、`libMHYComboCrypto.so`、`libEncryptorP.so`、`libALBiometricsJni.so`、`libaab.so`、`libfacedevice.so`、`libtoyger.so`、`libShanYCore.so`、`libCtaApiLib.so`、`libmsaoaid*.so`、`libgdvideouploader.so`、`libvolc_log.so`、`libbarhopper_v3.so`、`libapminsighta/b.so`、`libdddd.so`/`libxxxx*.so`（混淆）、`libc++_shared.so`、`librtmp-jni.so`、`libsora_kaito.so`、`libvcn*.so`（视频编解码）。

## 附录 C：assets 目录精选

`hyper_main_pags/`（PAG 动画）、`mihoyo_web_cache/`、`js/NativeCalculator.ts`、`js/NativeMHYAppInfo.ts`、`rncache-split/`（RN Hermes bundle + 子 bundle）、`mlkit_barcode_models/`、`toyger.face.dat`、`gt4.js/gt4-index.html`、`webview_monitor_js_file/`、`JSBridgeUnitTest.html`/`WebCacheTestPage.html`、`game_order_test.html`。

---

*本分析基于 APK 静态反编译（androguard）与未解压 native/混淆库的表面信息；混淆符号（dddd/xxxx）与部分生态 SDK 无法进一步还原。移植前务必结合源码仓与各 SDK 官方 OHOS 支持清单复核。*