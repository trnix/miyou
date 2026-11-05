#!/usr/bin/env node
// 米游社 gids 探测器（scripts/probe-gids.mjs）
//
// 背景：webHome 信息流接口对「错误/未注册的 gids」不报错，而是静默返回其它游戏的内容
// （崩坏3 频道当年用 gids=3 实测返回崩坏学园2，正确值无法考证）。
// 因此本脚本绝不信任请求里的 gid，而是逐 gids 拉仅验证过的 webHome，
// 只认响应体自带的「forum 名字分布」与「game/game_id 信号字段」来定映射。
//
// 用法：node scripts/probe-gids.mjs           # 扫描 gids 1..14
//       node scripts/probe-gids.mjs 1 20      # 自定义范围（含端点）
// 要求：Node.js ≥ 18（内置 fetch），无需安装依赖。
// 输出：每个 gids 一段证据块（forum 分布 / game 信号 / 样本标题 / 详情层 game 字段），人工阅读定案。

const HOME = 'https://bbs-api-static.miyoushe.com/apihub/wapi/webHome';
const POST_FULL = 'https://bbs-api.miyoushe.com/post/wapi/getPostFull';

// 与 FeedApi.fetchHome 请求头完全一致
const HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
  'Referer': 'https://www.miyoushe.com/',
  'Origin': 'https://www.miyoushe.com',
  'X-Requested-With': 'XMLHttpRequest',
  'Accept': 'application/json, text/plain, */*'
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function jget(url) {
  try {
    const r = await fetch(url, { headers: HEADERS });
    const t = await r.text();
    try {
      return { status: r.status, json: JSON.parse(t) };
    } catch (e) {
      return { status: r.status, json: null, head: t.slice(0, 160) };
    }
  } catch (e) {
    return { status: 0, json: null, head: String(e) };
  }
}

// 递归挖 game / game_id / gameId 字段（限深度防爆）
function digGameFields(obj, path, out, depth) {
  if (obj === null || typeof obj !== 'object' || depth > 6) {
    return;
  }
  const keys = Object.keys(obj);
  for (const k of keys) {
    const v = (obj)[k];
    const lower = k.toLowerCase();
    if ((lower === 'game' || lower === 'game_id' || lower === 'gameid') && v !== null && v !== undefined) {
      const pv = typeof v === 'object' ? JSON.stringify(v).slice(0, 200) : String(v);
      out.add(`${path}.${k} = ${pv}`);
    }
    if (v !== null && typeof v === 'object') {
      digGameFields(v, `${path}.${k}`, out, depth + 1);
    }
  }
}

async function probe(g) {
  const res = await jget(`${HOME}?gids=${g}&page=1&page_size=10`);
  if (!res.json) {
    console.log(`\n=== gids=${g} === HTTP ${res.status} 非JSON: ${res.head ?? ''}`);
    return;
  }
  const json = res.json;
  const data = json['data'] ?? {};
  const fixed = Array.isArray(data['fixed_posts']) ? data['fixed_posts'] : [];
  const rec = Array.isArray(data['recommended_posts']) ? data['recommended_posts'] : [];
  const items = fixed.concat(rec);
  const forumVotes = new Map();
  const signals = new Set();
  const samples = [];
  let firstPostId = '';
  for (const it of items) {
    if (!it || typeof it !== 'object') {
      continue;
    }
    const forum = it['forum'];
    const post = it['post'];
    if (forum && typeof forum === 'object') {
      const name = typeof forum['name'] === 'string' ? forum['name'] : '(no-name)';
      forumVotes.set(name, (forumVotes.get(name) ?? 0) + 1);
    }
    if (post && typeof post === 'object') {
      if (firstPostId === '' && typeof post['post_id'] === 'string') {
        firstPostId = post['post_id'];
      }
      if (samples.length < 3 && typeof post['subject'] === 'string' && post['subject'] !== '') {
        samples.push(post['subject']);
      }
    }
    digGameFields(it, 'item', signals, 0);
  }
  console.log(`\n=== gids=${g} === retcode=${json['retcode']} posts=${items.length}`);
  const voteLine = Array.from(forumVotes.entries()).map((e) => `${e[0]}(${e[1]})`).join(', ');
  console.log(`  forum 分布: ${voteLine === '' ? '(空)' : voteLine}`);
  const sigArr = Array.from(signals).slice(0, 6);
  if (sigArr.length === 0) {
    console.log(`  game 信号: (响应中未能找到 game 字段)`);
  } else {
    sigArr.forEach((s) => console.log(`  game 信号: ${s}`));
  }
  samples.forEach((s) => console.log(`  样本标题: ${s}`));
  if (firstPostId !== '') {
    const detail = await jget(`${POST_FULL}?post_id=${encodeURIComponent(firstPostId)}&read=1`);
    if (detail.json && detail.json['data'] !== undefined) {
      const deep = new Set();
      digGameFields(detail.json['data'] ?? {}, 'data', deep, 0);
      const lines = Array.from(deep).slice(0, 6);
      if (lines.length === 0) {
        console.log(`  详情层: (无 game 字段)`);
      } else {
        lines.forEach((x) => console.log(`  详情层: ${x}`));
      }
    } else {
      console.log(`  详情层: getPostFull HTTP ${detail.status}，无法解析`);
    }
  }
}

async function main() {
  const argv = process.argv.slice(2);
  const start = argv[0] !== undefined ? Number(argv[0]) : 1;
  const end = argv[1] !== undefined ? Number(argv[1]) : 14;
  if (!Number.isFinite(start) || !Number.isFinite(end) || start <= 0 || start > end) {
    console.log('用法: node scripts/probe-gids.mjs [start] [end]，例如 1 14');
    process.exit(1);
  }
  console.log(`米游社 gids 探测器 · 扫描 ${start}..${end} · 每个 gids 2 个请求`);
  console.log('认定证据优先级: game 信号字段 > forum 分布多数 > 样本标题佐证');
  for (let g = start; g <= end; g++) {
    await probe(g);
    await sleep(250);
  }
  console.log('\n扫描完成。把上方整段输出贴回对话，就能核定 gid → 游戏 真实映射。');
}

main().catch((e) => {
  console.error('探测失败:', e);
  process.exit(1);
});
