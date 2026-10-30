// 光感玻璃主题：档位状态（AppStorage + preferences 持久化）与视觉参数映射。
// 档位：0 关闭 / 1 弱 / 2 中（默认）/ 3 强。对应蓝图第 3 节。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE: string = 'miyou_settings';
const KEY_GLASS: string = 'glassLevel';

export class GlassTheme {
  static level(): number {
    return AppStorage.get<number>(KEY_GLASS) ?? 2;
  }

  static setLevel(level: number): void {
    AppStorage.setOrCreate(KEY_GLASS, level);
    try {
      const context = getContext() as common.UIAbilityContext;
      const store = preferences.getPreferencesSync(context, { name: STORE });
      store.putSync(KEY_GLASS, level);
      store.flush();
    } catch (e) {
      console.warn('GlassTheme persist failed');
    }
  }

  static hydrate(context: common.UIAbilityContext): void {
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE });
      const v = store.getSync(KEY_GLASS, 2) as number;
      AppStorage.setOrCreate(KEY_GLASS, v);
    } catch (e) {
      AppStorage.setOrCreate(KEY_GLASS, 2);
    }
  }

  static blur(level: number): BlurStyle {
    switch (level) {
      case 1:
        return BlurStyle.Thin;
      case 3:
        return BlurStyle.Thick;
      default:
        return BlurStyle.Regular;
    }
  }

  // 档位 0 为不透明实色（模糊被遮住等效关闭）；其余按档调透明度。
  static barColor(level: number): string {
    switch (level) {
      case 0:
        return '#FFF7F8FA';
      case 1:
        return '#B8F7F8FA';
      case 3:
        return '#73F7F8FA';
      default:
        return '#99F7F8FA';
    }
  }
}
