import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import * as THREE from "three";
import { GLTFExporter } from "three/examples/jsm/exporters/GLTFExporter.js";

if (!globalThis.FileReader) {
  globalThis.FileReader = class FileReader {
    constructor() {
      this.result = null;
      this.onloadend = null;
    }

    async readAsDataURL(blob) {
      const arrayBuffer = await blob.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);
      this.result = `data:${blob.type || "application/octet-stream"};base64,${buffer.toString("base64")}`;
      if (typeof this.onloadend === "function") {
        this.onloadend();
      }
    }
  };
}

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const outDir = path.resolve(__dirname, "../public/assets/models");

await mkdir(outDir, { recursive: true });

const exporter = new GLTFExporter();

const toGltf = (scene, animations = []) => new Promise((resolve, reject) => {
  exporter.parse(
    scene,
    (result) => resolve(JSON.stringify(result, null, 2)),
    (error) => reject(error),
    { binary: false, onlyVisible: true, trs: false, animations }
  );
});

const standard = (color, extra = {}) => new THREE.MeshStandardMaterial({ color, roughness: 0.7, metalness: 0.15, ...extra });
const quaternionValues = (angles) => angles.flatMap(([x, y, z]) => new THREE.Quaternion().setFromEuler(new THREE.Euler(x, y, z)).toArray());

const createTower = () => {
  const group = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(4, 7, 4), standard(0xc6d1d6));
  body.position.y = 3.5;
  group.add(body);

  const top = new THREE.Mesh(new THREE.CylinderGeometry(0, 3.5, 2.2, 4), standard(0x345061));
  top.rotation.y = Math.PI / 4;
  top.position.y = 8.3;
  group.add(top);

  for (const x of [-1.1, 1.1]) {
    for (const y of [2.1, 3.6, 5.1]) {
      const window = new THREE.Mesh(new THREE.BoxGeometry(0.6, 0.75, 0.12), standard(0x9cecff, { emissive: 0x26545d, roughness: 0.2 }));
      window.position.set(x, y, 2.05);
      group.add(window);
    }
  }

  return group;
};

const createHall = () => {
  const group = new THREE.Group();
  const base = new THREE.Mesh(new THREE.BoxGeometry(8, 4.2, 6), standard(0xd8d6cf));
  base.position.y = 2.1;
  group.add(base);

  const roof = new THREE.Mesh(new THREE.CylinderGeometry(0, 5.8, 2.2, 4), standard(0x805844));
  roof.rotation.y = Math.PI / 4;
  roof.position.y = 5.6;
  group.add(roof);

  const awning = new THREE.Mesh(new THREE.BoxGeometry(5, 0.2, 1.6), standard(0x395767));
  awning.position.set(0, 2.6, 3.2);
  group.add(awning);

  return group;
};

const createLantern = () => {
  const group = new THREE.Group();
  const post = new THREE.Mesh(new THREE.CylinderGeometry(0.12, 0.14, 2.2, 10), standard(0x627d88));
  post.position.y = 1.1;
  group.add(post);

  const head = new THREE.Mesh(new THREE.BoxGeometry(0.45, 0.45, 0.45), standard(0xaef3ff, { emissive: 0x2f7f90, roughness: 0.2 }));
  head.position.y = 2.35;
  group.add(head);
  return group;
};

const createTree = () => {
  const group = new THREE.Group();
  const trunk = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.28, 2.8, 8), standard(0x584434));
  trunk.position.y = 1.4;
  group.add(trunk);

  const canopyA = new THREE.Mesh(new THREE.SphereGeometry(1.35, 16, 16), standard(0x75ca92));
  canopyA.position.set(0, 3.1, 0);
  group.add(canopyA);
  const canopyB = new THREE.Mesh(new THREE.SphereGeometry(1.05, 16, 16), standard(0x8ed6a7));
  canopyB.position.set(0.55, 3.55, 0.25);
  group.add(canopyB);
  return group;
};

const createBench = () => {
  const group = new THREE.Group();
  const seat = new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.12, 0.6), standard(0xa7724f));
  seat.position.y = 0.65;
  group.add(seat);
  const back = new THREE.Mesh(new THREE.BoxGeometry(1.8, 0.8, 0.12), standard(0xa7724f));
  back.position.set(0, 1.05, -0.24);
  group.add(back);
  for (const x of [-0.72, 0.72]) {
    const leg = new THREE.Mesh(new THREE.BoxGeometry(0.12, 0.7, 0.12), standard(0x415058));
    leg.position.set(x, 0.33, 0);
    group.add(leg);
  }
  return group;
};

