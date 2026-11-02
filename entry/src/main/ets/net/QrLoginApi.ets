import { MysHttp } from './MysHttp';
import { DeviceIdentity } from '../auth/DeviceIdentity';

export interface QrCreate {
  ok: boolean;
  message: string;
  flow: string; // app ｜ web
  ticket: string;
  url: string;
}

export interface QrStatus {
  retcode: number;
  message: string;
  status: string; // pending ｜ scanned ｜ confirmed ｜ expired
  pairs: string[]; // 已规范化的 cookie 片段（key=value）
}

function asStr(v: Object | undefined): string {
  return typeof v === 'string' ? v : '';
}

function addIdentity(pairs: string[], aid: string, mid: string): void {
  if (aid !== '') {
    const uidKeys: string[] = ['stuid', 'ltuid', 'ltuid_v2', 'account_id', 'account_id_v2'];
    uidKeys.forEach((k: string) => pairs.push(`${k}=${aid}`));
  }
  if (mid !== '') {
    const midKeys: string[] = ['mid', 'ltmid_v2', 'account_mid_v2'];
    midKeys.forEach((k: string) => pairs.push(`${k}=${mid}`));
  }
}

// 米游社扫码登录（通行证），逐行对齐仍在维护的上游实现 dsh-mys-checkin（2026-10 发布）：
// 通行证 QR 流程不签名（无 DS、无 device_fp）；App 通道（active Hyperion 身份）返回
// tokens 内联数组（token_type: 1 stoken / 2 ltoken / 4 cookie_token，v2_ 前缀决定 _v2 键）；
// App 通道创建失败时回退 Web 通道。过期码为 -3501/-3505。
class QrLoginApi {
  private static readonly APP_VERSION: string = '2.109.0';
  private static readonly BASE_APP: string = 'https://passport-api.mihoyo.com/account/ma-cn-passport/app';
  private static readonly BASE_WEB: string = 'https://passport-api.miyoushe.com/account/ma-cn-passport/web';

  private static baseHeaders(): Record<string, string> {
    return {
      'User-Agent': `Mozilla/5.0 (Linux; Android 12; Unspecified Device) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/103.0.5060.129 Mobile Safari/537.36 miHoYoBBS/${QrLoginApi.APP_VERSION}`,
      'Accept': 'application/json, text/plain, */*',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Content-Type': 'application/json',
      'x-rpc-app_id': 'bll8iq97cem8',
      'x-rpc-client_type': '4',
      'x-rpc-device_id': DeviceIdentity.deviceId(),
      'x-rpc-app_version': QrLoginApi.APP_VERSION,
      'x-rpc-channel': 'miyousheluodi',
      'x-rpc-sys_version': '12'
    };
  }

  private static headers(flow: string): Record<string, string> {
    const h = QrLoginApi.baseHeaders();
    if (flow === 'app') {
      h['User-Agent'] = 'HYPContainer/1.3.3.182';
      h['x-rpc-app_id'] = 'ddxf5dufpuyo';
      h['x-rpc-client_type'] = '3';
    }
    return h;
  }

  private static base(flow: string): string {
    return flow === 'app' ? QrLoginApi.BASE_APP : QrLoginApi.BASE_WEB;
  }

  private static async createFlow(flow: string): Promise<QrCreate> {
    const fail: QrCreate = { ok: false, message: '网络异常', flow, ticket: '', url: '' };
    try {
      const raw = await MysHttp.postJson(`${QrLoginApi.base(flow)}/createQRLogin`, QrLoginApi.headers(flow), '{}');
      const obj = JSON.parse(raw.body) as Record<string, Object>;
      const rc = obj['retcode'];
      const retcode = typeof rc === 'number' ? rc : -1;
      const message = asStr(obj['message']);
      if (retcode !== 0) {
        return { ok: false, message: `retcode ${retcode}（${message}）`, flow, ticket: '', url: '' };
      }
      const data = obj['data'] as Record<string, Object> | undefined;
      if (!data) {
        return { ok: false, message: '响应数据为空', flow, ticket: '', url: '' };
      }
      const ticket = asStr(data['ticket']);
      const url = asStr(data['url']);
      if (ticket === '' || url === '') {
        return { ok: false, message: '缺少二维码字段', flow, ticket: '', url: '' };
      }
      return { ok: true, message: '', flow, ticket, url };
    } catch (e) {
      return fail;
    }
  }

  // App 通道优先（其二维码请求 SToken）；创建失败回退 Web 通道。
  static async create(): Promise<QrCreate> {
    const app = await QrLoginApi.createFlow('app');
    if (app.ok) {
      return app;
    }
    const web = await QrLoginApi.createFlow('web');
    if (web.ok) {
      return web;
    }
    return { ok: false, message: `App 通道：${app.message}；Web 通道：${web.message}`, flow: 'app', ticket: '', url: '' };
  }

  static async query(ticket: string, flow: string): Promise<QrStatus> {
    const result: QrStatus = { retcode: -1, message: '', status: 'pending', pairs: [] };
    const body = JSON.stringify({ ticket });
    const url = `${QrLoginApi.base(flow)}/queryQRLoginStatus?ticket=${encodeURIComponent(ticket)}`;
    try {
      const raw = await MysHttp.postJson(url, QrLoginApi.headers(flow), body);
      const obj = JSON.parse(raw.body) as Record<string, Object>;
      const rc = obj['retcode'];
      result.retcode = typeof rc === 'number' ? rc : -1;
      result.message = asStr(obj['message']);
      if (result.retcode === -3501 || result.retcode === -3505) {
        result.status = 'expired';
        return result;
      }
      if (result.retcode !== 0) {
        return result;
      }
      const data = obj['data'] as Record<string, Object> | undefined;
      if (!data) {
        return result;
      }
      const status = asStr(data['status']).toLowerCase();
      if (status === 'expired') {
        result.status = 'expired';
        return result;
      }
      if (status === 'scanned' || status === 'scannedwaitingconfirmation') {
        result.status = 'scanned';
        return result;
      }
      if (status === 'confirmed') {
        result.status = 'confirmed';
        const tokens = data['tokens'];
        if (Array.isArray(tokens)) {
          (tokens as Object[]).forEach((raw: Object) => {
            const t = raw as Record<string, Object>;
            const token = asStr(t['token']);
            const type = t['token_type'];
            const typeNum = typeof type === 'number' ? type : 0;
            if (token === '' || (typeNum !== 1 && typeNum !== 2 && typeNum !== 4)) {
              return;
            }
            const baseName = typeNum === 1 ? 'stoken' : (typeNum === 2 ? 'ltoken' : 'cookie_token');
            const name = token.startsWith('v2_') ? `${baseName}_v2` : baseName;
            result.pairs.push(`${name}=${token}`);
          });
        }
        const user = data['user_info'] as Record<string, Object> | undefined;
        if (user) {
          addIdentity(result.pairs, asStr(user['aid']), asStr(user['mid']));
        }
      }
    } catch (e) {
      // 保留默认态
    }
    return result;
  }
}

export { QrLoginApi };
