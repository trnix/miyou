import { MysHttp } from './MysHttp';
import { DsSign } from './DsSign';
import { DeviceIdentity } from '../auth/DeviceIdentity';

export interface QrCreate {
  ok: boolean;
  message: string;
  ticket: string;
  url: string;
}

export interface QrStatus {
  retcode: number;
  message: string;
  status: string; // Init / Created / Scanned / Confirmed
  stoken: string;
  aid: string;
  mid: string;
}

function asStr(v: Object | undefined): string {
  return typeof v === 'string' ? v : '';
}

// 米游社扫码登录（通行证）。链路与请求头组合逐行对齐仍在维护的上游开源实现（TeyvatGuide）：
// createQRLogin → queryQRLoginStatus 轮询（Init/Created/Scanned → Confirmed；-106 二维码过期），
// 确认后 tokens[0].token 即 stoken，user_info.aid/mid 为账号标识。
class QrLoginApi {
  private static readonly BASE: string = 'https://passport-api.mihoyo.com/account/ma-cn-passport/app';
  private static readonly VER: string = DsSign.SIGN_VERSION;

  private static async qrHeaders(body: string): Promise<Record<string, string>> {
    return {
      'user-agent': `Mozilla/5.0 miHoYoBBS/${QrLoginApi.VER} Capture/2.2.0`,
      'accept': '*/*',
      'accept-language': 'zh-cn',
      'x-rpc-client_type': '3',
      'x-rpc-app_version': QrLoginApi.VER,
      'x-rpc-sdk_version': QrLoginApi.VER,
      'x-rpc-account_version': QrLoginApi.VER,
      'x-rpc-app_id': 'bll8iq97cem8',
      'x-rpc-game_biz': 'bbs_cn',
      'x-rpc-device_id': DeviceIdentity.deviceId(),
      'x-rpc-device_fp': DeviceIdentity.deviceFp(),
      'x-rpc-device_name': 'HarmonyOS Phone',
      'x-rpc-device_model': 'HarmonyOS',
      'DS': await DsSign.ds2(DsSign.SALT_4X, body, ''),
      'content-type': 'application/json'
    };
  }

  static async create(): Promise<QrCreate> {
    const fail: QrCreate = { ok: false, message: '网络异常', ticket: '', url: '' };
    const body = '{}';
    const raw = await MysHttp.postJson(`${QrLoginApi.BASE}/createQRLogin`, await QrLoginApi.qrHeaders(body), body);
    try {
      const obj = JSON.parse(raw.body) as Record<string, Object>;
      const rc = obj['retcode'];
      const retcode = typeof rc === 'number' ? rc : -1;
      const message = asStr(obj['message']);
      if (retcode !== 0) {
        return { ok: false, message: `retcode ${retcode}（${message}）`, ticket: '', url: '' };
      }
      const data = obj['data'] as Record<string, Object> | undefined;
      if (!data) {
        return { ok: false, message: '响应数据为空', ticket: '', url: '' };
      }
      const ticket = asStr(data['ticket']);
      const url = asStr(data['url']);
      if (ticket === '' || url === '') {
        return { ok: false, message: '缺少二维码字段', ticket: '', url: '' };
      }
      return { ok: true, message: '', ticket, url };
    } catch (e) {
      return { ok: false, message: `HTTP ${raw.httpCode}，响应非 JSON`, ticket: '', url: '' };
    }
  }

  static async query(ticket: string): Promise<QrStatus> {
    const result: QrStatus = { retcode: -1, message: '', status: '', stoken: '', aid: '', mid: '' };
    const body = JSON.stringify({ ticket });
    const raw = await MysHttp.postJson(`${QrLoginApi.BASE}/queryQRLoginStatus`, await QrLoginApi.qrHeaders(body), body);
    try {
      const obj = JSON.parse(raw.body) as Record<string, Object>;
      const rc = obj['retcode'];
      result.retcode = typeof rc === 'number' ? rc : -1;
      result.message = asStr(obj['message']);
      const data = obj['data'] as Record<string, Object> | undefined;
      if (!data) {
        return result;
      }
      result.status = asStr(data['status']);
      if (result.status === 'Confirmed') {
        const tokens = data['tokens'];
        if (Array.isArray(tokens) && tokens.length > 0) {
          const first = tokens[0] as Record<string, Object>;
          result.stoken = asStr(first['token']);
        }
        const user = data['user_info'] as Record<string, Object> | undefined;
        if (user) {
          result.aid = asStr(user['aid']);
          result.mid = asStr(user['mid']);
        }
      }
    } catch (e) {
      // 保留默认态
    }
    return result;
  }

  // 补齐 ltoken（可选增强）：stoken → ltoken，失败返回空串，不影响主流程。
  static async exchangeLToken(stoken: string, mid: string): Promise<string> {
    const query = `stoken=${stoken}`;
    const headers: Record<string, string> = {
      'user-agent': `Mozilla/5.0 (Windows NT 10.0; Win64; x64) miHoYoBBS/${QrLoginApi.VER}`,
      'x-rpc-app_version': QrLoginApi.VER,
      'x-rpc-client_type': '5',
      'x-requested-with': 'com.mihoyo.hyperion',
      'referer': 'https://webstatic.mihoyo.com',
      'x-rpc-device_id': DeviceIdentity.deviceId(),
      'x-rpc-device_fp': DeviceIdentity.deviceFp(),
      'ds': await DsSign.ds2(DsSign.SALT_4X, '', query),
      'cookie': `mid=${mid};stoken=${stoken}`
    };
    try {
      const raw = await MysHttp.request(
        `https://passport-api.mihoyo.com/account/auth/api/getLTokenBySToken?${query}`, headers);
      const obj = JSON.parse(raw.body) as Record<string, Object>;
      const rc = obj['retcode'];
      if (typeof rc !== 'number' || rc !== 0) {
        return '';
      }
      const data = obj['data'] as Record<string, Object> | undefined;
      return data ? asStr(data['ltoken']) : '';
    } catch (e) {
      return '';
    }
  }
}

export { QrLoginApi };
