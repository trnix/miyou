// 端点与请求头基线。版本号与 verify_key 集中管理，失效时只需改这里。
export class Endpoints {
  static readonly DEVICE_FP: string = 'https://public-data-api.mihoyo.com/device-fp/api/getFp';
  static readonly WEB_HOME: string = 'https://bbs-api-static.miyoushe.com/apihub/wapi/webHome';

  // x-rpc 头基线：与 DS salt 绑定的版本号，提取 salt 时必须是同一版本。
  static readonly APP_VERSION: string = '2.117.0';
  static readonly CLIENT_TYPE: string = '5';
  static readonly VERIFY_KEY: string = 'bll8iq97cem8';
  // MiYou 应用版本需与 AppScope/app.json5 的 versionName 同代（AGENTS.md 文档同代规则）
  static readonly USER_AGENT: string = 'Hyperion/434 Mozilla/5.0 (Linux; HarmonyOS) MiYou/0.7.0';
  static readonly REFERER: string = 'https://app.mihoyo.com';
}
