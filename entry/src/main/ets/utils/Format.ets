// 展示格式化工具

export class Format {
  static num(n: number): string {
    if (n >= 100000000) {
      return `${(n / 100000000).toFixed(1)}亿`;
    }
    if (n >= 10000) {
      return `${(n / 10000).toFixed(1)}万`;
    }
    return `${n}`;
  }

  static time(ts: number): string {
    const d = new Date(ts * 1000);
    const p = (x: number): string => x < 10 ? `0${x}` : `${x}`;
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
  }

  // 将帖子 HTML 正文转成纯文本(阶段1简化处理:去标签、保留换行、解码常见实体)
  static stripHtml(html: string): string {
    const AMP: string = String.fromCharCode(38);
    let s = html.replace(/<img[^>]*>/gi, '');
    s = s.replace(/<br\s*\/?>/gi, '\n');
    s = s.replace(/<\/p>/gi, '\n');
    s = s.replace(/<[^>]+>/g, '');
    // HTML 实体解码(用编码拼接避免源码层面的转义干扰)
    s = Format.replaceAll(s, AMP + 'nbsp;', ' ');
    s = Format.replaceAll(s, AMP + 'amp;', AMP);
    s = Format.replaceAll(s, AMP + 'lt;', '<');
    s = Format.replaceAll(s, AMP + 'gt;', '>');
    s = Format.replaceAll(s, AMP + 'quot;', '"');
    s = Format.replaceAll(s, AMP + '#39;', "'");
    s = s.replace(/\n{3,}/g, '\n\n');
    return s.trim();
  }

  private static replaceAll(s: string, from: string, to: string): string {
    return s.split(from).join(to);
  }
}
