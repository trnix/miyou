// 光感玻璃主题：沉浸光感开关状态与材质参数工厂。
// 开关语义（v1.3 起）：0 = 关闭；3 = 开启（hydrate 时将旧值 1/2 归一为 3）。
// 两条材质线并存：
//   HDS 线（AppShell）：titleBar=IMMERSIVE、底栏=ADAPTIVE，等级经 hdsLevel() 给出
//     （EXQUISITE 优先，设备不支持 IMMERSIVE 材质时按官方建议降级 SMOOTH）；
//   uiMaterial 线（PostDetail 顶栏、频道栏等普通 ArkUI 组件）：material() 保持原状。
// 能力检测必须查 IMMERSIVE 成员：getSystemMaterialTypes() 非空仅代表存在任意材质类型。
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
    return stored !== undefined ? stored : 3;
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
      let v = store.getSync(KEY_GLASS, 3) as number;
      if (v !== 0 && v !== 3) {
        v = 3;
        store.putSync(KEY_GLASS, v);
        store.flush();
      }
      AppStorage.setOrCreate(KEY_GLASS, v);
    } catch (e) {
      AppStorage.setOrCreate(KEY_GLASS, 3);
    }
    setTimeout(() => GlassTheme.probeSupport(), 0);
  }

  private static probeSupport(): void {
    try {
      const types = hdsMaterial.getSystemMaterialTypes();
      GlassTheme.immersiveSupported = types.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0;
    } catch (e) {
      GlassTheme.immersiveSupported = false;
    }
  }

  // HDS 材质等级：支持 IMMERSIVE → EXQUISITE；否则 → SMOOTH（官方降级路径）。
  static hdsLevel(): hdsMaterial.MaterialLevel {
    return GlassTheme.immersiveSupported
      ? hdsMaterial.MaterialLevel.EXQUISITE
      : hdsMaterial.MaterialLevel.SMOOTH;
  }

  // uiMaterial 线：普通 ArkUI 组件（详情页顶栏、频道栏）继续沿用。
  static material(level: number): uiMaterial.Material {
    if (level === 0 || !GlassTheme.immersiveSupported) {
      // 「关闭」：不透明赋色遮住材质层，等同无玻璃效果。
      return new uiMaterial.ImmersiveMaterial({
        style: uiMaterial.ImmersiveStyle.REGULAR,
        interactive: false,
        materialColor: '#FFF7F8FA'
      });
    }
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THICK,
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
