import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';

@Entry
@Component
struct ToolWeb {
  @State url: string = '';
  @State title: string = '官方工具';
  private controller: webview.WebviewController = new webview.WebviewController();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    const value: string = params && params.url ? params.url : '';
    if (/^https:\/\/(www\.miyoushe\.com|webstatic\.mihoyo\.com)\//.test(value)) { this.url = value; }
    this.title = params && params.title ? params.title : '官方工具';
  }

  build() {
    Column() {
      Row() {
        Button('返回').onClick(() => router.back())
        Text(this.title).fontSize(18).layoutWeight(1).textAlign(TextAlign.Center)
        Button('刷新').onClick(() => this.controller.refresh())
      }.width('100%').padding(12)
      if (this.url) {
        Web({ src: this.url, controller: this.controller }).javaScriptAccess(true).domStorageAccess(true)
          .fileAccess(false).mixedMode(MixedMode.None).layoutWeight(1).width('100%')
      } else { Text('无效的官方工具地址').padding(24) }
    }.width('100%').height('100%').backgroundColor('#F7F8FA')
  }
}
