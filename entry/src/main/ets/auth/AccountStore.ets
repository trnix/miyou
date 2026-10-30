// 登录会话：官方网页登录捕获的 Cookie 仅存本机，不上传、不接触账密。
// 全字段保留（stuid/stoken/mid/login_ticket/ltuid/ltoken/cookie_token），为远期写功能预留。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE: string = 'miyou_auth';
const KEY_COOKIE: string = 'cookie';

export class AccountStore {
  static cookie(): string {
    return AppStorage.get<string>(KEY_COOKIE) ?? '';
  }

  static loggedIn(): boolean {
    return AccountStore.cookie().length > 0;
  }

  static stuid(): string {
    const m = AccountStore.cookie().match(/(?:stuid|ltuid|account_id|login_uid)=(\d+)/);
    return m ? m[1] : '';
  }

  static hydrate(context: common.UIAbilityContext): void {
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
    AccountStore.persist(cookie);
  }

  static clear(): void {
    AppStorage.setOrCreate(KEY_COOKIE, '');
    AccountStore.persist('');
  }

  private static persist(value: string): void {
    try {
      const context = getContext() as common.UIAbilityContext;
      const store = preferences.getPreferencesSync(context, { name: STORE });
      store.putSync(KEY_COOKIE, value);
      store.flush();
    } catch (e) {
      console.warn('AccountStore persist failed');
    }
  }
}
