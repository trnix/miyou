// 自适应比例图片：先按 16:9 预估比例占位（布局从首帧起稳定），
// onComplete 拿到真实宽高后按真实比例显示，不固定大小：
// - 常规图（0.7~2.4）：完整按真实比例显示（适用多图、长截图，长图到 0.7 下限开始 Cover）
// - 极宽 banner（>2.4）：装饰条/功能入口图，自动控制高度，避免一张细长图占据整个屏幕
// - 极小图（<0.7 且真实尺寸小）：表情包/装饰图标，限制展示高度，避免小图被拉成大图
// 点按仍可全屏看原图。

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
  @State maxHeight: number = 0; // 0 = 不限高

  build() {
    if (this.maxHeight > 0) {
      Image(this.imageUrl)
        .width('100%')
        .constraintSize({ maxHeight: this.maxHeight })
        .aspectRatio(this.ratio)
        .objectFit(ImageFit.Contain)
        .backgroundColor('#F2F4F7')
        .borderRadius(this.radius)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onComplete((event?: ImageCompleteInfo) => {
          this.adjust(event);
        })
        .onClick(() => {
          this.onTap();
        })
    } else {
      Image(this.imageUrl)
        .width('100%')
        .aspectRatio(this.ratio)
        .objectFit(ImageFit.Cover)
        .backgroundColor('#F2F4F7')
        .borderRadius(this.radius)
        .animation({ duration: 180, curve: Curve.EaseOut })
        .onComplete((event?: ImageCompleteInfo) => {
          this.adjust(event);
        })
        .onClick(() => {
          this.onTap();
        })
    }
  }

  private adjust(event?: ImageCompleteInfo): void {
    if (event === undefined || event.width <= 0 || event.height <= 0) {
      return;
    }
    const r = event.width / event.height;
    if (r > 8) {
      // 超细 banner/分隔条：原比例显示但限高，不让它身材主导屏幕高度
      this.ratio = r;
      this.maxHeight = 90;
    } else if (r > 2.4) {
      // 横幅图：压缩一半比例后按 Cover 显示，控制高度方向占比
      this.ratio = r / 2;
      this.maxHeight = 0;
    } else if (r < 0.7 && event.height <= 480) {
      // 表情包/装饰小图：全显 + 限高，避免被放大成大图
      this.ratio = Math.max(0.3, r);
      this.maxHeight = 120;
    } else {
      // 常规 + 长截图：完整按真实比例，长图呢 Cover 到 0.7 下限
      this.ratio = Math.min(2.4, Math.max(0.7, r));
      this.maxHeight = 0;
    }
  }
}
