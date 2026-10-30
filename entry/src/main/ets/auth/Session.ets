// 登录会话：官方网页登录捕获的 Cookie 仅存本机，不上传、不接触账密。
// 全字段保留（stuid/stoken/mid/login_ticket/ltuid/ltoken/cookie_token），为远期写功能预留。
// 注：类名刻意避开与 AppStorage 形近的命名（编译器解析教训，见构建日志 da2c168）。
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
    const m = Session.cookie().match(/(?:stuid|ltuid|account_id|login_uid)=(\d+)/);
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

  static save(cookie: string): void {
    AppStorage.setOrCreate(KEY_COOKIE, cookie);
    Session.persist(cookie);
  }

  static clear(): void {
    AppStorage.setOrCreate(KEY_COOKIE, '');
    Session.persist('');
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
