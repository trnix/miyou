// 首页骨架:演示断点自适应布局(手机 1 列 / 折叠屏与小平板 2 列 / 大屏 3 列)
@Entry
@Component
struct Index {
  @State items: string[] = [
    '占位卡片 1:版本资讯流',
    '占位卡片 2:官方公告',
    '占位卡片 3:同人图文',
    '占位卡片 4:攻略 Wiki',
    '占位卡片 5:每日签到',
    '占位卡片 6:游戏便签'
  ];

  build() {
    Scroll() {
      Column() {
        Text('米柚')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .margin({ top: 24, bottom: 4 })
        Text('非官方米游社第三方客户端 · 阶段 0 骨架')
          .fontSize(14)
          .fontColor('#888888')
          .margin({ bottom: 16 })
        GridRow({ columns: { xs: 1, sm: 1, md: 2, lg: 3 } }) {
          GridCol({ span: { sm: 1, md: 2, lg: 3 } }) {
            Text('下方卡片列数会随窗口宽度自动变化(1/2/3 列),用于验证一次开发、多端部署。')
              .fontSize(14)
              .fontColor('#666666')
              .margin({ bottom: 12 })
          }
          ForEach(this.items, (item: string) => {
            GridCol() {
              Column() {
                Text(item)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                Text('这里将展示帖子/资讯内容')
                  .fontSize(13)
                  .fontColor('#999999')
                  .margin({ top: 6 })
              }
              .alignItems(HorizontalAlign.Start)
              .width('100%')
              .padding(16)
              .borderRadius(12)
              .backgroundColor('#F5F6FA')
              .margin({ bottom: 12 })
            }
          }, (item: string) => item)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16 })
    .scrollBar(BarState.Off)
  }
}
