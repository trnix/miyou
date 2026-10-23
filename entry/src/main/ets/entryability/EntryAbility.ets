import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'miyou', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'miyou', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    this.prepareWindow(windowStage);
  }

  private async prepareWindow(windowStage: window.WindowStage): Promise<void> {
    try {
      const mainWindow = windowStage.getMainWindowSync();
      // Match the current light homepage and avoid a separate white gesture-area strip.
      mainWindow.setWindowBackgroundColor('#F7F8FA');
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000',
        navigationBarColor: '#00000000',
        statusBarContentColor: '#101828',
        navigationBarContentColor: '#101828'
      });
      // Keep layout avoidance until every page has explicit safe-area handling.
      // Index expands only its background; controls remain inside the safe area.
    } catch (e) {
      hilog.warn(0x0000, 'miyou', '%{public}s',
        'System bar configuration unavailable; continuing with default window.');
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'miyou', 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, 'miyou', '%{public}s', 'Content loaded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'miyou', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'miyou', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'miyou', '%{public}s', 'Ability onBackground');
  }
}
