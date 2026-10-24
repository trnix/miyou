// 登录会话: 官方网页登录捕获的 Cookie 仅存本机, 不上传、不接触账密。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE: string = 'miyou_auth';
const KEY: string = 'cookie';

export class Auth {
  static cookie(): string {
    const stored = AppStorage.get<string>(KEY);
    return stored ? stored : '';
  }

  static loggedIn(): boolean {
    return Auth.cookie() !== '';
  }

  // 应用启动时从 preferences 恢复到 AppStorage。
  static hydrate(context: common.UIAbilityContext): void {
    try {
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE });
      const value = store.getSync(KEY, '') as string;
      AppStorage.setOrCreate(KEY, value);
    } catch (e) { console.warn('Auth hydrate failed'); }
  }

  static save(cookie: string): void {
    AppStorage.setOrCreate(KEY, cookie);
    Auth.persist(cookie);
  }

  static clear(): void {
    AppStorage.setOrCreate(KEY, '');
    Auth.persist('');
  }

  private static persist(value: string): void {
    try {
      const context: common.UIAbilityContext = getContext() as common.UIAbilityContext;
      const store: preferences.Preferences = preferences.getPreferencesSync(context, { name: STORE });
      store.putSync(KEY, value);
      store.flush();
    } catch (e) { console.warn('Auth persist failed'); }
  }
}
