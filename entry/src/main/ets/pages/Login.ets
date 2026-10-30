// 官方网页登录 + Cookie 诊断版：
// - 登录入口用 user.mihoyo.com（直达登录页，体验好）
// - 「检测」对 7 个候选域逐个读取 Cookie，仅列键名不列值；并用 JS document.cookie 对照，
//   区分「HttpOnly Cookie（原生可读/JS不可读）」与「未落 Cookie（两侧皆无）」两种情形。
// - 报告可长按复制，便于回传排查。
import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { Session } from '../auth/Session';
import { GlassTheme } from '../view/GlassTheme';

@Entry
@Component
struct Login {
  @State status: string = '请在下方页面完成登录，然后点「检测」。诊断只列 Cookie 键名，不含值。';
  @State done: boolean = false;
  @StorageLink('glassLevel') glassLevel: number = 2;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  private controller: webview.WebviewController = new webview.WebviewController();
  private domains: string[] = [
    'https://user.mihoyo.com',
    'https://www.miyoushe.com',
    'https://miyoushe.com',
    'https://passport-api.mihoyo.com',
    'https://webapi.account.mihoyo.com',
    'https://api-takumi-record.mihoyo.com',
    'https://www.mihoyo.com'
  ];

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  private cookieKeys(cookie: string): string[] {
    const keys: string[] = [];
    if (!cookie || cookie.length === 0) {
      return keys;
    }
    cookie.split(';').forEach((pair: string) => {
      const p = pair.trim();
      const eq = p.indexOf('=');
      if (eq > 0) {
        keys.push(p.substring(0, eq));
      }
    });
    return keys;
  }

  private hostOf(url: string): string {
    return url.replace('https://', '');
  }

  private collect(): string {
    const parts: string[] = [];
    this.domains.forEach((d: string) => {
      try {
        const c: string = webview.WebCookieManager.fetchCookieSync(d);
        if (c && c.length > 0) {
          parts.push(c);
        }
      } catch (e) {
        // 单域读取失败不影响其他域
      }
    });
    return parts.join(';');
  }

  private trySave(): boolean {
    const combined = this.collect();
    const hasToken: boolean = /(ltoken|login_ticket|stoken)=/.test(combined);
    const hasUid: boolean = /(ltuid|stuid|account_id|login_uid)=\d+/.test(combined);
    if (hasToken && hasUid) {
      Session.save(combined);
      return true;
    }
    return false;
  }

  private autoCheck(): void {
    if (this.done) {
      return;
    }
    if (this.trySave()) {
      this.done = true;
      this.status = '登录成功，会话已保存到本机。';
    }
  }

  private diagnose(): void {
    if (this.done) {
      return;
    }
    this.status = '检测中…';
    const lines: string[] = [];
    this.domains.forEach((d: string) => {
      let c = '';
      try {
        c = webview.WebCookieManager.fetchCookieSync(d);
      } catch (e) {
        // 单域读取失败按无 Cookie 处理
      }
      const keys = this.cookieKeys(c);
      if (keys.length > 0) {
        lines.push(`√ ${this.hostOf(d)} (${keys.length}): ${keys.join(', ')}`);
      } else {
        lines.push(`× ${this.hostOf(d)}: 无`);
      }
    });
    if (this.trySave()) {
      this.done = true;
      lines.unshift('√ 关键会话键已找到，会话已保存到本机');
    } else {
      lines.push('× 关键会话键（token 类 + uid 类）未找到');
    }
    this.status = lines.join('\n');
    this.controller.runJavaScript('document.cookie').then((jsCookie: string) => {
      const jsKeys = this.cookieKeys(jsCookie);
      const extra = jsKeys.length > 0 ? jsKeys.join(', ') : '无';
      this.status = `${lines.join('\n')}\nJS可见(${jsKeys.length}): ${extra}`;
    }).catch(() => {
      this.status = `${lines.join('\n')}\nJS侧读取失败`;
    });
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
            if (this.done) {
              router.back();
            } else {
              this.diagnose();
            }
          })
      }
      .width('100%')
      .height(56 + this.vp(this.safeTopPx))
      .padding({ top: this.vp(this.safeTopPx), left: 12, right: 12 })
      .backgroundColor(GlassTheme.barColor(this.glassLevel))
      .backgroundBlurStyle(GlassTheme.blur(this.glassLevel))
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Web({ src: 'https://user.mihoyo.com/#/login?back_route=%252Fhome%252Faccount-overview', controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .fileAccess(false)
        .mixedMode(MixedMode.None)
        .onPageEnd(() => this.autoCheck())
        .layoutWeight(1)
        .width('100%')

      Scroll() {
        Text(this.status)
          .fontSize(11)
          .fontColor(this.done ? '#067647' : '#667085')
          .width('100%')
          .lineHeight(17)
          .copyOption(CopyOptions.LocalDevice)
      }
      .width('100%')
      .constraintSize({ maxHeight: 200 })
      .padding({ left: 12, right: 12, top: 8, bottom: 8 + this.vp(this.safeBottomPx) })
      .backgroundColor('#F7F8FA')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F8FA')
  }
}
