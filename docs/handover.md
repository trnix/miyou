# 米柚项目交接文档(AI Handover)

> 本文档面向接手本仓库的人或 AI。**2026-10-30 更新：项目按「官方架构为蓝图的原生重写」路线重启，main 旧代码已于当日清空；旧 0.4.0 骨架完整归档于分支 `archive/v0.4-skeleton`（同一提交 `af799e1` 亦有 tag `v0.4.0-b31`），随时可取回参考。** 仓库保留 Actions 变量(Secrets/Variables)、docs/ 与 scripts/sign.sh；只要这 7 个变量未动，任何新的鸿蒙工程放入本仓库即可直接复用自动构建与签名。

---

## 1. 项目概况与历史

- **米柚(MiYou)**:非官方米游社原生鸿蒙客户端，ArkTS/ArkUI 编写，目标 API 26(HarmonyOS 7)，云端 CI 构建后 hdc 侧载调试包。
- **历史版本**:0.1.0 骨架 + CI 闭环 → 0.2.0 沉浸光感首页 → 0.3.0 四标签应用外壳(社区/官方/工具/我的)→ 0.4.0 崩溃修复(移除实验性 uiMaterial)+ 悬浮沉浸底栏 + 四游戏频道 + 只读评论区 + 官方网页登录。专用 CI 机制:push 到 main 自动签名并创建预发布 Release,无需手工建 tag。
- **停止原因**:由原开发者决定放弃，仅供后续复用流水线资产。（2026-10-30 更新：项目已按原生重写路线重启，本节后文为 0.4.0 时代历史记录。）
- **法律风险**:本项目与米哈游无隶属关系。公开发布不得使用「米游社」名称或米哈游素材图标；接入官方接口存在账号风控与接口时效风险，建议仅用小号。

## 2. 保留的 Actions 变量(7 个)

位置:Settings → Secrets and variables → Actions。这些值与代码文件无关，删文件不影响，删仓库才会丢。

| 变量 | 类型 | 作用 | 生命周期注意 |
|---|---|---|---|
| `CLI_TOOLS_URL` | Variable 或 Secret | 华为 Command Line Tools(Linux x86-64)下载直链，内嵌 SDK/hvigor/ohpm/hdc/Node.js | 需登录华为账号获取；直链随官方版本更新会失效，失效后重新复制并更新此值 |
| `SIGNING_P12` | Secret | 签名密钥库 .p12 的 base64 文本 | 换别名/密码需重新生成并连带换证书 |
| `SIGNING_CERT` | Secret | 调试证书 .cer 的 base64 | AGC 申请，有有效期，到期前重申请并更新 |
| `SIGNING_PROFILE` | Secret | 调试 Profile .p7b 的 base64 | **绑定具体手机 UDID**；换设备必须先在 AGC 注册设备、重新下载 Profile 并更新此 Secret，否则新手机装不上 |
| `SIGNING_KEY_ALIAS` | Secret | 生成 .p12 时用的密钥别名 | 必须与 .p12 配套 |
| `SIGNING_KEYSTORE_PASSWORD` | Secret | p12 密钥库密码 | — |
| `SIGNING_KEY_PASSWORD` | Secret | 密钥密码 | 可与上一项相同 |

### 安全与备份须知(最重要)

1. GitHub Secret **只能写入/覆盖，永远无法读取**。若本地没有 .p12/.cer/.p7b 原文件与两个密码、别名的备份，GitHub 里的值换仓库即丢失——届时只能重新申请整会，且**旧证书签出的所有包都装不上**(除非新包用同一密钥源)。
2. 现在立刻在本地备份以上原始文件与口令，并记录 AGC 中证书到期日期。
3. 这些材料属敏感资产，不要放进任何代码库或聊天记录.pr 脚本/workflow 中只吃 Secret,不落原文件。

## 3. GitHub 自动打包 HAP 全流程(重建指南)

在新工程重建 `.github/workflows/build.yml` 即可，流程共 8 步:

