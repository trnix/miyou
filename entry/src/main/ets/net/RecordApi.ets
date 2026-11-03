import { MysHttp, RawResult } from './MysHttp';
import { DsSign } from './DsSign';
import { DeviceIdentity } from '../auth/DeviceIdentity';
import { Session } from '../auth/Session';
import { Endpoints } from './Endpoints';

// record 域（game_record）接口请求头：x-rpc 基线 + client_type=5 + DS2(4X) 签名 + Cookie。
// 与 QrLogin 的扫码头组完全分离，仅用于战绩/便签/角色卡链路。
export class RecordApi {
  private static readonly VER: string = DsSign.SIGN_VERSION;

  static async signedHeaders(query: string): Promise<Record<string, string>> {
    const headers: Record<string, string> = {
      'User-Agent': `Mozilla/5.0 (Linux; Android 12; Unspecified Device) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/103.0.5060.129 Mobile Safari/537.36 miHoYoBBS/${RecordApi.VER}`,
      'Accept': 'application/json, text/plain, */*',
      'x-rpc-app_version': RecordApi.VER,
      'x-rpc-client_type': '5',
      'x-rpc-device_id': DeviceIdentity.deviceId(),
      'x-rpc-device_fp': DeviceIdentity.deviceFp(),
      'x-rpc-device_name': 'HarmonyOS Phone',
      'x-rpc-device_model': 'HarmonyOS',
      'x-rpc-sys_version': '12',
      'x-rpc-channel': 'miyousheluodi',
      'x-rpc-verify_key': Endpoints.VERIFY_KEY,
      'Referer': 'https://webstatic.mihoyo.com/',
      'X-Requested-With': 'com.mihoyo.hyperion',
      'DS': await DsSign.ds2(DsSign.SALT_4X, '', query)
    };
    const cookie = Session.cookie();
    if (cookie.length > 0) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  // 战绩卡：GET game_record/card/api/getGameRecordCard?uid=<stuid>
  static async gameRecordCard(uid: string): Promise<RawResult> {
    const query = `uid=${uid}`;
    const url = `${Endpoints.GAME_RECORD_CARD}?${query}`;
    return await MysHttp.request(url, await RecordApi.signedHeaders(query));
  }
}
