import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { Session } from '../auth/Session';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { GlassTheme } from '../view/GlassTheme';

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  private windowStageRef: window.WindowStage | null = null;

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

  // 窗口级全局沉浸：全屏布局 + 状态栏/导航条透明 + 深色内容色。
  // 每次返回前台重新应用，防止登录/相机/全屏 H5 等流程被系统改动后不复原。
  private applyWindowImmersion(): void {
    try {
      let win = this.mainWindow;
      if (win === null && this.windowStageRef !== null) {
        win = this.windowStageRef.getMainWindowSync();
        this.mainWindow = win;
      }
      if (win === null) {
        return;
      }
      win.setWindowLayoutFullScreen(true);
      const barProps: window.SystemBarProperties = {
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: '#000000',
        navigationBarContentColor: '#000000'
      };
      win.setWindowSystemBarProperties(barProps);
      this.updateSafeArea(win);
    } catch (e) {
      console.warn('米柚沉浸设置应用失败');
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.windowStageRef = windowStage;
    try {
      const windowClass = windowStage.getMainWindowSync();
      this.mainWindow = windowClass;
      this.applyWindowImmersion();
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

  onForeground(): void {
    // 从相机/其他 Ability/可能改动过栏设置的流程返回时，恢复全局沉浸基线
    this.applyWindowImmersion();
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
    this.windowStageRef = null;
  }
}