1. **触发**:push 到 main(自动预发布)或推送 `v*` tag(正式发布)。
2. **环境**:Ubuntu runner + JDK 21(API 26 工具链官方推荐)+ `libgl1-mesa-dev`。
3. **下载工具链**:`curl -fL "$CLI_TOOLS_URL"` 解压至 `$HOME/ohos`,将 `command-line-tools/bin` 与 `tool/node/bin` 加入 PATH。**保留架构自检**(验证 tool/node/bin/node 能跑),避免下到 ARM64/macOS 版导致后段才报 Exec format error。
4. **装依赖**:`ohpm config set registry https://ohpm.openharmony.cn/ohpm/` → `ohpm install --all`(工程根 + entry 模块)。
5. **构建**:`hvigorw assembleHap --mode module -p product=default -p buildMode=release --no-daemon`,产物:`entry/build/default/outputs/default/entry-default-unsigned.hap`。
6. **签名**:将 3 个 base64 Secret 解码为 .p12/.cer/.p7b,执行工具链自带 `hap-sign-tool.jar sign-app -mode localSign`。缺材料时策略:非 tag 构建放行未签名包(仅验证编译);tag 构建直接失败。**缺签名 Secrets 时还应自动跳过 Release 并输出中文引导警告**。
7. **产出**:`actions/upload-artifact@v4` 备档 dist/；签名成功 → `softprops/action-gh-release@v2` 建 Release 附 `app-signed.hap`(main 用 `v{versionName}-b{run_number}` 自动 tag 打 prerelease;tag 用原名打正式版并 latest)。
8. **安装**:Release 下载 → `hdc install app-signed.hap`。调试包**只能装到 Profile 注册过的设备**。

### 3.1 参考实现:build.yml(原文收录)

版本号读取自 `AppScope/app.json5` 的 `versionName`;警告步骤的 echo 务必用块标量 `run: |`(半角冒号+空格会破坏 YAML plain scalar,这是血泪教训)。

```yaml
name: Build & Release HAP

on:
  push:
    branches: [main, 'feature/**']
    tags: ['v*']
  workflow_dispatch:

permissions:
  contents: write

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up JDK 21
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'

      - name: Install build dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y libgl1-mesa-dev

      - name: Download HarmonyOS Command Line Tools
        env:
          CLI_TOOLS_URL: ${{ vars.CLI_TOOLS_URL || secrets.CLI_TOOLS_URL }}
        run: |
          if [ -z "$CLI_TOOLS_URL" ]; then
            echo "::error::缺少 CLI_TOOLS_URL。请在仓库 Settings → Secrets and variables → Actions 里添加。"
            exit 1
          fi
          curl -fL --retry 3 "$CLI_TOOLS_URL" -o /tmp/cli-tools.zip
          unzip -q /tmp/cli-tools.zip -d "$HOME/ohos"
          NODE_BIN="$HOME/ohos/command-line-tools/tool/node/bin/node"
          if [ ! -f "$NODE_BIN" ]; then
            echo "::error::解压后未找到 tool/node/bin/node，请确认下载的是 Linux 版"
            exit 1
          fi
          if ! "$NODE_BIN" -v >/dev/null 2>&1; then
            echo "::error::工具包内 Node 无法在当前架构运行，请重新复制 Linux x86-64 版直链"
            exit 1
          fi

      - name: Build unsigned HAP
        run: |
          export PATH="$HOME/ohos/command-line-tools/bin:$HOME/ohos/command-line-tools/tool/node/bin:$PATH"
          ohpm config set registry https://ohpm.openharmony.cn/ohpm/
          (cd entry && ohpm install --all)
          ohpm install --all
          hvigorw clean --no-daemon
          hvigorw assembleHap --mode module -p product=default -p buildMode=release --no-daemon

      - name: Resolve release info
        id: rel
        run: |
          VERSION=$(sed -n 's/.*"versionName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' AppScope/app.json5 | head -1)
          if [ -z "$VERSION" ]; then
            echo "::error::无法从 AppScope/app.json5 读取 versionName"
            exit 1
          fi
          case "$GITHUB_REF" in
            refs/tags/*) TAG="${GITHUB_REF#refs/tags/}" ;;
            *) TAG="v${VERSION}-b${GITHUB_RUN_NUMBER}" ;;
          esac
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "tag=$TAG" >> "$GITHUB_OUTPUT"

      - name: Sign HAP
        env:
          SIGNING_P12: ${{ secrets.SIGNING_P12 }}
          SIGNING_CERT: ${{ secrets.SIGNING_CERT }}
          SIGNING_PROFILE: ${{ secrets.SIGNING_PROFILE }}
          SIGNING_KEY_ALIAS: ${{ secrets.SIGNING_KEY_ALIAS }}
          SIGNING_KEYSTORE_PASSWORD: ${{ secrets.SIGNING_KEYSTORE_PASSWORD }}
          SIGNING_KEY_PASSWORD: ${{ secrets.SIGNING_KEY_PASSWORD }}
          RELEASE_MODE: ${{ startsWith(github.ref, 'refs/tags/') }}
        run: bash scripts/sign.sh

      - name: Detect signing result
        id: sign
        run: |
          if [ -f dist/app-signed.hap ]; then
            echo "signed=true" >> "$GITHUB_OUTPUT"
          else
            echo "signed=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Verify signed HAP (tag builds only)
        if: startsWith(github.ref, 'refs/tags/')
        run: test -f dist/app-signed.hap || { echo "::error::tag 发布构建必须产出已签名 HAP，请检查签名 Secrets"; exit 1; }

      - name: Warn when auto-release skipped
        if: ${{ github.ref == 'refs/heads/main' && steps.sign.outputs.signed == 'false' }}
        run: |
          echo "::warning::未配置签名 Secrets，已跳过自动 Release，请按交接文档补齐。"

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: hap
          path: dist/
          if-no-files-found: error

      - name: Create GitHub Release
        if: ${{ steps.sign.outputs.signed == 'true' && (github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/')) }}
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ steps.rel.outputs.tag }}
          name: 米柚 ${{ steps.rel.outputs.tag }}
          prerelease: ${{ github.ref == 'refs/heads/main' }}
          make_latest: ${{ github.ref != 'refs/heads/main' }}
          files: dist/app-signed.hap
```

