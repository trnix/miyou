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
  @State probeResult: string = '尚未探活。探活流程：获取设备指纹 → getGameRecordCard → 显示角色。';
  @State probing: boolean = false;
  private glassLabels: string[] = ['关闭', '弱', '中', '强'];

  private async probe(): Promise<void> {
    this.probing = true;
    this.probeResult = '探活中…';
    try {
      await DeviceIdentity.ensureFp();
      const uid = Session.stuid();
      const url = `${Endpoints.GAME_RECORD_CARD}?uid=${uid}`;
      const raw = await MysHttp.getObject(url, true);
      const result: RecordCardResult = GameRecord.parseRoles(raw);
      if (result.ok) {
        if (result.roles.length > 0) {
          const names = result.roles.map((r: GameRole) => `${r.nickname} Lv.${r.level}`).join('、');
          this.probeResult = `探活成功：${names}`;
        } else {
          this.probeResult = '探活成功：接口正常，账号未绑定游戏角色。';
        }
      } else {
        this.probeResult = `探活失败：retcode ${result.retcode}（${result.message}）。-100/-10001 表示登录态失效，请重新登录。`;
      }
    } catch (e) {
      this.probeResult = '探活失败：网络异常，请检查网络后重试。';
    } finally {
      this.probing = false;
    }
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

        Text('米柚 0.5.0 · 非官方米游社客户端 · 只读应用')
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
