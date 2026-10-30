// 官方网页登录：用户在米游社官方页面自行登录（内部会走通行证流程），应用仅捕获 Cookie 会话。
// 注意：user.mihoyo.com 的通行证 SPA 登录态存 localStorage 不落 Cookie，检测不到；
// www.miyoushe.com 登录后会话落成真实 Cookie（0.4.0 已验证），故以其为登录入口。
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { Session } from '../auth/Session';
import { GlassTheme } from '../view/GlassTheme';

@Entry
@Component
struct Login {
  @State status: string = '请在下方米游社官方页面完成登录，检测到会话后会自动保存。';
  @State done: boolean = false;
  @StorageLink('glassLevel') glassLevel: number = 2;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  private checkLogin(): void {
    if (this.done) {
      return;
    }
    this.status = '检测中…';
    try {
      const domains: string[] = [
        'https://www.miyoushe.com',
        'https://user.mihoyo.com',
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
        Session.save(combined);
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
      .height(56 + this.vp(this.safeTopPx))
      .padding({ top: this.vp(this.safeTopPx), left: 12, right: 12 })
      .backgroundColor(GlassTheme.barColor(this.glassLevel))
      .backgroundBlurStyle(GlassTheme.blur(this.glassLevel))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Web({ src: 'https://www.miyoushe.com/', controller: this.controller })
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
        .padding({ left: 12, right: 12, top: 10, bottom: 10 + this.vp(this.safeBottomPx) })
        .backgroundColor('#F7F8FA')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }
}