### 3.2 参考实现:scripts/sign.sh(原文收录)

```bash
#!/usr/bin/env bash
# 用 hap-sign-tool 签名。材料来自 GitHub Secrets(base64)。
# RELEASE_MODE=true 时缺少任何签名材料直接失败。
set -euo pipefail

mkdir -p dist

HAP="entry/build/default/outputs/default/entry-default-unsigned.hap"
if [ ! -s "$HAP" ]; then
  echo "::error::未找到构建产物 HAP"
  exit 1
fi

if [ -z "${SIGNING_P12:-}" ]; then
  if [ "${RELEASE_MODE:-}" = "true" ]; then
    echo "::error::tag 发布构建必须配置全部签名 Secrets"
    exit 1
  fi
  echo "::warning::未配置签名 Secrets,仅上传未签名 HAP"
  cp "$HAP" dist/app-unsigned.hap
  exit 0
fi

for v in SIGNING_CERT SIGNING_PROFILE SIGNING_KEY_ALIAS SIGNING_KEYSTORE_PASSWORD SIGNING_KEY_PASSWORD; do
  if [ -z "${!v:-}" ]; then
    echo "::error::缺少签名 Secret: $v"
    exit 1
  fi
done

mkdir -p .sign
printf '%s' "$SIGNING_P12" | base64 -d > .sign/debug.p12
printf '%s' "$SIGNING_CERT" | base64 -d > .sign/debug.cer
printf '%s' "$SIGNING_PROFILE" | base64 -d > .sign/debug.p7b

SIGN_TOOL=$(find "$HOME/ohos" -name "hap-sign-tool.jar" -type f | head -1)
if [ -z "$SIGN_TOOL" ]; then
  echo "::error::未找到 hap-sign-tool.jar"
  exit 1
fi

java -jar "$SIGN_TOOL" sign-app \
  -keyAlias "$SIGNING_KEY_ALIAS" \
  -signAlg "SHA256withECDSA" \
  -mode "localSign" \
  -appCertFile ".sign/debug.cer" \
  -profileFile ".sign/debug.p7b" \
  -inFile "$HAP" \
  -outFile "dist/app-signed.hap" \
  -keystoreFile ".sign/debug.p12" \
  -keystorePwd "$SIGNING_KEYSTORE_PASSWORD" \
  -keyPwd "$SIGNING_KEY_PASSWORD"

echo "签名完成: dist/app-signed.hap"
```

