import { router } from '@kit.ArkUI';
import { QrLoginApi, QrStatus } from '../net/QrLoginApi';
import { Session } from '../auth/Session';
import { GlassTheme } from '../view/GlassTheme';

// R4.2 扫码登录：二维码票证提升到 AppStorage（`qrSession`），页面重建（扫码相机切前后台）
// 等不打断扫码流程——重建后续用同一张票，恢复轮询，直到 expired 或 confirmed。
@Entry
@Component
struct QrLoginPage {
  @StorageLink('glassLevel') glassLevel: number = 3;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @State qrUrl: string = '';
  @State statusText: string = '正在生成二维码…';
  @State debugText: string = '';
  @State generating: boolean = true;
  private ticket: string = '';
  private flow: string = 'app';
  private timer: number = -1;
  private polling: boolean = false;
  private epoch: number = 0;
  private pollCount: number = 0;

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  aboutToAppear(): void {
    // 已有未过期票证直接续用，不重建二维码
    const saved = AppStorage.get<string>('qrSession');
    if (saved && saved.length > 0) {
      const idx = saved.indexOf('|');
      if (idx > 0) {
        this.flow = saved.substring(0, idx);
        this.ticket = saved.substring(idx + 1);
        this.qrUrl = ''; // URL 从上次页的内存已失，需重新生成；但票仍有效，让用户扫原图即可
        this.generating = false;
        this.statusText = '请使用米游社 App 扫码（或者点下方刷新）';
        this.debugText = `通道：${this.flow} · 恢复上轮票证`;
        this.pollCount = 0;
        this.resumePoll();
        return;
      }
    }
    this.start();
  }

  aboutToDisappear(): void {
    this.stopPoll();
  }

  private stopPoll(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private resumePoll(): void {
    this.stopPoll();
    this.timer = setInterval(() => {
      this.poll();
    }, 1500);
  }

  private async start(): Promise<void> {
    this.epoch++;
    const epoch = this.epoch;
    this.stopPoll();
    this.ticket = '';
    this.flow = 'app';
    this.qrUrl = '';
    this.pollCount = 0;
    this.generating = true;
    this.statusText = '正在生成二维码…';
    this.debugText = '';
    AppStorage.setOrCreate('qrSession', ''); // 新流程，清空旧票
    try {
      const r = await QrLoginApi.create();
      if (epoch !== this.epoch) {
        return;
      }
      if (!r.ok) {
        this.generating = false;
        this.statusText = `二维码生成失败\n${r.message}`;
        return;
      }
      this.ticket = r.ticket;
      this.flow = r.flow;
      this.qrUrl = r.url;
      this.generating = false;
      this.statusText = '请使用米游社 App 扫码';
      this.debugText = `通道：${r.flow}`;
      AppStorage.setOrCreate('qrSession', `${r.flow}|${r.ticket}`);
      this.resumePoll();
    } catch (e) {
      if (epoch === this.epoch) {
        this.generating = false;
        this.statusText = '网络异常，请检查网络后重试';
      }
    }
  }

  private async poll(): Promise<void> {
    if (this.polling || this.ticket === '') {
      return;
    }
    this.polling = true;
    const epoch = this.epoch;
    try {
      const s: QrStatus = await QrLoginApi.query(this.ticket, this.flow);
      if (epoch !== this.epoch) {
        return;
      }
      this.pollCount++;
      this.debugText = `#${this.pollCount} ${s.debugText}`;
      if (s.status === 'expired') {
        this.start(); // 过期自动刷新
        return;
      }
      if (s.status === 'scanned') {
        this.statusText = '已扫码，请在手机上确认登录';
      } else if (s.status === 'confirmed') {
        await this.finish(s);
        return;
      } else if (s.retcode !== 0) {
        this.statusText = `状态查询异常（${s.retcode}），重试中…`;
      }
    } catch (e) {
      this.debugText = `#${this.pollCount} 请求异常，等待下一轮`;
    } finally {
      this.polling = false;
    }
  }

  private async finish(s: QrStatus): Promise<void> {
    this.stopPoll();
    AppStorage.setOrCreate('qrSession', '');
    if (!s.hasToken) {
      this.statusText = '确认响应缺少登录凭据，请重试';
      this.ticket = '';
      this.qrUrl = '';
      return;
    }
    this.statusText = '登录成功，正在写入凭据…';
    Session.save(s.pairs.join('; '));
    this.statusText = '登录成功';
    router.back();
  }

  @Builder
  TopBar() {
    Row({ space: 12 }) {
      Text('←').fontSize(22).fontColor('#101828')
        .onClick(() => router.back())
      Text('扫码登录')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
      Text('').width(22)
    }
    .width('100%')
    .height(56 + this.vp(this.safeTopPx))
    .padding({ top: this.vp(this.safeTopPx), left: 16, right: 16 })
    .backgroundColor(GlassTheme.barColor(this.glassLevel))
    .systemMaterial(GlassTheme.material(this.glassLevel))
    .border({ width: { bottom: 0.5 }, color: GlassTheme.edgeColor(this.glassLevel) })
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column() {
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F8FA')

      Column({ space: 16 }) {
        Column({ space: 16 }) {
          if (this.generating) {
            Text('…')
              .fontSize(32)
              .fontColor('#98A2B3')
              .width(240)
              .height(240)
              .textAlign(TextAlign.Center)
          } else if (this.qrUrl !== '') {
            QRCode(this.qrUrl)
              .width(240)
              .height(240)
          } else {
            Text('?')
              .fontSize(32)
              .fontColor('#98A2B3')
              .width(240)
              .height(240)
              .textAlign(TextAlign.Center)
          }
          Text(this.statusText)
            .fontSize(14)
            .fontColor('#475467')
            .textAlign(TextAlign.Center)
            .lineHeight(20)
          Text('扫码登录可获取完整角色卡/战绩所需的凭据；二维码由米哈游官方签发，凭据仅存本机')
            .fontSize(12)
            .fontColor('#98A2B3')
            .textAlign(TextAlign.Center)
            .lineHeight(18)
          if (this.debugText !== '') {
            Text(this.debugText)
              .fontSize(11)
              .fontColor('#98A2B3')
              .textAlign(TextAlign.Center)
              .lineHeight(16)
              .copyOption(CopyOptions.LocalDevice)
          }
          Button('刷新二维码')
            .onClick(() => this.start())
        }
        .width('100%')
        .padding(24)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height('100%')
      .padding({ top: 56 + this.vp(this.safeTopPx), left: 16, right: 16 })
      .justifyContent(FlexAlign.Center)

      this.TopBar()
    }
    .width('100%')
    .height('100%')
  }
}
