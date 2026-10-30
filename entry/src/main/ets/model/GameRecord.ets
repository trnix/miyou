// getGameRecordCard 响应的防御性解析：任何字段缺失/变质都不抛错。

export interface GameRole {
  gameId: number;
  region: string;
  uid: string;
  nickname: string;
  level: number;
}

export interface RecordCardResult {
  ok: boolean;
  retcode: number;
  message: string;
  roles: GameRole[];
}

function asNum(v: Object | undefined): number {
  if (typeof v === 'number') {
    return v;
  }
  return 0;
}

function asStr(v: Object | undefined): string {
  if (typeof v === 'string') {
    return v;
  }
  return '';
}

export class GameRecord {
  static parseRoles(raw: Object): RecordCardResult {
    const obj = raw as Record<string, Object>;
    const rc = obj['retcode'];
    const retcode = typeof rc === 'number' ? rc : -1;
    const message = asStr(obj['message']);
    const roles: GameRole[] = [];
    try {
      const data = obj['data'] as Record<string, Object> | undefined;
      const listRaw = data ? data['list'] : undefined;
      if (Array.isArray(listRaw)) {
        (listRaw as Object[]).forEach((item: Object) => {
          const it = item as Record<string, Object>;
          roles.push({
            gameId: asNum(it['game_id']),
            region: asStr(it['region']),
            uid: asStr(it['game_role_id']),
            nickname: asStr(it['nickname']),
            level: asNum(it['level'])
          });
        });
      }
    } catch (e) {
      // 单个角色解析失败不影响整体
    }
    return { ok: retcode === 0, retcode, message, roles };
  }
}
