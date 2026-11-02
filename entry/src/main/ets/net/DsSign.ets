import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

// DS 签名（DS1/DS2）。
// DS2 的 X4/X6 salt 取自社区仍在维护的开源项目 TeyvatGuide（与其配套版本线 2.115.0 绑定）；
// 米哈游官方从未公开 salt，签名请求必须使用配套版本号，本仓库内统一经 SIGN_VERSION 引用。
export class DsSign {
  static readonly SALT_K2: string = '09d39d16528ca0e4900a39ecc07d5062'; // client_type=2 · DS1（米游社内操作）
  static readonly SALT_LK2: string = 'b99b74d9023a6511231be2c7209b6fdb'; // client_type=4 · DS1
  static readonly SALT_4X: string = 'xV8v4Qu54lUKrEYFZkJhB8cuOh9Asafs'; // X4 · DS2（扫码登录/战绩查询）
  static readonly SALT_6X: string = 't0qEgfub6cvueAPgR5m9aQWWVciEer7v'; // X6 · DS2（签到福利）
  // 与上述 salt 绑定的米游社版本线；与 Endpoints.APP_VERSION 解耦，勿混用。
  static readonly SIGN_VERSION: string = '2.115.0';

  static async md5Hex(input: string): Promise<string> {
    const md = cryptoFramework.createMd('MD5');
    const data = util.TextEncoder.create('utf-8').encodeInto(input);
    await md.update({ data });
    const out = await md.digest();
    let hex = '';
    out.data.forEach((b: number) => {
      hex += b.toString(16).padStart(2, '0');
    });
    return hex;
  }

  private static randomChars(len: number): string {
    const pool = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let r = '';
    for (let i = 0; i < len; i++) {
      r += pool.charAt(Math.floor(Math.random() * pool.length));
    }
    return r;
  }

  private static randomDigits(len: number): string {
    let r = '';
    for (let i = 0; i < len; i++) {
      r += Math.floor(Math.random() * 10).toString();
    }
    return r;
  }

  // DS1：md5(salt=&t=&r=[&b=body][&q=sortedQuery])
  static async ds1(salt: string, body: string, query: string): Promise<string> {
    const t = Math.floor(Date.now() / 1000).toString();
    const r = DsSign.randomChars(6);
    let raw = `salt=${salt}&t=${t}&r=${r}`;
    if (body.length > 0) {
      raw += `&b=${body}`;
    }
    if (query.length > 0) {
      raw += `&q=${query}`;
    }
    const md5 = await DsSign.md5Hex(raw);
    return `${t},${r},${md5}`;
  }

  // DS2：随机数恒为 100000–200000 的六位数字，b/q 段恒存在（可为空串）。
  static async ds2(salt: string, body: string, query: string): Promise<string> {
    const t = Math.floor(Date.now() / 1000).toString();
    const r = (100000 + Math.floor(Math.random() * 100001)).toString();
    const raw = `salt=${salt}&t=${t}&r=${r}&b=${body}&q=${query}`;
    const md5 = await DsSign.md5Hex(raw);
    return `${t},${r},${md5}`;
  }
}
