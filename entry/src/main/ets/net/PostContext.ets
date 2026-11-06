// 只在本进程保存帖子ID到响应game_id的映射，不持久化账号或请求凭据。
function record(v: Object | undefined): Record<string, Object> {
  if (v !== null && typeof v === 'object' && !Array.isArray(v)) { return v as Record<string, Object>; }
  return {};
}
function idOf(v: Object | undefined): string {
  return typeof v === 'string' ? v : '';
}

export class PostContext {
  private static games: Map<string, number> = new Map<string, number>();

  private static rememberEntry(value: Object): void {
    const entry = record(value);
    const post = record(entry['post']);
    const forum = record(entry['forum']);
    const id = idOf(post['post_id']);
    const primary = Number(post['game_id']);
    const secondary = Number(forum['game_id']);
    const gid = Number.isInteger(primary) && primary > 0 ? primary : secondary;
    if (!/^\d+$/.test(id) || !Number.isInteger(gid) || gid <= 0) { return; }
    PostContext.games.delete(id);
    PostContext.games.set(id, gid);
    if (PostContext.games.size > 2048) {
      const keys: string[] = Array.from(PostContext.games.keys());
      PostContext.games.delete(keys[0]);
    }
  }

  static rememberLists(raw: Object): void {
    const root = record(raw);
    if (root['retcode'] !== 0) { return; }
    const data = record(root['data']);
    const keys: string[] = ['posts', 'fixed_posts', 'recommended_posts', 'list'];
    keys.forEach((key: string) => {
      const entries = data[key];
      if (Array.isArray(entries)) {
        (entries as Object[]).forEach((item: Object) => PostContext.rememberEntry(item));
      }
    });
  }

  static rememberDetail(raw: Object): void {
    const root = record(raw);
    if (root['retcode'] !== 0) { return; }
    const article = record(root['data'])['post'];
    if (article !== undefined && article !== null) { PostContext.rememberEntry(article); }
  }

  static gameOf(postId: string): number { return PostContext.games.get(postId) ?? 0; }

  static matchesDetail(raw: Object, expectedId: string): boolean {
    const root = record(raw);
    const article = record(record(root['data'])['post']);
    return root['retcode'] === 0 && idOf(record(article['post'])['post_id']) === expectedId;
  }

  // getSemPosts 语义层：整个 data.list 报告一遍候选 post_id（诊断证据）
  static listIds(raw: Object): string {
    const root = record(raw);
    const data = record(root['data']);
    const list = data['list'];
    if (!Array.isArray(list)) {
      return '';
    }
    const ids: string[] = [];
    (list as Object[]).forEach((entry: Object) => {
      const item = record(entry);
      const post = record(item['post']);
      const id = idOf(post['post_id']);
      if (id !== '') {
        ids.push(id);
      }
    });
    return '[' + ids.join(',') + ']';
  }

  // 从 data.list 严格按 post_id 精准命中一个元素（不近似首条）
  // 返回 Record（元素本身），允许调用方组装返回结构。
  static findDetailInList(raw: Object, expectedId: string): Record<string, Object> | undefined {
    const root = record(raw);
    const data = record(root['data']);
    const list = data['list'];
    if (!Array.isArray(list)) {
      return undefined;
    }
    const entries = list as Object[];
    for (let i = 0; i < entries.length; i++) {
      const item = record(entries[i]);
      const post = record(item['post']);
      if (idOf(post['post_id']) === expectedId) {
        return item;
      }
    }
    return undefined;
  }
}
