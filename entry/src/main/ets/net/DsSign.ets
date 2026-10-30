import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

// DS 签名（DS1/DS2）。
// 注意：salt 与 x-rpc-app_version 绑定，需从官方 App 抓包或社区维护库提取后填入；
// 留空时签名必然失败——这是刻意的，避免把来路不明的 salt 写死在仓库里。
export class DsSign {
  static readonly SALT_K2: string = ''; // client_type=2 · DS1（米游社内操作）
  static readonly SALT_LK2: string = ''; // client_type=4 · DS1
  static readonly SALT_4X: string = ''; // client_type=5 · DS2（战绩查询）
  static readonly SALT_6X: string = ''; // client_type=5 · DS2（签到福利，M4 才用）

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

  // DS2：随机串为 6 位数字，b/q 段恒存在（可为空串）
  static async ds2(salt: string, body: string, query: string): Promise<string> {
    const t = Math.floor(Date.now() / 1000).toString();
    const r = DsSign.randomDigits(6);
    const raw = `salt=${salt}&t=${t}&r=${r}&b=${body}&q=${query}`;
    const md5 = await DsSign.md5Hex(raw);
    return `${t},${r},${md5}`;
  }
}
