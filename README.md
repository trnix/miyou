# 米柚 MiYou

非官方米游社第三方客户端（HarmonyOS NEXT，ArkTS/ArkUI 原生重写版），仅用于查看社区内容与本人授权的游戏数据。

- 与米哈游（miHoYo）无任何隶属关系；分发不使用「米游社」名称与米哈游素材
- 不收集账号密码：登录在米哈游通行证官方网页内完成，应用仅捕获 Cookie 会话且仅存本机
- 当前为只读应用：不含发帖、评论、点赞、签到等任何远端写入功能

## 文档

- `docs/blueprint.md` — 移植蓝图 v1.0（需求基线：模块取舍、光感玻璃视觉规范、M0–M4 里程碑）
- `docs/handover.md` — 交接文档（CI 与签名 7 变量、云端打包重建指南）
- `docs/sideload.md` / `docs/signing.md` — 侧载与签名说明

## 构建与安装

push 到 `main` 自动构建并签名，产出预发布 Release（tag 形如 `v0.5.0-b*`）；下载后 `hdc install` 侧载（仅限签名 Profile 注册过的设备）。

## 历史归档

旧 0.4.0 骨架完整保存于分支 `archive/v0.4-skeleton`（同提交亦有 tag `v0.4.0-b31`），仅供参考，不再维护。
