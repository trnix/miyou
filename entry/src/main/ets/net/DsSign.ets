// DS 签名：米游社网页客户端（x-rpc-client_type=4）请求签名，算法见 UIGF mihoyo-api-collect 公开文档。
// DS1: md5("salt={LK2}&t={秒级时间戳}&r={6位随机串}") → "{t},{r},{md5}"
// DS2/x6: md5("salt={x6}&t={t}&r={100001..200000}&b={body}&q={排序后查询串}")，仅作诊断对照。
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { util } from '@kit.ArkTS';

const SALT_LK2: string = 'xV8v4Qu54lUKrEYFZkJhB8cuOh9Asafs';
const SALT_X6: string = 't0qEgfub6cvueAPgR5m9aQWWVciEer7v';
const CHARS: string = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

export class DsSign {
  static md5Hex(input: string): string {
    const md = cryptoFramework.createMd('MD5');
    const bytes = new Uint8Array(util.TextEncoder.create('utf-8').encodeInto(input));
    const blob: cryptoFramework.DataBlob = { data: bytes };
    md.updateSync(blob);
    const digest = md.digestSync();
    let hex = '';
    digest.data.forEach((b: number) => {
      hex += b.toString(16).padStart(2, '0');
    });
    return hex;
  }

  private static randText(len: number): string {
    let s = '';
    for (let i = 0; i < len; i++) {
      s += CHARS.charAt(Math.floor(Math.random() * CHARS.length));
    }
    return s;
  }

  static webDs1(): string {
    const t = Math.floor(Date.now() / 1000).toString();
    const r = DsSign.randText(6);
    const c = DsSign.md5Hex(`salt=${SALT_LK2}&t=${t}&r=${r}`);
    return `${t},${r},${c}`;
  }

  static webDs2(query: string): string {
    const t = Math.floor(Date.now() / 1000).toString();
    const r = (100001 + Math.floor(Math.random() * 100000)).toString();
    const c = DsSign.md5Hex(`salt=${SALT_X6}&t=${t}&r=${r}&b=&q=${query}`);
    return `${t},${r},${c}`;
  }
}
