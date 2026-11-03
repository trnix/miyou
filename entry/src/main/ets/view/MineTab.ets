import { router } from '@kit.ArkUI';
import { Session } from '../auth/Session';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { MysHttp } from '../net/MysHttp';
import { RecordApi } from '../net/RecordApi';
import { Endpoints } from '../net/Endpoints';
import { GameRecord, RecordCardResult, GameRole } from '../model/GameRecord';
import { GlassTheme } from './GlassTheme';

@Component
export struct MineTab {
  @StorageLink('cookie') cookie: string = '';
  @StorageLink('glassLevel') glassLevel: number = 3;
  @State probeResult: string = '尚未探活。探活为三段式诊断：全头 / 裸请求 / bbs 用户态对照。';
  @State probing: boolean = false;
  @State recordTestResult: string = '未测试。用 DS2(4X) 签名头打 record 卡接口，验证卡片认证可行性。';
  @State recordTesting: boolean = false;

  private trimMsg(s: string): string {
    return s.length > 160 ? s.substring(0, 160) + '…' : s;
  }

  private extractMsg(body: string): string {
    try {
      const obj = JSON.parse(body) as Record<string, Object>;
      const rc = obj['retcode'];
      const msg = obj['message'];
      const rcText = typeof rc === 'number' ? rc.toString() : '?';
      const msgText = typeof msg === 'string' ? msg : '';
      return `retcode ${rcText}（${msgText}）`;
    } catch (e) {
      return this.trimMsg(body);
    }
  }

  private async probe(): Promise<void> {
    this.probing = true;
    this.probeResult = '探活中…';
    const uid = Session.stuid();
    const recordUrl = `${Endpoints.GAME_RECORD_CARD}?uid=${uid}`;
    const lines: string[] = [`uid: ${uid.length > 0 ? uid : '未提取到'}`];
    try {
      await DeviceIdentity.ensureFp();
      try {
        const a = await MysHttp.getObject(recordUrl, true);
        const ar: RecordCardResult = GameRecord.parseRoles(a);
        if (ar.ok && ar.roles.length > 0) {
          const names = ar.roles.map((r: GameRole) => `${r.nickname} Lv.${r.level}`).join('、');
          lines.push(`A 全头 record 域: 成功，角色 ${ar.roles.length} 个（${names}）`);
        } else {
          lines.push(`A 全头 record 域: retcode ${ar.retcode}（${this.trimMsg(ar.message)}）`);
        }
      } catch (e) {
        lines.push('A 全头 record 域: 网络异常');
      }
      try {
        const b = await MysHttp.getBare(recordUrl, true);
        lines.push(`B 裸请求 record 域: HTTP ${b.httpCode}，${this.extractMsg(b.body)}`);
      } catch (e) {
        lines.push('B 裸请求 record 域: 网络异常');
      }
      try {
        const c = await MysHttp.getBare(Endpoints.BBS_USER_INFO, true);
        lines.push(`C 裸请求 bbs 用户态: HTTP ${c.httpCode}，${this.extractMsg(c.body)}`);
      } catch (e) {
        lines.push('C 裸请求 bbs 用户态: 网络异常');
      }
    } finally {
      this.probing = false;
    }
    this.probeResult = lines.join('\n');
  }

  private async recordTest(): Promise<void> {
    this.recordTesting = true;
    this.recordTestResult = '测试中…';
    const uid = Session.stuid();
    const lines: string[] = [`uid: ${uid.length > 0 ? uid : '未提取到'}`];
    try {
      await DeviceIdentity.ensureFp();
      try {
        const raw = await RecordApi.gameRecordCard(uid);
        lines.push(`HTTP ${raw.httpCode}`);
        try {
          const obj = JSON.parse(raw.body) as Record<string, Object>;
          const rc = obj['retcode'];
          const msg = obj['message'];
          const rcText = typeof rc === 'number' ? rc.toString() : '?';
          const msgText = typeof msg === 'string' ? msg : '';
          lines.push(`retcode ${rcText}（${msgText}）`);
          if (typeof rc === 'number' && rc === 0) {
            const ar: RecordCardResult = GameRecord.parseRoles(obj);
            if (ar.ok && ar.roles.length > 0) {
              const names = ar.roles.map((r: GameRole) => `${r.nickname} Lv.${r.level}`).join('、');
              lines.push(`成功，角色 ${ar.roles.length} 个（${names}）`);
            } else {
              lines.push('retcode 0 但角色列表为空');
            }
          }
        } catch (e) {
          lines.push(`响应非 JSON：${this.trimMsg(raw.body)}`);
        }
      } catch (e) {
        lines.push('网络异常');
      }
    } finally {
      this.recordTesting = false;
    }
    this.recordTestResult = lines.join('\n');
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 10 }) {
          Text(this.cookie.length > 0 ? '已登录' : '未登录')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
          Text(this.cookie.length > 0 ? '会话仅存本机，仅用于查看授权数据' : '经米哈游通行证官方网页登录，不接触账密')
            .fontSize(12)
            .fontColor('#667085')
          Row({ space: 12 }) {
            Button(this.cookie.length > 0 ? '重新登录' : '去登录')
              .onClick(() => router.pushUrl({ url: 'pages/Login' }))
            if (this.cookie.length > 0) {
              Button('退出登录')
                .backgroundColor('#F04438')
                .onClick(() => Session.clear())
            }
          }
          if (this.cookie.length > 0) {
            Button('扫码登录（完整战绩凭据）')
              .onClick(() => router.pushUrl({ url: 'pages/QrLogin' }))
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        Column({ space: 10 }) {
          Text('账号探活').fontSize(15).fontWeight(FontWeight.Medium)
          Button(this.probing ? '探活中…' : '开始探活')
            .enabled(!this.probing)
            .onClick(() => {
              this.probe();
            })
          Text(this.probeResult)
            .fontSize(12)
            .fontColor('#667085')
            .width('100%')
            .lineHeight(18)
            .copyOption(CopyOptions.LocalDevice)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        Column({ space: 10 }) {
          Text('战绩签名测试').fontSize(15).fontWeight(FontWeight.Medium)
          Text('用 DS2(4X) 签名 + 现有 Cookie 调 record 卡接口，验证桌面卡片/战绩的认证可行性')
            .fontSize(12)
            .fontColor('#667085')
          Button(this.recordTesting ? '测试中…' : '开始测试')
            .enabled(!this.recordTesting)
            .onClick(() => {
              this.recordTest();
            })
          Text(this.recordTestResult)
            .fontSize(12)
            .fontColor('#667085')
            .width('100%')
            .lineHeight(18)
            .copyOption(CopyOptions.LocalDevice)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        Column({ space: 10 }) {
          Row() {
            Text('沉浸光感')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.glassLevel > 0 })
              .selectedColor('#1570EF')
              .onChange((isOn: boolean) => {
                GlassTheme.setLevel(isOn ? 3 : 0)
              })
          }
          .width('100%')
          Text('顶栏与底栏的沉浸玻璃拟态效果，开关即时生效')
            .fontSize(12)
            .fontColor('#667085')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        Text('米柚 0.6.0 · 非官方米游社客户端 · 只读应用')
          .fontSize(11)
          .fontColor('#98A2B3')
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 6 })
      }
      .width('100%')
      .padding(16)
    }
    .width('100%')
    .height('100%')
  }
}
