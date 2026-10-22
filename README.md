# 米柚(MiYou · 非官方米游社鸿蒙原生客户端)

以 ArkTS/ArkUI 编写的非官方米游社第三方客户端骨架,目标 API 26(HarmonyOS 7),支持手机/折叠屏/平板自适应布局。

**阶段 0 目标**:跑通「GitHub Actions 云端构建 → 签名 → Release → hdc 侧载到手机」的完整闭环。当前仓库里只有一个空白首页,验证基础设施后再逐步填充功能。

**当前状态说明**:本工程按 API 26 官方规范配置(compatibleSdkVersion `26.0.0`、hvigor modelVersion `26.0.0`、CI 使用 JDK 21,依据为[华为官方流水线文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-command-line-building-app)与[命令行工具文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/ide-commandline-get-V5)),但 Command Line Tools 需登录华为账号后才能从下载中心获取直链,因此尚未在本地完成真实编译验证——**首次 CI 运行用于验证编译,成功产出 HAP 才算编译通过**,报错时对照下方排查表处理。

## 必读风险

- **命名与素材**:本项目与米哈游无关,请勿使用「米游社」名称和米哈游的图标/素材进行公开发布,避免侵权投诉。
- **账号风控**:后续接入米游社接口时,尚未确认官方开放接口及第三方授权范围,存在账号被限制的可能,建议使用小号。
- **接口时效**:米游社接口随时可能变动,社区文档(UIGF-org/mihoyo-api-collect)已归档,后续需自行抓包维护。

## 目录结构

```
├── .github/workflows/build.yml   # CI:下载工具链 → 构建 → 签名 → 上传 Release
├── scripts/sign.sh                # 用 hap-sign-tool 给 HAP 签名
├── docs/signing.md                # 申请调试证书/Profile 并配置 Secrets 的完整指南
├── docs/sideload.md               # 手机侧载安装指南
├── AppScope/app.json5             # 应用级配置(bundleName 必须与 AGC 一致)
├── build-profile.json5            # 工程级构建配置(SDK 版本、产品)
├── hvigor/hvigor-config.json5     # hvigor 版本配置(modelVersion 26.0.0)
└── entry/                         # 主模块
    └── src/main/
        ├── module.json5           # 模块配置(权限、设备类型)
        └── ets/pages/Index.ets     # 首页(GridRow 断点自适应示例)
```

## 快速开始(阶段 0 闭环)

按顺序完成以下 6 步:

1. **实名认证**:登录 [华为开发者联盟](https://developer.huawei.com/consumer/cn/),完成个人开发者实名认证。
2. **AGC 创建应用**:在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/agconnect/) 「我的项目」中新建项目并添加 HarmonyOS 应用,**包名必须与本仓库 `AppScope/app.json5` 中的 `bundleName` 完全一致**(默认 `com.miyou.app`,可自行修改)。
3. **申请签名材料**:按 [docs/signing.md](docs/signing.md) 生成密钥和 CSR,在 AGC 申请调试证书、注册手机 UDID、申请调试 Profile。
4. **配置 GitHub**:在仓库 **Settings → Secrets and variables → Actions** 中添加:
   - **Variables(1 个)**:`CLI_TOOLS_URL` = 华为下载中心「Command Line Tools」Linux x86-64 版直链(需登录后获取,方法见 [docs/signing.md](docs/signing.md))
   - **Secrets(6 个)**:`SIGNING_P12`、`SIGNING_CERT`、`SIGNING_PROFILE`(三个文件各自 base64 后的文本)、`SIGNING_KEY_ALIAS`、`SIGNING_KEYSTORE_PASSWORD`、`SIGNING_KEY_PASSWORD`
5. **触发构建**:
   - 推送到 `main` 分支 → 构建并在 Artifacts 中查看产物(未配置签名 Secrets 时会上传未签名包,仅用于验证编译)
   - 推送 `v0.1.0` 之类的 **tag** → 构建并自动创建 GitHub Release(必须已配置签名,否则构建失败,不会发布未签名包)
6. **侧载安装**:下载 Release 中的 `app-signed.hap`,按 [docs/sideload.md](docs/sideload.md) 用 `hdc install` 装到手机。

## 工作流说明

CI 做了这些事(全部在云端,本地无需安装 DevEco Studio):

1. 检出代码,装 JDK 21(26.0.0 及以上版本工具链的官方推荐)和 libgl1-mesa-dev
2. 从 `CLI_TOOLS_URL` 下载华为官方 Command Line Tools(内嵌 HarmonyOS SDK、hvigor、ohpm、hdc,自带配套 Node.js)
3. 配置 ohpm 仓库源,安装工程及 entry 模块依赖
4. `hvigorw assembleHap` 构建 HAP
5. 用 `hap-sign-tool` 以调试证书签名(材料来自 Secrets,不进仓库;tag 构建缺材料直接失败)
6. 上传 Artifacts;若是 tag 推送,则同时创建 Release

## 常见问题排查

| 现象 | 原因与处理 |
|---|---|
| hvigor 报 modelVersion / SDK 版本不匹配 | 本工程按 API 26(`modelVersion: "26.0.0"`、`compatibleSdkVersion: "26.0.0"`)配置。若你下载的 Command Line Tools 是其他版本,先运行 `hvigorw -v` 查看工具链版本,再把 `hvigor/hvigor-config.json5` 与 `build-profile.json5` 中的版本号调成一致 |
| 下载 Command Line Tools 失败 | 下载中心直链会随版本更新失效,登录后重新复制链接并更新 `CLI_TOOLS_URL` 变量 |
| 签名步骤报 keyAlias / 口令错误 | 检查 `SIGNING_KEY_ALIAS` 是否与生成 .p12 时用的别名一致,两个密码 Secret 是否填对 |
| 安装提示签名校验失败 | 按顺序检查:1) 当前设备 UDID 是否已注册进调试 Profile(按 docs/signing.md);2) 调试证书与 Profile 是否在有效期内;3) CI 是否用了正确的调试证书 Secrets |
| 证书或 Profile 到期 | 调试证书和调试 Profile 各有有效期,请在 AGC 页面查看实际到期时间,到期前重新申请并更新对应 Secrets |
| HAP 构建成功但装不上别的设备 | 正常现象:调试包只能安装到 Profile 里注册过的设备,不是通用发行包 |

## 多端适配说明

首页使用 `GridRow`/`GridCol` 断点布局:窗口 < 600vp 时 1 列,600–840vp 时 2 列,>840vp 时 3 列。折叠屏展开、平板横屏、2in1 设备都会自动切换列数,这是「一次开发、多端部署」的基本功,后续页面都沿用这个模式。注意:骨架代码只是布局层面的准备,真机上的实际显示效果尚未验证,装上手机后请在不同窗口宽度下确认。
