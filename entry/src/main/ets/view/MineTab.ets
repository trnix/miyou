import { router } from '@kit.ArkUI';
import { Session } from '../auth/Session';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { MysHttp } from '../net/MysHttp';
import { Endpoints } from '../net/Endpoints';
import { GameRecord, RecordCardResult, GameRole } from '../model/GameRecord';
import { GlassTheme } from './GlassTheme';

@Component
export struct MineTab {
  @StorageLink('cookie') cookie: string = '';
  @StorageLink('glassLevel') glassLevel: number = 2;
  @State probeResult: string = '尚未探活。探活为三段式诊断：全头 / 裸请求 / bbs 用户态对照。';
  @State probing: boolean = false;
  private glassLabels: string[] = ['关闭', '弱', '中', '强'];

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
          Text('光感强度').fontSize(15).fontWeight(FontWeight.Medium)
          Row({ space: 8 }) {
            ForEach(this.glassLabels, (label: string, idx: number) => {
              Button(label)
                .layoutWeight(1)
                .backgroundColor(this.glassLevel === idx ? '#1570EF' : '#E4E7EC')
                .fontColor(this.glassLevel === idx ? '#FFFFFF' : '#344054')
                .onClick(() => GlassTheme.setLevel(idx))
            })
          }
          .width('100%')
          Text('顶栏与底栏的玻璃拟态强度，切换即时生效')
            .fontSize(12)
            .fontColor('#667085')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)

        Text('米柚 0.5.1 · 非官方米游社客户端 · 只读应用')
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
