import { GlassTheme } from '../view/GlassTheme';
import { MineTab } from '../view/MineTab';
import { HomeTab } from '../view/HomeTab';
import { SearchTab } from '../view/SearchTab';

@Entry
@Component
struct AppShell {
  @StorageLink('glassLevel') glassLevel: number = 2;
  @StorageLink('safeTopPx') safeTopPx: number = 0;
  @StorageLink('safeBottomPx') safeBottomPx: number = 0;
  @State currentTab: number = 0;
  private tabTitles: string[] = ['首页', '社区', '我的'];
  private readonly topBar: number = 56;
  // Tab 保活：首次访问才挂载（懒加载），之后用 visibility 隐藏而非销毁，切换不再重新拉数据
  private visited: boolean[] = [true, false, false];

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  private switchTab(idx: number): void {
    if (this.currentTab === idx) {
      return;
    }
    this.visited[idx] = true;
    this.currentTab = idx;
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {}.width('100%').height('100%').backgroundColor('#F7F8FA')
      Stack() {
        if (this.visited[0]) {
          Column() {
            HomeTab()
          }
          .width('100%')
          .height('100%')
          .visibility(this.currentTab === 0 ? Visibility.Visible : Visibility.Hidden)
        }
        if (this.visited[1]) {
          Column() {
            SearchTab()
          }
          .width('100%')
          .height('100%')
          .padding({ top: this.topBar + this.vp(this.safeTopPx) })
          .visibility(this.currentTab === 1 ? Visibility.Visible : Visibility.Hidden)
        }
        if (this.visited[2]) {
          Column() {
            MineTab()
          }
          .width('100%')
          .height('100%')
          .padding({ top: this.topBar + this.vp(this.safeTopPx) })
          .visibility(this.currentTab === 2 ? Visibility.Visible : Visibility.Hidden)
        }
      }.width('100%').height('100%')
      Column() {
        Row() {
          Text('米柚').fontSize(20).fontWeight(FontWeight.Bold)
          Blank()
          Text(this.tabTitles[this.currentTab]).fontSize(14).fontColor('#667085')
        }.width('100%').height(this.topBar + this.vp(this.safeTopPx))
          .padding({ top: this.vp(this.safeTopPx), left: 16, right: 16 })
          .backgroundColor(GlassTheme.barColor(this.glassLevel))
          .systemMaterial(GlassTheme.material(this.glassLevel))
          .border({ width: { bottom: 0.5 }, color: GlassTheme.edgeColor(this.glassLevel) })
      }.width('100%').height('100%').hitTestBehavior(HitTestMode.None)
      Row() {
        ForEach(this.tabTitles, (title: string, idx: number) => {
          Column() {
            Text(title).fontSize(13)
              .fontColor(this.currentTab === idx ? '#1570EF' : '#667085')
              .fontWeight(this.currentTab === idx ? FontWeight.Medium : FontWeight.Normal)
          }.layoutWeight(1).padding({ top: 14, bottom: 14 })
            .backgroundColor(this.currentTab === idx ? '#2B1570EF' : '#00000000').borderRadius(24)
            .onClick(() => { this.switchTab(idx); })
        })
      }.margin({ left: 16, right: 16, bottom: this.vp(this.safeBottomPx) }).padding(8)
        .backgroundColor(GlassTheme.barColor(this.glassLevel))
        .systemMaterial(GlassTheme.material(this.glassLevel))
        .border({ width: 0.5, color: GlassTheme.edgeColor(this.glassLevel) })
        .borderRadius(32).shadow({ radius: 24, color: '#26000000', offsetY: 8 })
    }.width('100%').height('100%')
  }
}
