import { UIAbility } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onWindowStageCreate(stage: window.WindowStage): void { this.prepare(stage); }

  private async prepare(stage: window.WindowStage): Promise<void> {
    try {
      const mainWindow = stage.getMainWindowSync();
      mainWindow.setWindowBackgroundColor('#F7F8FA');
      await mainWindow.setWindowSystemBarProperties({
        statusBarColor: '#00000000', navigationBarColor: '#00000000',
        statusBarContentColor: '#101828', navigationBarContentColor: '#101828'
      });
    } catch (e) { hilog.warn(0, 'miyou', 'System bars unavailable'); }
    stage.loadContent('pages/AppShell', (error) => {
      if (error.code) { hilog.error(0, 'miyou', 'Load shell failed: %{public}s', JSON.stringify(error)); }
    });
  }
}
