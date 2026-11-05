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
  // currentTab 只做顶栏标题与底栏高亮显示，不绑定 Tabs 的 index 参数：
  // 点击底栏时立刻写它（高光瞬移），页面滑动动画由 TabsController 独立驱动，两者互不拖累
  @State currentTab: number = 0;
  private tabTitles: string[] = ['首页', '社区', '我的'];
  private readonly topBar: number = 56;
  private tabsController: TabsController = new TabsController();

  private vp(px: number): number {
    return this.getUIContext().px2vp(px);
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {}.width('100%').height('100%').backgroundColor('#F7F8FA')

      // 系统 Tabs：barHeight(0) 隐藏自带页签条，保留自定义悬浮底栏；
      // TabContent 自带懒加载 + 常驻保活 + 边缘横滑手势。
      // 不传 index 绑定，页面切换完全由控制器驱动（避免属性绑定被状态写入瞬跳吞动画）。
      Tabs({ barPosition: BarPosition.Start, controller: this.tabsController }) {
        TabContent() {
          HomeTab()
        }
        TabContent() {
          Column() {
            SearchTab()
          }
          .width('100%')
          .height('100%')
          .padding({ top: this.topBar + this.vp(this.safeTopPx) })
        }
        TabContent() {
          Column() {
            MineTab()
          }
          .width('100%')
          .height('100%')
          .padding({ top: this.topBar + this.vp(this.safeTopPx) })
        }
      }
      .width('100%')
      .height('100%')
      .barHeight(0)
      .scrollable(true)
      .animationDuration(280)
      .onChange((index: number) => {
        this.currentTab = index;
      })

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
            .onClick(() => {
              // 高光立即到位（纯显示状态，不绑定 index 不会瞬跳页面）
              this.currentTab = idx;
              // 页面滑动动画由控制器独立播放
              this.tabsController.changeIndex(idx);
            })
        })
      }.margin({ left: 16, right: 16, bottom: this.vp(this.safeBottomPx) }).padding(8)
        .backgroundColor(GlassTheme.barColor(this.glassLevel))
        .systemMaterial(GlassTheme.material(this.glassLevel))
        .border({ width: 0.5, color: GlassTheme.edgeColor(this.glassLevel) })
        .borderRadius(32).shadow({ radius: 24, color: '#26000000', offsetY: 8 })
    }.width('100%').height('100%')
  }
}
