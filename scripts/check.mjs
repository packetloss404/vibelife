import { readdir, readFile } from "node:fs/promises";
import path from "node:path";

const root = process.cwd();

async function assertNoDuplicateGodotFunctions() {
  const filePath = path.join(root, "native-client", "godot", "scripts", "main.gd");
  const content = await readFile(filePath, "utf8");
  const names = [...content.matchAll(/^func\s+([A-Za-z0-9_]+)\(/gm)].map((match) => match[1]);
  const duplicates = [...new Set(names.filter((name, index) => names.indexOf(name) !== index))];

  if (duplicates.length) {
    throw new Error(`Duplicate Godot functions found: ${duplicates.join(", ")}`);
  }
}

async function assertAssetCopiesExist() {
  const webDir = path.join(root, "public", "assets", "models");
  const nativeDir = path.join(root, "native-client", "godot", "assets", "models");
  const webFiles = (await readdir(webDir)).filter((name) => name.endsWith(".gltf")).sort();
  const nativeFiles = (await readdir(nativeDir)).filter((name) => name.endsWith(".gltf")).sort();

  const missing = webFiles.filter((name) => !nativeFiles.includes(name));
  if (missing.length) {
    throw new Error(`Native Godot assets missing copies for: ${missing.join(", ")}`);
  }
}

await assertNoDuplicateGodotFunctions();
await assertAssetCopiesExist();

console.log("check passed");
