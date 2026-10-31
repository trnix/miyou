import { GlassTheme } from '../view/GlassTheme';
import { MineTab } from '../view/MineTab';
import { HomeTab } from '../view/HomeTab';
import { uiMaterial } from '@kit.ArkUI';

@Entry
@Component
struct AppShell {
  @StorageLink('glassLevel') glassLevel: number = 2;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State currentTab: number = 0;
  private tabTitles: string[] = ['首页', '社区', '消息', '我的'];
  private readonly topBar: number = 56;

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
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F7F8FA')

      Stack() {
        if (this.currentTab === 0) {
          HomeTab()
        } else {
          Column() {
            if (this.currentTab === 1) {
              this.PlaceholderTab('社区', '版区浏览将在后续里程碑接入\n（官方资讯 / 攻略 / 同人 / 酒馆）')
            } else if (this.currentTab === 2) {
              this.PlaceholderTab('消息', '消息中心为只读拉取，将在 R3 接入\n（需登录态）')
            } else {
              MineTab()
            }
          }
          .width('100%')
          .height('100%')
          .padding({ top: this.topBar + this.vp(this.safeTopPx) })
        }
      }
      .width('100%')
      .height('100%')

      Column() {
        Row() {
          Text('米柚').fontSize(20).fontWeight(FontWeight.Bold)
          Blank()
          Text(this.tabTitles[this.currentTab]).fontSize(14).fontColor('#667085')
        }
        .width('100%')
        .height(this.topBar + this.vp(this.safeTopPx))
        .padding({ top: this.vp(this.safeTopPx), left: 16, right: 16 })
        .systemMaterial(GlassTheme.material(this.glassLevel))
        .backgroundColor(GlassTheme.barColor(this.glassLevel))
        .border({ width: { bottom: 0.5 }, color: GlassTheme.edgeColor(this.glassLevel) })
      }
      .width('100%')
      .height('100%')

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
      .margin({ left: 16, right: 16, bottom: this.vp(this.safeBottomPx) })
      .padding(8)
      .backgroundColor(GlassTheme.barColor(this.glassLevel))
      .systemMaterial(GlassTheme.material(this.glassLevel))
      .border({ width: 0.5, color: GlassTheme.edgeColor(this.glassLevel) })
      .borderRadius(32)
      .shadow({ radius: 24, color: '#26000000', offsetY: 8 })
    }
    .width('100%')
    .height('100%')
  }
}
