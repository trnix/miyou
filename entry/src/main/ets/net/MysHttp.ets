import { http } from '@kit.NetworkKit';
import { Endpoints } from './Endpoints';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { Session } from '../auth/Session';

export interface RawResult {
  httpCode: number;
  body: string;
}

// 统一请求封装：x-rpc 基线头 + device 身份 + 可选 Cookie。
// 调用方负责解析 retcode；网络异常直接抛错，由页面层兜底展示。
export class MysHttp {
  static buildHeaders(withCookie: boolean): Record<string, string> {
    const headers: Record<string, string> = {
      'x-rpc-app_version': Endpoints.APP_VERSION,
      'x-rpc-client_type': Endpoints.CLIENT_TYPE,
      'x-rpc-verify_key': Endpoints.VERIFY_KEY,
      'x-rpc-device_id': DeviceIdentity.deviceId(),
      'x-rpc-device_fp': DeviceIdentity.deviceFp(),
      'Referer': Endpoints.REFERER,
      'User-Agent': Endpoints.USER_AGENT
    };
    if (withCookie) {
      const cookie: string = Session.cookie();
      if (cookie.length > 0) {
        headers['Cookie'] = cookie;
      }
    }
    return headers;
  }

  static async request(url: string, headers: Record<string, string>): Promise<RawResult> {
    const req = http.createHttp();
    try {
      const res = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.STRING,
        header: headers,
        connectTimeout: 10000,
        readTimeout: 10000
      });
      const body = typeof res.result === 'string' ? res.result : JSON.stringify(res.result);
      return { httpCode: res.responseCode, body };
    } finally {
      req.destroy();
    }
  }

  static async getObject(url: string, withCookie: boolean): Promise<Object> {
    const raw = await MysHttp.request(url, MysHttp.buildHeaders(withCookie));
    return JSON.parse(raw.body) as Object;
  }

  // 裸请求：仅 UA/Referer + 可选 Cookie，不带任何 x-rpc 头。用于与全头请求对照排障。
  static async getBare(url: string, withCookie: boolean): Promise<RawResult> {
    const headers: Record<string, string> = {
      'User-Agent': Endpoints.USER_AGENT,
      'Referer': 'https://www.miyoushe.com/'
    };
    if (withCookie) {
      const cookie: string = Session.cookie();
      if (cookie.length > 0) {
        headers['Cookie'] = cookie;
      }
    }
    return MysHttp.request(url, headers);
  }
}
