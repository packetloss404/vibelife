import { readdir, readFile } from "node:fs/promises";
import { createHash } from "node:crypto";
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

  const extra = nativeFiles.filter((name) => !webFiles.includes(name));
  if (extra.length) {
    throw new Error(`Native Godot assets contain extra files: ${extra.join(", ")}`);
  }

  for (const file of webFiles) {
    const [webContent, nativeContent] = await Promise.all([
      readFile(path.join(webDir, file)),
      readFile(path.join(nativeDir, file))
    ]);
    const webHash = createHash("sha256").update(webContent).digest("hex");
    const nativeHash = createHash("sha256").update(nativeContent).digest("hex");

    if (webHash !== nativeHash) {
      throw new Error(`Native Godot asset drift detected for: ${file}`);
    }
  }
}

await assertNoDuplicateGodotFunctions();
await assertAssetCopiesExist();

console.log("check passed");
