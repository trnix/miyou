// 登录会话：官方网页登录捕获的 Cookie 仅存本机，不上传、不接触账密。
// 2026 起通行证登录态主体是 v2 键（ltoken_v2/ltuid_v2/account_id_v2/cookie_token_v2），
// 同名 v1 键是空值占位。多域拼接的原始 Cookie 每个键重复多次且空值在前，
// 会导致服务器读到空 ltuid 判定未登录——保存前必须清洗：按键去重、丢弃空值。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE: string = 'miyou_auth';
const KEY_COOKIE: string = 'cookie';

export class Session {
  private static ctx: common.UIAbilityContext | null = null;

  static cookie(): string {
    const stored = AppStorage.get<string>(KEY_COOKIE);
    return stored ? stored : '';
  }

  static loggedIn(): boolean {
    return Session.cookie().length > 0;
  }

  static stuid(): string {
    const m = Session.cookie().match(/(?:stuid|ltuid_v2|account_id_v2|ltuid|account_id|login_uid)=(\d+)/);
    return m ? m[1] : '';
  }

  static hydrate(context: common.UIAbilityContext): void {
    Session.ctx = context;
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE });
      const value = store.getSync(KEY_COOKIE, '') as string;
      AppStorage.setOrCreate(KEY_COOKIE, value);
    } catch (e) {
      AppStorage.setOrCreate(KEY_COOKIE, '');
    }
  }

  static save(rawCookie: string): void {
    const cleaned = Session.compose(rawCookie);
    AppStorage.setOrCreate(KEY_COOKIE, cleaned);
    Session.persist(cleaned);
  }

  static clear(): void {
    AppStorage.setOrCreate(KEY_COOKIE, '');
    Session.persist('');
  }

  // 按键去重：非空值覆盖一切，空值键直接丢弃（空 v1 键会误导服务器判定未登录）。
  private static compose(raw: string): string {
    const map = new Map<string, string>();
    raw.split(';').forEach((pair: string) => {
      const p = pair.trim();
      const eq = p.indexOf('=');
      if (eq <= 0) {
        return;
      }
      const k = p.substring(0, eq);
      const v = p.substring(eq + 1);
      if (v.length > 0) {
        map.set(k, v);
      } else if (!map.has(k)) {
        map.set(k, '');
      }
    });
    const parts: string[] = [];
    map.forEach((v: string, k: string) => {
      if (v.length > 0) {
        parts.push(`${k}=${v}`);
      }
    });
    return parts.join('; ');
  }

  private static persist(value: string): void {
    if (Session.ctx === null) {
      return;
    }
    try {
      const store = preferences.getPreferencesSync(Session.ctx, { name: STORE });
      store.putSync(KEY_COOKIE, value);
      store.flush();
    } catch (e) {
      console.warn('Session persist failed');
    }
  }
}
