// 官方网页登录：用户在米哈游通行证官方页面自行登录，应用仅捕获 Cookie 会话，不接触账密。
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { AccountStore } from '../auth/AccountStore';

@Entry
@Component
struct Login {
  @State status: string = '请在下方米哈游通行证官方页面完成登录，检测到会话后会自动保存。';
  @State done: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();

  private checkLogin(): void {
    if (this.done) {
      return;
    }
    try {
      const domains: string[] = [
        'https://user.mihoyo.com',
        'https://www.miyoushe.com',
        'https://passport-api.mihoyo.com'
      ];
      const parts: string[] = [];
      domains.forEach((d: string) => {
        try {
          const c: string = webview.WebCookieManager.fetchCookieSync(d);
          if (c && c.length > 0) {
            parts.push(c);
          }
        } catch (e) {
          // 单域读取失败不影响其他域
        }
      });
      const combined: string = parts.join(';');
      const hasToken: boolean = /(ltoken|login_ticket|stoken)=/.test(combined);
      const hasUid: boolean = /(ltuid|stuid|account_id|login_uid)=\d+/.test(combined);
      if (hasToken && hasUid) {
        AccountStore.save(combined);
        this.done = true;
        this.status = '登录成功，会话已保存到本机。';
      } else {
        this.status = '尚未检测到登录会话，请先在页面内登录。';
      }
    } catch (e) {
      this.status = '读取登录状态失败，请稍后重试。';
    }
  }

  build() {
    Column() {
      Row() {
        Button('返回').onClick(() => router.back())
        Text('官方登录')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button(this.done ? '完成' : '检测')
          .onClick(() => {
            this.checkLogin();
            if (this.done) {
              router.back();
            }
          })
      }
      .width('100%')
      .padding(12)

      Web({ src: 'https://user.mihoyo.com/#/login?back_route=%252Fhome%252Faccount-overview', controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
        .mixedMode(MixedMode.None)
        .onPageEnd(() => this.checkLogin())
        .layoutWeight(1)
        .width('100%')

      Text(this.status)
        .fontSize(12)
        .fontColor(this.done ? '#067647' : '#667085')
        .width('100%')
        .padding(10)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }
}
