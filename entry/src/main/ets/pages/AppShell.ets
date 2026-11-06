import { HdsNavigation, HdsNavigationTitleMode, HdsTabs, HdsTabsController,
  ScrollEffectType, hdsMaterial, HdsTabsFloatingStyle, TitleBarStyleOptions } from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { GlassTheme } from '../view/GlassTheme';
import { MineTab } from '../view/MineTab';
import { HomeTab } from '../view/HomeTab';
import { SearchTab } from '../view/SearchTab';

interface TabItem {
  label: string;
  normal: SymbolGlyphModifier;
  selected: SymbolGlyphModifier;
}

// 底栏图标：HDS 标准双色策略（未选=bottom_tab_icon_off 系，选中=activated 系）。
// BottomTabBarStyle 是 ArkUI 全局类型，无需导入（demo 与全站 HdsTabs 工程一致）。
const TAB_ITEMS: TabItem[] = [
  {
    label: '首页',
    normal: new SymbolGlyphModifier($r('sys.symbol.house_fill'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('sys.color.ohos_id_color_bottom_tab_icon_off'),
        $r('sys.color.ohos_id_color_bottom_tab_icon_auxcolor_off02')]),
    selected: new SymbolGlyphModifier($r('sys.symbol.house_fill'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('sys.color.ohos_id_color_activated'),
        $r('sys.color.ohos_id_color_primary_contrary')])
  },
  {
    label: '社区',
    normal: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('sys.color.ohos_id_color_bottom_tab_icon_off'),
        $r('sys.color.ohos_id_color_bottom_tab_icon_auxcolor_off02')]),
    selected: new SymbolGlyphModifier($r('sys.symbol.magnifyingglass'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('sys.color.ohos_id_color_activated'),
        $r('sys.color.ohos_id_color_primary_contrary')])
  },
  {
    label: '我的',
    normal: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('sys.color.ohos_id_color_bottom_tab_icon_off'),
        $r('sys.color.ohos_id_color_bottom_tab_icon_auxcolor_off02')]),
    selected: new SymbolGlyphModifier($r('sys.symbol.person_fill'))
      .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_COLOR)
      .fontColor([$r('sys.color.ohos_id_color_activated'),
        $r('sys.color.ohos_id_color_primary_contrary')])
  }
];

@Entry
@Component
struct AppShell {
  @StorageLink('glassLevel') glassLevel: number = 3;
  private tabsController: HdsTabsController = new HdsTabsController();
  private scHome: Scroller = new Scroller();
  private scSearch: Scroller = new Scroller();
  private scMine: Scroller = new Scroller();

  // 顶栏材质：开=IMMERSIVE + EXQUISITE/SMOOTH；关=不下发材质参数
  private titleStyle(): TitleBarStyleOptions {
    const style: TitleBarStyleOptions = {
      scrollEffectOpts: { enableScrollEffect: false, scrollEffectType: ScrollEffectType.GRADIENT_BLUR }
    };
    if (this.glassLevel > 0) {
      style.systemMaterialEffect = {
        materialType: hdsMaterial.MaterialType.IMMERSIVE,
        materialLevel: GlassTheme.hdsLevel()
      };
    }
    return style;
  }

  // 底栏材质：开=ADAPTIVE + EXQUISITE/SMOOTH；关=仅保留悬浮边距
  private floatingStyle(): HdsTabsFloatingStyle {
    if (this.glassLevel > 0) {
      return {
        barBottomMargin: 28,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: GlassTheme.hdsLevel()
        }
      };
    }
    return { barBottomMargin: 28 };
  }

  build() {
    HdsNavigation() {
      HdsTabs({ controller: this.tabsController }) {
        TabContent() {
          HomeTab({ scroller: this.scHome })
        }.tabBar(new BottomTabBarStyle(
          { normal: TAB_ITEMS[0].normal, selected: TAB_ITEMS[0].selected }, TAB_ITEMS[0].label))
        TabContent() {
          SearchTab({ scroller: this.scSearch })
        }.tabBar(new BottomTabBarStyle(
          { normal: TAB_ITEMS[1].normal, selected: TAB_ITEMS[1].selected }, TAB_ITEMS[1].label))
        TabContent() {
          MineTab({ scroller: this.scMine })
        }.tabBar(new BottomTabBarStyle(
          { normal: TAB_ITEMS[2].normal, selected: TAB_ITEMS[2].selected }, TAB_ITEMS[2].label))
      }
      .barOverlap(true)
      .vertical(false)
      .barPosition(BarPosition.End)
      .barFloatingStyle(this.floatingStyle())
    }
    .mode(NavigationMode.Stack)
    .titleBar({
      content: { title: { mainTitle: '米柚' } },
      style: this.titleStyle(),
      avoidLayoutSafeArea: false,
      enableComponentSafeArea: false
    })
    .bindToScrollable([this.scHome, this.scSearch, this.scMine])
    .hideBackButton(true)
    .titleMode(HdsNavigationTitleMode.MINI)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
