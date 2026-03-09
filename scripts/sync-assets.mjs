import { copyFile, mkdir, readdir } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const sourceDir = path.resolve(__dirname, "../public/assets/models");
const targetDir = path.resolve(__dirname, "../native-client/godot/assets/models");

await mkdir(targetDir, { recursive: true });

const files = (await readdir(sourceDir)).filter((name) => name.endsWith(".gltf"));

for (const file of files) {
  await copyFile(path.join(sourceDir, file), path.join(targetDir, file));
}

console.log(`synced ${files.length} assets to ${targetDir}`);
