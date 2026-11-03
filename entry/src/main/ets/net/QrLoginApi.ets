import { MysHttp } from './MysHttp';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { Session } from '../auth/Session';

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
  pairs: string[];
  hasToken: boolean;
  debugText: string;
}

function asStr(v: Object | undefined): string {
  return typeof v === 'string' ? v : '';
}

function trim(s: string, n: number): string {
  return s.length > n ? s.substring(0, n) + '…' : s;
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

const CREDENTIAL_NAMES: string[] = [
  'ltoken_v2', 'ltoken', 'ltuid_v2', 'ltuid', 'ltmid_v2',
  'stoken_v2', 'stoken', 'stuid', 'mid',
  'cookie_token_v2', 'cookie_token',
  'account_id_v2', 'account_mid_v2', 'account_id',
  'login_ticket', 'login_uid'
];

function isCredential(name: string): boolean {
  return CREDENTIAL_NAMES.indexOf(name) !== -1;
}

function splitSetCookie(text: string, out: string[]): void {
  const parts = text.split(', ');
  let current = '';
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    const eq = part.indexOf('=');
    const head = eq > 0 ? part.substring(0, eq) : '';
    const first = head.length > 0 ? head.charCodeAt(0) : 0;
    const isAlpha = (first >= 65 && first <= 90) || (first >= 97 && first <= 122);
    const looksNew = eq > 0 && head.indexOf(' ') === -1 && isAlpha;
    if (looksNew && current !== '') {
      out.push(current);
      current = part;
    } else if (looksNew) {
      current = part;
    } else {
      current = current === '' ? part : `${current}, ${part}`;
    }
  }
  if (current !== '') {
    out.push(current);
  }
}

function credentialPairsFromHeader(headerText: string, out: string[], onToken: () => void): void {
  if (headerText === '') {
    return;
  }
  try {
    const obj = JSON.parse(headerText) as Record<string, Object>;
    const keys = Object.keys(obj);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i].toLowerCase() !== 'set-cookie') {
        continue;
      }
      const lines: string[] = [];
      const v = obj[keys[i]];
      if (typeof v === 'string') {
        splitSetCookie(v, lines);
      } else if (Array.isArray(v)) {
        (v as Object[]).forEach((item: Object) => {
          if (typeof item === 'string') {
            splitSetCookie(item as string, lines);
          }
        });
      }
      lines.forEach((line: string) => {
        const head = line.split(';')[0].trim();
        const eq = head.indexOf('=');
        if (eq <= 0) {
          return;
        }
        const name = head.substring(0, eq);
        const value = head.substring(eq + 1);
        if (isCredential(name) && value !== '') {
          out.push(`${name}=${value}`);
          if (name === 'stoken' || name === 'stoken_v2' || name === 'ltoken' || name === 'ltoken_v2' ||
            name === 'cookie_token' || name === 'cookie_token_v2') {
            onToken();
          }
        }
      });
    }
  } catch (e) {
  }
}

// 米游社扫码登录（通行证）。头组参照 dsh-mys-checkin：**所有请求都带 Session Cookie**
//（让服务器把二维码归属到当前登录态），App 通道优先，失败回退 Web 通道；
// 凭据来源：确认响应 tokens 内联数组 + Set-Cookie。过期码：-3501/-3505/-106。
class QrLoginApi {
  private static readonly APP_VERSION: string = '2.109.0';
  private static readonly BASE_APP: string = 'https://passport-api.mihoyo.com/account/ma-cn-passport/app';
  private static readonly BASE_WEB: string = 'https://passport-api.miyoushe.com/account/ma-cn-passport/web';

  private static baseHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
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
    const cookie = Session.cookie();
    if (cookie.length > 0) {
      headers['Cookie'] = cookie;
    }
    return headers;
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
        return { ok: false, message: `HTTP ${raw.httpCode} · retcode ${retcode}（${trim(message, 60)}）`, flow, ticket: '', url: '' };
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
    const result: QrStatus = { retcode: -1, message: '', status: 'pending', pairs: [], hasToken: false, debugText: '' };
    const body = JSON.stringify({ ticket });
    const url = `${QrLoginApi.base(flow)}/queryQRLoginStatus?ticket=${encodeURIComponent(ticket)}`;
    let httpCode = 0;
    try {
      const raw = await MysHttp.postJson(url, QrLoginApi.headers(flow), body);
      httpCode = raw.httpCode;
      const obj = JSON.parse(raw.body) as Record<string, Object>;
      const rc = obj['retcode'];
      result.retcode = typeof rc === 'number' ? rc : -1;
      result.message = asStr(obj['message']);
      credentialPairsFromHeader(raw.headerText, result.pairs, () => {
        result.hasToken = true;
      });
      const data = obj['data'] as Record<string, Object> | undefined;
      const dataKeys = data ? Object.keys(data).join(',') : '(无 data)';
      const statusRaw = data ? asStr(data['status']) : '';
      result.debugText =
        `HTTP ${httpCode} · rc ${result.retcode} · status=${statusRaw === '' ? '(空)' : statusRaw} · data键=[${trim(dataKeys, 80)}] · 消息:${trim(result.message, 40)}`;
      if (result.retcode === -3501 || result.retcode === -3505 || result.retcode === -106) {
        result.status = 'expired';
        return result;
      }
      if (result.retcode !== 0) {
        return result;
      }
      if (!data) {
        return result;
      }
      const status = statusRaw.toLowerCase();
      if (status === 'expired') {
        result.status = 'expired';
        return result;
      }
      if (status === 'confirmed') {
        result.status = 'confirmed';
        const tokens = data['tokens'];
        if (Array.isArray(tokens)) {
          (tokens as Object[]).forEach((rawT: Object) => {
            const t = rawT as Record<string, Object>;
            const token = asStr(t['token']);
            const type = t['token_type'];
            const typeNum = typeof type === 'number' ? type : 0;
            if (token === '' || (typeNum !== 1 && typeNum !== 2 && typeNum !== 4)) {
              return;
            }
            const baseName = typeNum === 1 ? 'stoken' : (typeNum === 2 ? 'ltoken' : 'cookie_token');
            const name = token.startsWith('v2_') ? `${baseName}_v2` : baseName;
            result.pairs.push(`${name}=${token}`);
            result.hasToken = true;
          });
        }
        const user = data['user_info'] as Record<string, Object> | undefined;
        if (user) {
          addIdentity(result.pairs, asStr(user['aid']), asStr(user['mid']));
        }
        return result;
      }
      // 扫描中/等待确认：任何含 scan 的状态都归入 scanned（页面只显示状态，不中断轮询）
      if (status.indexOf('scan') === 0) {
        result.status = 'scanned';
        return result;
      }
    } catch (e) {
      result.debugText = `HTTP ${httpCode} · 解析失败（响应不是预期 JSON）`;
    }
    return result;
  }
}

export { QrLoginApi };
