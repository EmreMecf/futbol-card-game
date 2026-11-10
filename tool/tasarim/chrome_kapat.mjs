// Kalıcı PvP Chrome'unu kapatır:  node --experimental-websocket tool/tasarim/chrome_kapat.mjs [port]
import { chromeBaglan } from './cdp.mjs';
const t = await chromeBaglan(+(process.argv[2] ?? 9340));
await t.gonder('Browser.close').catch(() => {});
process.exit(0);
