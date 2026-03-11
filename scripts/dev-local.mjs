import { spawn } from "node:child_process";

console.log("Starting local VibeLife dev server...");
console.log("- Backend: http://localhost:3000");
console.log("- Browser admin/debug: http://localhost:3000");
console.log("- Godot client: open native-client/godot/project.godot and target http://localhost:3000");
console.log("");

const child = spawn("npm", ["run", "dev"], {
  stdio: "inherit",
  shell: true,
});

child.on("exit", (code) => {
  process.exit(code ?? 0);
});
