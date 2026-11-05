import { http } from '@kit.NetworkKit';
import { Endpoints } from './Endpoints';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { Session } from '../auth/Session';

export interface RawResult {
  httpCode: number;
  body: string;
  headerText: string; // 可能含凭据，界面不得展示。
}

export class MysHttp {
  static buildHeaders(withCookie: boolean): Record<string, string> {
    const headers: Record<string, string> = {
      'x-rpc-app_version': Endpoints.APP_VERSION, 'x-rpc-client_type': Endpoints.CLIENT_TYPE,
      'x-rpc-verify_key': Endpoints.VERIFY_KEY, 'x-rpc-device_id': DeviceIdentity.deviceId(),
      'x-rpc-device_fp': DeviceIdentity.deviceFp(), 'Referer': Endpoints.REFERER, 'User-Agent': Endpoints.USER_AGENT
    };
    if (withCookie && Session.cookie().length > 0) { headers['Cookie'] = Session.cookie(); }
    return headers;
  }

  private static toHeaderText(header: Object): string {
    try { return JSON.stringify(header); } catch (e) { return ''; }
  }

  static async request(url: string, headers: Record<string, string>): Promise<RawResult> {
    const req = http.createHttp();
    try {
      const res = await req.request(url, {
        method: http.RequestMethod.GET, expectDataType: http.HttpDataType.STRING,
        header: headers, connectTimeout: 10000, readTimeout: 10000
      });
      const body = typeof res.result === 'string' ? res.result : JSON.stringify(res.result);
      return { httpCode: res.responseCode, body, headerText: MysHttp.toHeaderText(res.header) };
    } finally { req.destroy(); }
  }

  static async postJson(url: string, headers: Record<string, string>, body: string): Promise<RawResult> {
    const req = http.createHttp();
    try {
      const res = await req.request(url, {
        method: http.RequestMethod.POST, expectDataType: http.HttpDataType.STRING,
        header: headers, extraData: body, connectTimeout: 10000, readTimeout: 10000
      });
      const text = typeof res.result === 'string' ? res.result : JSON.stringify(res.result);
      return { httpCode: res.responseCode, body: text, headerText: MysHttp.toHeaderText(res.header) };
    } finally { req.destroy(); }
  }

  // 媒体下载不携带会话、设备指纹或 x-rpc 凭据；32 MiB 上限避免无界缓冲。
  static async imageBytes(url: string): Promise<ArrayBuffer> {
    if (!/^https?:\/\//i.test(url)) { throw new Error('图片地址不受支持'); }
    const req = http.createHttp();
    try {
      const res = await req.request(url, {
        method: http.RequestMethod.GET, expectDataType: http.HttpDataType.ARRAY_BUFFER,
        header: { 'Referer': 'https://www.miyoushe.com/', 'User-Agent': Endpoints.USER_AGENT },
        connectTimeout: 10000, readTimeout: 20000, maxLimit: 32 * 1024 * 1024
      });
      if (res.responseCode !== 200 || !(res.result instanceof ArrayBuffer) || res.result.byteLength === 0) {
        throw new Error('图片下载失败');
      }
      return res.result;
    } finally { req.destroy(); }
  }

  static async getObject(url: string, withCookie: boolean): Promise<Object> {
    const raw = await MysHttp.request(url, MysHttp.buildHeaders(withCookie));
    return JSON.parse(raw.body) as Object;
  }

  static async getBare(url: string, withCookie: boolean): Promise<RawResult> {
    const headers: Record<string, string> = { 'User-Agent': Endpoints.USER_AGENT, 'Referer': 'https://www.miyoushe.com/' };
    if (withCookie && Session.cookie().length > 0) { headers['Cookie'] = Session.cookie(); }
    return MysHttp.request(url, headers);
  }
}
