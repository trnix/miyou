import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export interface GameInfo {
  gids: number;
  name: string;
  short: string;
  color: string;
}

// 用户上传的 gids 探测结果：webHome 与首帖详情归属一致；不等于所有接口均已验证。
export const GAMES: GameInfo[] = [
  { gids: 2, name: '原神', short: '原神', color: '#1570EF' },
  { gids: 8, name: '绝区零', short: '绝区零', color: '#E66900' },
  { gids: 6, name: '崩坏：星穹铁道', short: '星穹铁道', color: '#6B5CE7' },
  { gids: 1, name: '崩坏3', short: '崩坏3', color: '#875BF7' },
  { gids: 3, name: '崩坏学园2', short: '学园2', color: '#F15A98' },
  { gids: 4, name: '未定事件簿', short: '未定事件簿', color: '#A67C3D' },
  { gids: 5, name: '大别野', short: '大别野', color: '#12B76A' },
  { gids: 9, name: '崩坏：因缘精灵', short: '因缘精灵', color: '#F79009' },
  { gids: 10, name: '星布谷地', short: '星布谷地', color: '#669F12' }
];

export function gameByGids(id: number): GameInfo {
  for (let i = 0; i < GAMES.length; i++) {
    if (GAMES[i].gids === id) { return GAMES[i]; }
  }
  return GAMES[0];
}

export function defaultOrder(): number[] {
  return GAMES.map((g: GameInfo) => g.gids);
}

// 只清理无效/重复编号，绝不把用户移出的频道重新加入。大别野为本版保留频道。
export function cleanOrder(raw: number[]): number[] {
  const out: number[] = [];
  raw.forEach((id: number) => {
    if (GAMES.some((g: GameInfo) => g.gids === id) && out.indexOf(id) < 0) { out.push(id); }
  });
  if (out.indexOf(5) < 0) { out.push(5); }
  return out;
}

export class GameTheme {
  private static ctx: common.UIAbilityContext | null = null;

  static hydrate(ctx: common.UIAbilityContext): void {
    GameTheme.ctx = ctx;
    AppStorage.setOrCreate('homeChannelOrder', GameTheme.read('homeChannelOrder'));
    AppStorage.setOrCreate('searchChannelOrder', GameTheme.read('searchChannelOrder'));
  }

  private static read(key: string): number[] {
    if (GameTheme.ctx === null) { return defaultOrder(); }
    try {
      const store = preferences.getPreferencesSync(GameTheme.ctx, { name: 'miyou_settings' });
      const text = store.getSync(key, '') as string;
      if (text === '') { return defaultOrder(); }
      const raw = JSON.parse(text) as Object;
      if (!Array.isArray(raw)) { return defaultOrder(); }
      return cleanOrder(raw as number[]);
    } catch (e) {
      return defaultOrder();
    }
  }

  static async save(target: string, order: number[]): Promise<void> {
    if (GameTheme.ctx === null) { throw new Error('频道配置尚未初始化'); }
    const key = target === 'search' ? 'searchChannelOrder' : 'homeChannelOrder';
    const next = cleanOrder(order);
    const store = preferences.getPreferencesSync(GameTheme.ctx, { name: 'miyou_settings' });
    const previous = store.getSync(key, '') as string;
    try {
      store.putSync(key, JSON.stringify(next));
      await store.flush();
    } catch (e) {
      store.putSync(key, previous);
      throw new Error('频道设置保存失败，请重试');
    }
    AppStorage.setOrCreate(key, next);
  }
}
