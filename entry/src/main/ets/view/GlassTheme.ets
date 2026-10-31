// 光感玻璃主题：档位状态与官方沉浸光感材质生成。
// 0=关闭 / 1=弱 / 2=中 / 3=强；对普通 ArkUI 组件（Row/Column）用 uiMaterial.ImmersiveMaterial，
// 枚举：ImmersiveStyle + ImmersiveOptions；能力检查失败或未支持时不加材质、自动降级。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { uiMaterial } from '@kit.ArkUI';
import { hdsMaterial } from '@kit.UIDesignKit';

const STORE: string = 'miyou_settings';
const KEY_GLASS: string = 'glassLevel';

interface GateInfo {
  supported: boolean;
}

export class GlassTheme {
  private static ctx: common.UIAbilityContext | null = null;
  private static supportedCache: GateInfo | null = null;

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
    // 异步初始化能力检查，不阻塞页面
    setTimeout(() => GlassTheme.probeSupport(), 0);
  }

  private static probeSupport(): void {
    try {
      const types = hdsMaterial.getSystemMaterialTypes();
      GlassTheme.supportedCache = { supported: types.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0 };
    } catch (e) {
      GlassTheme.supportedCache = { supported: false };
    }
  }

  // 普通 ArkUI 组件用 systemMaterial；未支持/未初始化时返回 empty（不加材质）
  static material(level: number): uiMaterial.Material {
    if (level === 0 || !GlassTheme.supportedCache?.supported) {
      return uiMaterial.Material.empty;
    }
    let style: uiMaterial.ImmersiveStyle;
    switch (level) {
      case 1:
        style = uiMaterial.ImmersiveStyle.SMOOTH;
        break;
      case 2:
        style = uiMaterial.ImmersiveStyle.GENTLE;
        break;
      case 3:
        style = uiMaterial.ImmersiveStyle.EXQUISITE;
        break;
      default:
        style = uiMaterial.ImmersiveStyle.GENTLE;
    }
    return new uiMaterial.ImmersiveMaterial({ style, interactive: true });
  }

  // 背景透明度：材质自带色调，背景只做协调；Material 已接管透明度，不需要单独调低。
  static barColor(level: number): string {
    if (level === 0) {
      return '#FFF7F8FA';
    }
    return '#26F7F8FA';
  }

  static edgeColor(level: number): string {
    return level === 0 ? '#0D000000' : '#2EFFFFFF';
  }
}
