# 申请签名材料并配置 GitHub(全程无需 DevEco Studio)

调试安装要求:HAP 必须用**调试证书**签名,且调试 Profile 中注册了你的设备 UDID。调试证书和调试 Profile 各有有效期,请在 AGC 页面查看实际到期时间,到期前重新申请并更新对应材料。

以下命令为华为官方流水线文档中的写法。Windows 下请在 **Git Bash 或 WSL** 中执行(命令中的 `\` 换行写法不适用于 PowerShell)。需要先安装 JDK(keytool 随 JDK 提供)。

## 一、生成密钥库和 CSR

```bash
# 1. 生成密钥库 debug.p12(EC P-256 密钥,鸿蒙要求)
#    执行时会交互式提示输入密码(PKCS12 的密钥库密码与密钥密码使用同一个,共输入两次)
keytool -genkeypair \
  -alias "miyou" \
  -keyalg EC -groupname secp256r1 -sigalg SHA256withECDSA \
  -dname "C=CN,O=personal,OU=MiYou,CN=miyou" \
  -keystore debug.p12 \
  -storetype pkcs12 \
  -validity 9125

# 2. 从密钥库导出证书请求文件 debug.csr(执行时会要求输入密钥库密码)
keytool -certreq \
  -alias "miyou" \
  -sigalg SHA256withECDSA \
  -keystore debug.p12 \
  -storetype pkcs12 \
  -file debug.csr
```

密码要求:大小写字母、数字、特殊符号中至少两种组合,8 位以上。记下:`alias`(别名)和密码(后续要填进 GitHub Secrets)。

## 二、获取手机 UDID

在 Windows 上装好 Command Line Tools(Windows 版,含 hdc),手机开启开发者模式和 USB 调试(见 docs/sideload.md),连接后执行:

```bash
hdc list targets          # 确认能识别到设备
hdc shell bm get --udid   # 输出就是设备 UDID,复制保存
```

## 三、在 AGC 申请证书和 Profile

登录 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html),进入「**证书、APP ID 和 Profile**」模块(注意:旧文档里的「用户与访问 → 证书管理」已不是当前入口):

1. **创建 APP ID**(如尚未创建):「APP ID」→ 新建,选择 HarmonyOS 应用,应用名「米柚」,包名必须与仓库 `AppScope/app.json5` 的 `bundleName` 一致(`com.miyou.app`,包名创建后不可修改)。
2. **申请新增证书**:「证书」→ 新增证书,类型选**调试证书**,上传 `debug.csr`,提交后下载 `xxx.cer`。注意:AGC 调试证书每个账号最多 2 个。
3. **注册调试设备**:「设备」→ 添加,类型选真机,填入上一步得到的 UDID,名称随意(如 Mate80ProMax)。
4. **申请新增调试 Profile**:「Profile」→ 新建,类型选**调试Profile**,勾选应用「米柚 com.miyou.app」、刚申请的调试证书、已注册的设备,提交后下载 `xxx.p7b`。

流程就是「APP ID → 证书 → 设备 → Profile」四步。具体页面名称以 AGC 当前界面为准。

## 四、获取 Command Line Tools 直链(CI 用)

1. 用华为账号登录 [华为开发者下载中心](https://developer.huawei.com/consumer/cn/download/)(下载中心需要登录才能下载)。
2. 找到 **Command Line Tools**,选择 **Linux x86-64 版**,在下载按钮上右键「复制链接地址」(直链形如 `https://...dbankcdn.cn/...zip`)。
3. 存到仓库 **Settings → Secrets and variables → Actions**(Variables 或 Secrets 均可,工作流两边都认),名称 `CLI_TOOLS_URL`。

注意:直链会随版本更新失效,构建报下载失败时回来换新链接。本地侧载用的 hdc 则下载 **Windows 版** Command Line Tools。

## 五、配置 GitHub Secrets

先把三个签名文件转成 base64 文本(Git Bash 或 WSL):

```bash
base64 -w0 debug.p12  > p12.b64
base64 -w0 xxx.cer    > cer.b64
base64 -w0 xxx.p7b    > p7b.b64
```

在仓库 **Settings → Secrets and variables → Actions → Secrets** 中添加 6 个:

| Secret 名称 | 内容 |
|---|---|
| `SIGNING_P12` | `p12.b64` 的内容 |
| `SIGNING_CERT` | `cer.b64` 的内容 |
| `SIGNING_PROFILE` | `p7b.b64` 的内容 |
| `SIGNING_KEY_ALIAS` | 生成密钥时的别名,如 `miyou` |
| `SIGNING_KEYSTORE_PASSWORD` | 密钥库密码(storepass) |
| `SIGNING_KEY_PASSWORD` | 密钥密码(与 storepass 相同) |

配置完成后推送代码或 tag 即可触发构建。

## 六、验证

推送 `v0.1.0` tag → Actions 跑完 → Releases 页出现 `app-signed.hap` → 下载后按 docs/sideload.md 安装。手机上出现「米柚」图标、打开是卡片列表页,即闭环成功。
