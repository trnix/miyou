#!/usr/bin/env bash
# 用 hap-sign-tool 对构建产物签名。签名材料来自 GitHub Secrets(base64)。
# tag 发布构建(RELEASE_MODE=true)缺少任何签名材料时直接失败,不发布未签名包。
set -euo pipefail

mkdir -p dist

HAP="entry/build/default/outputs/default/entry-default-unsigned.hap"
if [ ! -s "$HAP" ]; then
  echo "::error::未找到构建产物 HAP(预期路径且非空: entry/build/default/outputs/default/entry-default-unsigned.hap)"
  exit 1
fi

if [ -z "${SIGNING_P12:-}" ]; then
  if [ "${RELEASE_MODE:-}" = "true" ]; then
    echo "::error::tag 发布构建必须配置全部签名 Secrets(见 docs/signing.md),不会发布未签名包。"
    exit 1
  fi
  echo "::warning::未配置签名 Secrets,仅上传未签名 HAP(未签名包不能安装到手机)。"
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

# hap-sign-tool.jar 位于命令行工具 sdk/default/openharmony/toolchains/lib 下
SIGN_TOOL=$(find "$HOME/ohos" -name "hap-sign-tool.jar" -type f | head -1)
if [ -z "$SIGN_TOOL" ]; then
  echo "::error::未找到 hap-sign-tool.jar"
  exit 1
fi

echo "Signing: $HAP"
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

ls -la dist/
echo "签名完成: dist/app-signed.hap"
