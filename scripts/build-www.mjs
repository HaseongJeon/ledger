/* 앱 파일만 www/ 로 모읍니다.
   Capacitor 는 webDir 폴더를 통째로 APK 에 넣기 때문에,
   저장소 루트를 그대로 가리키면 node_modules 와 android/ 까지 들어갑니다. */
import { cp, rm, mkdir, writeFile, readFile } from "node:fs/promises";
import { existsSync } from "node:fs";

const OUT = "www";
const FILES = ["index.html", "config.js", "manifest.json", "assets"];

await rm(OUT, { recursive: true, force: true });
await mkdir(OUT, { recursive: true });

for (const f of FILES) {
  if (!existsSync(f)) { console.warn(`  건너뜀 (없음): ${f}`); continue; }
  await cp(f, `${OUT}/${f}`, { recursive: true });
  console.log(`  ${f}`);
}

/* 네이티브 앱에서는 서비스 워커를 쓰지 않습니다.
   앱 자체가 이미 오프라인이고, 워커가 남으면 업데이트 후에도 옛 화면이 뜹니다. */
const html = await readFile(`${OUT}/index.html`, "utf8");
await writeFile(`${OUT}/index.html`, html.replace(
  '<link rel="manifest" href="manifest.json">',
  '<link rel="manifest" href="manifest.json">\n<meta name="jpc-native" content="1">'
));

console.log(`\n${OUT}/ 준비 완료`);
