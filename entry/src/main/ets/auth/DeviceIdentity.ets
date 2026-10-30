// 设备身份：device_id 首启生成并持久化，device_fp 经公共接口获取。
// 二者必须成对稳定，否则易被风控判定为异常设备。
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { http } from '@kit.NetworkKit';
import { Endpoints } from '../net/Endpoints';

const STORE: string = 'miyou_device';
const KEY_ID: string = 'device_id';
const KEY_FP: string = 'device_fp';

export class DeviceIdentity {
  static hydrate(context: common.UIAbilityContext): void {
    try {
      const store = preferences.getPreferencesSync(context, { name: STORE });
      AppStorage.setOrCreate(KEY_ID, store.getSync(KEY_ID, '') as string);
      AppStorage.setOrCreate(KEY_FP, store.getSync(KEY_FP, '') as string);
    } catch (e) {
      AppStorage.setOrCreate(KEY_ID, '');
      AppStorage.setOrCreate(KEY_FP, '');
    }
  }

  static deviceId(): string {
    const cached = AppStorage.get<string>(KEY_ID) ?? '';
    if (cached.length > 0) {
      return cached;
    }
    try {
      const context = getContext() as common.UIAbilityContext;
      const store = preferences.getPreferencesSync(context, { name: STORE });
      const saved = store.getSync(KEY_ID, '') as string;
      const fresh = saved.length > 0 ? saved : util.generateRandomUUID(true);
      if (saved.length === 0) {
        store.putSync(KEY_ID, fresh);
        store.flush();
      }
      AppStorage.setOrCreate(KEY_ID, fresh);
      return fresh;
    } catch (e) {
      return '';
    }
  }

  static deviceFp(): string {
    return AppStorage.get<string>(KEY_FP) ?? '';
  }

  static async ensureFp(): Promise<void> {
    if (DeviceIdentity.deviceFp().length > 0) {
      return;
    }
    const deviceId = DeviceIdentity.deviceId();
    const body = {
      seed_id: util.generateRandomUUID(true),
      device_id: deviceId,
      platform: '5',
      seed_time: Date.now().toString(),
      ext_fields: '{"userAgent":"Hyperion/434","browserScreenSize":"2815200","maxTouchPoints":"5","isTouchSupported":"1","browserLanguage":"zh-CN","browserPlat":"Linux aarch64","browserTimeZone":"Asia/Shanghai","browserOnline":"true"}',
      app_name: 'bbs_cn',
      bbs_device_id: deviceId,
      device_fp: ''
    };
    const req = http.createHttp();
    try {
      const res = await req.request(Endpoints.DEVICE_FP, {
        method: http.RequestMethod.POST,
        expectDataType: http.HttpDataType.OBJECT,
        header: {
          'Content-Type': 'application/json',
          'User-Agent': Endpoints.USER_AGENT
        },
        extraData: JSON.stringify(body),
        connectTimeout: 10000,
        readTimeout: 10000
      });
      if (typeof res.result === 'string') {
        DeviceIdentity.saveFp(JSON.parse(res.result) as Record<string, Object>);
      } else {
        DeviceIdentity.saveFp(res.result as Record<string, Object>);
      }
    } finally {
      req.destroy();
    }
  }

  private static saveFp(obj: Record<string, Object>): void {
    const rc = obj['retcode'];
    if (typeof rc !== 'number' || rc !== 0) {
      return;
    }
    const data = obj['data'] as Record<string, Object> | undefined;
    const fp = data ? data['device_fp'] : undefined;
    if (typeof fp !== 'string' || fp.length === 0) {
      return;
    }
    AppStorage.setOrCreate(KEY_FP, fp);
    try {
      const context = getContext() as common.UIAbilityContext;
      const store = preferences.getPreferencesSync(context, { name: STORE });
      store.putSync(KEY_FP, fp);
      store.flush();
    } catch (e) {
      console.warn('DeviceIdentity persist fp failed');
    }
  }
}
