import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { AccountStore } from '../auth/AccountStore';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { GlassTheme } from '../view/GlassTheme';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const windowClass = windowStage.getMainWindowSync();
      windowClass.setWindowLayoutFullScreen(true);
      const avoid = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      AppStorage.setOrCreate('safeTopPx', avoid.topRect.height);
      AppStorage.setOrCreate('safeBottomPx', avoid.bottomRect.height);
    } catch (e) {
      AppStorage.setOrCreate('safeTopPx', 0);
      AppStorage.setOrCreate('safeBottomPx', 0);
    }
    AccountStore.hydrate(this.context);
    DeviceIdentity.hydrate(this.context);
    GlassTheme.hydrate(this.context);
    windowStage.loadContent('pages/AppShell', (err) => {
      if (err.code) {
        console.error(`米柚启动失败: ${err.code} ${err.message}`);
      }
    });
  }
}