## 4. 签名材料生命周期(AGC 操作)

若材料过期或丢失，在 AppGallery Connect 重新准备:

1. 华为开发者联盟完成实名认证。
2. AGC「我的项目」→ 新建项目 → 添加 HarmonyOS 应用，**包名必须与工程 `AppScope/app.json5` 的 `bundleName` 一致**(原项目:`com.miyou.app`)。
3. 本地生成密钥:`keytool -genkeypair -alias <别名> -keyalg EC -groupname secp256r1 -sigalg SHA256withECDSA -keystore debug.p12 -storetype p12`,随后生成 CSR。
4. AGC「证书、APP ID 和 Profile」→ 申请调试证书(下载 .cer)→ 注册测试设备 UDID(手机 `hdc shell bm get -u` 获取)→ 申请调试 Profile(下载 .p7b)。
5. 三个文件分别 `base64 -w 0` 后填入对应 Secret；别名与两个密码填入其余三个 Secret。
6. 调试证书与 Profile 各有有效期，**到期前必须重申请并更新 Secrets**，否则侧载失败。

## 5. 0.4.0 应用现状(供复活项目参考)

架构:单模块 entry,入口 `pages/AppShell` 四标签外壳；页面:`Index`(完整首页)、`PostDetail`(详情+评论)、`ToolWeb`(官方工具 WebView)、`Login`(官方网页登录)。层:`net/MiyousheApi.ts` + `model/MiyousheModels.ts` + `utils/Format.ts` + `utils/Auth.ts`(Cookie/preferences)。

使用过的米游社只读接口(网页匿名可用，时效性已实测至 2026-10-22):
- `https://bbs-api-static.miyoushe.com/apihub/wapi/webHome?gids=游戏ID&page=N&page_size=M` — 首页推荐/轮播/话题/置顶/月榜
- `https://bbs-api.miyoushe.com/post/wapi/getPostFull?post_id=` — 帖子详情
- `https://bbs-api.miyoushe.com/post/wapi/getDynamicData?gids=&post_ids=` — 批量动态统计(浏览/赞/评论)
- `https://bbs-api.miyoushe.com/post/wapi/getNewsList?gids=&type=&page_size=` — 官方公告/活动/资讯
- `https://bbs-api.miyoushe.com/post/api/getPostReplies?post_id=&size=&only_good_replies=false&is_hot=true` — 热门评论(**未经真机最终验证，失效时按代码降级处理**)

游戏 ID(gids):原神=2、崩坏3=3、星穹铁道=6、绝区零=8。登录为官方 WebView 捕获 Cookie(ltoken/ltuid 等键判定),Cookie 由 Auth 存 preferences 并由 MiyousheApi 自动带 Cookie 头发送；不接触账密。

已知遗留：视频帖只提示不播放；评论无楼中楼展开；DS 签名的接口未接入(签到/战绩需此能力，存在风控)。兼容教训:**勿用实验性 `@ohos.arkui.uiMaterial`**(真机闪退/材质失效),用 `backgroundBlurStyle` + `shadow` 与 `setWindowLayoutFullScreen(true)` 实现悬浮与沉浸。

## 6. 排查表(沿用旧 README 经验)

- hvigor 版本报错 → `hvigorw -v` 对齐 `hvigor-config.json5` 与 `build-profile.json5` 版本号。
- 工具链下载失败 → 更新 `CLI_TOOLS_URL` 直链。
- 签名口令报错 → 核对别名与两个密码。
- 安装签名校验失败 → UDID 是否注册进 Profile / 证书与 Profile 是否过期 / Secrets 是否正确。
- main 推送后无 Release → 去 Actions 日志看「Warn when auto-release skipped」，多半是签名 Secrets 缺失或过期。

——以上足以让接手的 AI 从零重建项目与流水线。
