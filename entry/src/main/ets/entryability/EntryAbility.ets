import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Session } from '../auth/Session';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { GlassTheme } from '../view/GlassTheme';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const windowClass = windowStage.getMainWindowSync();
      windowClass.setWindowLayoutFullScreen(true);
      // 手势导航的小白条区域报在 TYPE_NAVIGATION_INDICATOR，TYPE_SYSTEM 底部为 0，二者取大。
      const sysAvoid = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navAvoid = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate('safeTopPx', sysAvoid.topRect.height);
      const bottomPx = sysAvoid.bottomRect.height > navAvoid.bottomRect.height
        ? sysAvoid.bottomRect.height
        : navAvoid.bottomRect.height;
      AppStorage.setOrCreate('safeBottomPx', bottomPx);
    } catch (e) {
      AppStorage.setOrCreate('safeTopPx', 0);
      AppStorage.setOrCreate('safeBottomPx', 0);
    }
    Session.hydrate(this.context);
    DeviceIdentity.hydrate(this.context);
    GlassTheme.hydrate(this.context);
    windowStage.loadContent('pages/AppShell', (err) => {
      if (err.code) {
        console.error(`米柚启动失败: ${err.code} ${err.message}`);
      }
    });
  }
}
