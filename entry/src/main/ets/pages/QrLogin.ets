import { router } from '@kit.ArkUI';
import { QrLoginApi, QrStatus } from '../net/QrLoginApi';
import { Session } from '../auth/Session';
import { GlassTheme } from '../view/GlassTheme';

// R4.1 扫码登录：生成 → 轮询（1.5s）→ 确认写入。每轮轮询出结构级诊断行（无 token 明文），
// expired 自动刷新；请求批次号防止旧响应竞态；确认态必须拿到真 token 才落库，且整体替换会话（防跨账号残留）。
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
    this.start();
  }

  aboutToDisappear(): void {
    this.epoch++;
    this.stopPoll();
  }

  private stopPoll(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private async start(): Promise<void> {
    this.epoch++;
    const epoch = this.epoch;
    this.stopPoll();
    this.ticket = '';
    this.qrUrl = '';
    this.pollCount = 0;
    this.generating = true;
    this.statusText = '正在生成二维码…';
    this.debugText = '';
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
      this.timer = setInterval(() => {
        this.poll();
      }, 1500);
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
        this.start(); // 二维码过期，自动刷新后继续轮询
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
    if (!s.hasToken) {
      this.statusText = '确认响应缺少登录凭据，请重试';
      this.ticket = '';
      this.qrUrl = '';
      return;
    }
    this.statusText = '登录成功，正在写入凭据…';
    // 整体替换会话：不再与旧 Cookie 合并，防止跨账号身份残留
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
            Text('!')
              .fontSize(32)
              .fontColor('#F04438')
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
