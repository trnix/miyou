import { GlassTheme } from '../view/GlassTheme';
import { MineTab } from '../view/MineTab';

@Entry
@Component
struct AppShell {
  @StorageLink('glassLevel') glassLevel: number = 2;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State currentTab: number = 0;
  private tabTitles: string[] = ['首页', '社区', '消息', '我的'];

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  @Builder
  PlaceholderTab(title: string, desc: string) {
    Column({ space: 10 }) {
      Text(title).fontSize(22).fontWeight(FontWeight.Medium)
      Text(desc)
        .fontSize(13)
        .fontColor('#667085')
        .textAlign(TextAlign.Center)
        .lineHeight(20)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(24)
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Row() {
          Text('米柚').fontSize(20).fontWeight(FontWeight.Bold)
          Blank()
          Text(this.tabTitles[this.currentTab]).fontSize(14).fontColor('#667085')
        }
        .width('100%')
        .height(56 + this.vp(this.safeTopPx))
        .padding({ top: this.vp(this.safeTopPx), left: 16, right: 16 })
        .backgroundColor(GlassTheme.barColor(this.glassLevel))
        .backgroundBlurStyle(GlassTheme.blur(this.glassLevel))
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Stack() {
          if (this.currentTab === 0) {
            this.PlaceholderTab('首页', '推荐与游戏频道信息流将在 M1 里程碑接入\n（蓝图 P0：getNewsFeed / webHome）')
          } else if (this.currentTab === 1) {
            this.PlaceholderTab('社区', '版区浏览将在后续里程碑接入\n（官方资讯 / 攻略 / 同人 / 酒馆）')
          } else if (this.currentTab === 2) {
            this.PlaceholderTab('消息', '消息中心为只读拉取，将在 M3 接入\n（需登录态）')
          } else {
            MineTab()
          }
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ bottom: 96 + this.vp(this.safeBottomPx) })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F8FA')

      Row() {
        ForEach(this.tabTitles, (title: string, idx: number) => {
          Column() {
            Text(title)
              .fontSize(13)
              .fontColor(this.currentTab === idx ? '#1570EF' : '#667085')
              .fontWeight(this.currentTab === idx ? FontWeight.Medium : FontWeight.Normal)
          }
          .layoutWeight(1)
          .padding({ top: 14, bottom: 14 })
          .backgroundColor(this.currentTab === idx ? '#2B1570EF' : '#00000000')
          .borderRadius(24)
          .onClick(() => {
            this.currentTab = idx;
          })
        })
      }
      .margin({ left: 16, right: 16, bottom: 8 + this.vp(this.safeBottomPx) })
      .padding(8)
      .backgroundColor(GlassTheme.barColor(this.glassLevel))
      .backgroundBlurStyle(GlassTheme.blur(this.glassLevel))
      .border({ width: 0.5, color: GlassTheme.edgeColor(this.glassLevel) })
      .borderRadius(32)
      .shadow({ radius: 24, color: '#26000000', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }
}
