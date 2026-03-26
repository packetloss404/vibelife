import { spawn } from "node:child_process";

console.log("Starting local PacketCraft dev server...");
console.log("- Sidecar API: http://localhost:3000");
console.log("- Paper plugin: connect your Paper server to http://localhost:3000");
console.log("- Fabric mod: connect your Fabric client to the Paper server");
console.log("");

const child = spawn("npm", ["run", "dev"], {
  stdio: "inherit",
  shell: true,
});

child.on("exit", (code) => {
  process.exit(code ?? 0);
});
