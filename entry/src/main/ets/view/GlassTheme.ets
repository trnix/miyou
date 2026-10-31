// 光感玻璃主题：档位状态（AppStorage + preferences 持久化）与视觉参数映射。
// 档位：0 关闭 / 1 弱 / 2 中（默认）/ 3 强。对应蓝图第 3 节。
// 机制（HarmonyOS 7 / API 26 官方文档）：backgroundBlurStyle 的 Material 系预设由引擎自带
// 色调叠加与边缘高光；背景色只做极轻的色调（10–26%），不遮住引擎材质——高不透明白底
// 会把玻璃效果盖住（0.5.x 实测教训）。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE: string = 'miyou_settings';
const KEY_GLASS: string = 'glassLevel';

export class GlassTheme {
  private static ctx: common.UIAbilityContext | null = null;

  static level(): number {
    const stored = AppStorage.get<number>(KEY_GLASS);
    return stored !== undefined ? stored : 2;
  }

  static setLevel(level: number): void {
    AppStorage.setOrCreate(KEY_GLASS, level);
    if (GlassTheme.ctx === null) {
      return;
    }
    try {
      const store = preferences.getPreferencesSync(GlassTheme.ctx, { name: STORE });
      store.putSync(KEY_GLASS, level);
      store.flush();
    } catch (e) {
      console.warn('GlassTheme persist failed');
    }
  }

  static hydrate(context: common.UIAbilityContext): void {
    GlassTheme.ctx = context;
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
        return BlurStyle.ThinMaterial;
      case 3:
        return BlurStyle.ThickMaterial;
      default:
        return BlurStyle.RegularMaterial;
    }
  }

  // 档位 0 为不透明实色（等效关闭光感）；1–3 档只做轻色调，由引擎材质主导。
  static barColor(level: number): string {
    switch (level) {
      case 0:
        return '#FFF7F8FA';
      case 1:
        return '#40F7F8FA';
      case 3:
        return '#1AF7F8FA';
      default:
        return '#2BF7F8FA';
    }
  }

  // 玻璃高光描边：档位 0 用深灰细线，其余用半透明白（玻璃边缘反光）。
  static edgeColor(level: number): string {
    return level === 0 ? '#0D000000' : '#2EFFFFFF';
  }
}
