import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Session } from '../auth/Session';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { GlassTheme } from '../view/GlassTheme';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;

  private updateSafeArea(win: window.Window): void {
    try {
      const sysAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const navAvoid = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      AppStorage.setOrCreate('safeTopPx', sysAvoid.topRect.height);
      const sysBottom = sysAvoid.bottomRect.height;
      const navBottom = navAvoid.bottomRect.height;
      AppStorage.setOrCreate('safeBottomPx', sysBottom > navBottom ? sysBottom : navBottom);
    } catch (e) {
      console.warn('米柚安全区读取失败');
      AppStorage.setOrCreate('safeTopPx', 0);
      AppStorage.setOrCreate('safeBottomPx', 0);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    try {
      const windowClass = windowStage.getMainWindowSync();
      this.mainWindow = windowClass;
      windowClass.setWindowLayoutFullScreen(true);
      // 系统栏沉浸：状态栏/导航条颜色透明，内容延伸到屏幕边缘，小白条直接压在内容上。
      const barProps: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: '#000000',
        navigationBarContentColor: '#000000'
      };
      windowClass.setWindowSystemBarProperties(barProps);
      this.updateSafeArea(windowClass);
      windowClass.on('avoidAreaChange', (options: window.AvoidAreaOptions) => {
        if (options.type === window.AvoidAreaType.TYPE_SYSTEM ||
          options.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          this.updateSafeArea(windowClass);
        }
      });
    } catch (e) {
      console.warn('米柚窗口安全区初始化失败');
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

  onWindowStageDestroy(): void {
    if (this.mainWindow !== null) {
      try {
        this.mainWindow.off('avoidAreaChange');
      } catch (e) {
        console.warn('米柚移除避让区监听失败');
      }
      this.mainWindow = null;
    }
  }
}
