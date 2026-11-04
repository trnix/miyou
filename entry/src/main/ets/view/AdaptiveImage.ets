// 自适应比例图片：先按 16:9 预估比例占位（布局从首帧起稳定，不再跳动），
// onComplete 拿到真实宽高后微调为真实比例，变化带短过渡。
// 比例限制在 0.5~3 之间：极端长图（如滚动截图）不会把页面拉成瀑布，点按仍可全屏看原图。

// ArkTS 禁止内联对象字面量作类型声明，具名 interface 是必须的写法
interface ImageCompleteInfo {
  width: number;
  height: number;
}

@Component
export struct AdaptiveImage {
  imageUrl: string = '';
  radius: number = 10;
  onTap: () => void = () => {};
  @State ratio: number = 1.78;

  build() {
    Image(this.imageUrl)
      .width('100%')
      .aspectRatio(this.ratio)
      .objectFit(ImageFit.Cover)
      .backgroundColor('#F2F4F7')
      .borderRadius(this.radius)
      .animation({ duration: 180, curve: Curve.EaseOut })
      .onComplete((event?: ImageCompleteInfo) => {
        if (event === undefined || event.width <= 0 || event.height <= 0) {
          return;
        }
        const r = event.width / event.height;
        this.ratio = Math.min(3, Math.max(0.5, r));
      })
      .onClick(() => {
        this.onTap();
      })
  }
}
