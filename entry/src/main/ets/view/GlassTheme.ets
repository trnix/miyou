// 光感玻璃主题：档位状态与官方沉浸光感材质生成。
// 档位：0 关闭 / 1 弱 / 2 中（默认）/ 3 强。
// 权威依据（harmonyos 官方 API 参考 arkts-apis-uimaterial）：
//   ImmersiveStyle 五档 = ULTRA_THIN / THIN / REGULAR / THICK / ULTRA_THICK；
//   普通 ArkUI 组件挂 .systemMaterial(new uiMaterial.ImmersiveMaterial(...))；
//   systemMaterial 不得与 backgroundBlurStyle 叠加（官方约束文档反例）；
//   materialColor 为纯不透明色时会遮住材质效果——利用它实现「关闭」档。
//   能力探测沿用官方最佳实践：hdsMaterial.getSystemMaterialTypes() 查询可用材质。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { uiMaterial } from '@kit.ArkUI';
import { hdsMaterial } from '@kit.UIDesignKit';

const STORE: string = 'miyou_settings';
const KEY_GLASS: string = 'glassLevel';

export class GlassTheme {
  private static ctx: common.UIAbilityContext | null = null;
  private static immersiveSupported: boolean = true;

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
    setTimeout(() => GlassTheme.probeSupport(), 0);
  }

  private static probeSupport(): void {
    try {
      const types = hdsMaterial.getSystemMaterialTypes();
      GlassTheme.immersiveSupported = types.length > 0;
    } catch (e) {
      GlassTheme.immersiveSupported = false;
    }
  }

  static material(level: number): uiMaterial.Material {
    if (level === 0 || !GlassTheme.immersiveSupported) {
      // 「关闭」：不透明赋色遮住材质层，等同无玻璃效果。
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR,
        interactive: false,
        materialColor: '#FFF7F8FA'
      });
    }
    let style: uiMaterial.ImmersiveStyle;
    switch (level) {
      case 1:
        style = uiMaterial.ImmersiveStyle.ULTRA_THIN;
        break;
      case 3:
        style = uiMaterial.ImmersiveStyle.THICK;
        break;
      default:
        style = uiMaterial.ImmersiveStyle.REGULAR;
    }
    return new uiMaterial.ImmersiveMaterial({
      style: style,
      interactive: true,
      lightEffect: { color: Color.White }
    });
  }

  // 栏背景：材质开启时色调主要由材质承担，背景只留极轻底色保持层次。
  static barColor(level: number): string {
    return level === 0 ? '#FFF7F8FA' : '#26F7F8FA';
  }

  static edgeColor(level: number): string {
    return level === 0 ? '#0D000000' : '#2EFFFFFF';
  }
}
