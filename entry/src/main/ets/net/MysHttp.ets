import { http } from '@kit.NetworkKit';
import { Endpoints } from './Endpoints';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { AccountStore } from '../auth/AccountStore';

// 统一 GET 封装：x-rpc 基线头 + device 身份 + 可选 Cookie。
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
      const cookie: string = AccountStore.cookie();
      if (cookie.length > 0) {
        headers['Cookie'] = cookie;
      }
    }
    return headers;
  }

  static async getObject(url: string, withCookie: boolean): Promise<Object> {
    const req = http.createHttp();
    try {
      const res = await req.request(url, {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.OBJECT,
        header: MysHttp.buildHeaders(withCookie),
        connectTimeout: 10000,
        readTimeout: 10000
      });
      if (typeof res.result === 'string') {
        return JSON.parse(res.result) as Object;
      }
      return res.result as Object;
    } finally {
      req.destroy();
    }
  }
}