const createDockCrate = () => {
  const group = new THREE.Group();
  const crate = new THREE.Mesh(new THREE.BoxGeometry(1.2, 1.2, 1.2), standard(0x7f6147));
  crate.position.y = 0.6;
  group.add(crate);
  const band = new THREE.Mesh(new THREE.BoxGeometry(1.24, 0.18, 1.24), standard(0x32434b));
  band.position.y = 0.6;
  group.add(band);
  return group;
};

const createAvatarRunner = () => {
  const root = new THREE.Group();
  root.name = "AvatarRoot";

  const bodyMaterial = standard(0x8cd8ff, { roughness: 0.42, metalness: 0.2 });
  const trimMaterial = standard(0x17323f, { roughness: 0.72, metalness: 0.08 });
  const headMaterial = standard(0xf2c7a8, { roughness: 0.92, metalness: 0.02 });

  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.48, 1.22, 6, 12), bodyMaterial);
  torso.name = "Torso";
  torso.position.y = 2.05;
  root.add(torso);

  const head = new THREE.Mesh(new THREE.SphereGeometry(0.4, 18, 18), headMaterial);
  head.name = "Head";
  head.position.y = 3.42;
  root.add(head);

  const leftArm = new THREE.Mesh(new THREE.CapsuleGeometry(0.12, 0.92, 4, 10), trimMaterial);
  leftArm.name = "LeftArm";
  leftArm.position.set(-0.74, 2.32, 0);
  root.add(leftArm);

  const rightArm = leftArm.clone();
  rightArm.name = "RightArm";
  rightArm.position.x = 0.74;
  root.add(rightArm);

  const leftLeg = new THREE.Mesh(new THREE.CapsuleGeometry(0.14, 0.96, 4, 10), trimMaterial);
  leftLeg.name = "LeftLeg";
  leftLeg.position.set(-0.24, 0.98, 0);
  root.add(leftLeg);

  const rightLeg = leftLeg.clone();
  rightLeg.name = "RightLeg";
  rightLeg.position.x = 0.24;
  root.add(rightLeg);

  const idleClip = new THREE.AnimationClip("Idle", 1.6, [
    new THREE.NumberKeyframeTrack("AvatarRoot.position[y]", [0, 0.8, 1.6], [0, 0.06, 0]),
    new THREE.QuaternionKeyframeTrack("LeftArm.quaternion", [0, 0.8, 1.6], quaternionValues([[0, 0, -0.08], [0, 0, 0.08], [0, 0, -0.08]])),
    new THREE.QuaternionKeyframeTrack("RightArm.quaternion", [0, 0.8, 1.6], quaternionValues([[0, 0, 0.08], [0, 0, -0.08], [0, 0, 0.08]]))
  ]);

  const walkClip = new THREE.AnimationClip("Walk", 0.9, [
    new THREE.NumberKeyframeTrack("AvatarRoot.position[y]", [0, 0.45, 0.9], [0, 0.12, 0]),
    new THREE.QuaternionKeyframeTrack("LeftArm.quaternion", [0, 0.45, 0.9], quaternionValues([[0.7, 0, 0], [-0.7, 0, 0], [0.7, 0, 0]])),
    new THREE.QuaternionKeyframeTrack("RightArm.quaternion", [0, 0.45, 0.9], quaternionValues([[-0.7, 0, 0], [0.7, 0, 0], [-0.7, 0, 0]])),
    new THREE.QuaternionKeyframeTrack("LeftLeg.quaternion", [0, 0.45, 0.9], quaternionValues([[-0.8, 0, 0], [0.8, 0, 0], [-0.8, 0, 0]])),
    new THREE.QuaternionKeyframeTrack("RightLeg.quaternion", [0, 0.45, 0.9], quaternionValues([[0.8, 0, 0], [-0.8, 0, 0], [0.8, 0, 0]]))
  ]);

  return { root, animations: [idleClip, walkClip] };
};

const assets = {
  "skyport-tower": createTower,
  "market-hall": createHall,
  "street-lantern": createLantern,
  "garden-tree": createTree,
  "park-bench": createBench,
  "dock-crate": createDockCrate,
  "avatar-runner": createAvatarRunner
};

for (const [name, build] of Object.entries(assets)) {
  const scene = new THREE.Scene();
  const built = build();
  const root = built.root ?? built;
  const animations = built.animations ?? [];
  scene.add(root);
  const gltf = await toGltf(scene, animations);
  await writeFile(path.join(outDir, `${name}.gltf`), gltf, "utf8");
}

console.log(`Generated ${Object.keys(assets).length} glTF assets in ${outDir}`);
