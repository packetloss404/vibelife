import * as THREE from "https://unpkg.com/three@0.179.1/build/three.module.js";
import { GLTFLoader } from "https://unpkg.com/three@0.179.1/examples/jsm/loaders/GLTFLoader.js";

const elements = {
  displayName: document.querySelector("#displayName"),
  regionSelect: document.querySelector("#regionSelect"),
  joinButton: document.querySelector("#joinButton"),
  status: document.querySelector("#status"),
  activeRegion: document.querySelector("#activeRegion"),
  viewport: document.querySelector("#viewport"),
  viewerHint: document.querySelector("#viewerHint"),
  chatLog: document.querySelector("#chatLog"),
  chatInput: document.querySelector("#chatInput"),
  chatButton: document.querySelector("#chatButton"),
  inventoryList: document.querySelector("#inventoryList"),
  parcelList: document.querySelector("#parcelList")
};

const loader = new GLTFLoader();

const state = {
  socket: null,
  session: null,
  account: null,
  regions: [],
  persistence: "memory",
  parcels: [],
  avatars: new Map(),
  avatarMeshes: new Map(),
  keys: new Set(),
  pointerActive: false,
  yaw: 0,
  pitch: 0.45,
  lastSentAt: 0,
  cameraDistance: 12,
  localVelocity: new THREE.Vector3(),
  movementVector: new THREE.Vector3(),
  regionScene: null,
  clock: new THREE.Clock()
};

const viewer = {
  renderer: null,
  scene: null,
  camera: null,
  terrain: null,
  avatarRoot: null,
  decorRoot: null,
  parcelLines: new Map(),
  terrainBounds: 30,
  assetCache: new Map()
};

const tempVectorA = new THREE.Vector3();
const tempVectorB = new THREE.Vector3();

const status = (message, isError = false) => {
  elements.status.textContent = message;
  elements.status.className = isError ? "warning" : "muted";
};

const appendChat = (line) => {
  const entry = document.createElement("div");
  entry.className = "chat-message";
  entry.textContent = line;
  elements.chatLog.prepend(entry);
};

const renderInventory = (items = []) => {
  if (!items.length) {
    elements.inventoryList.textContent = "No items loaded yet.";
    return;
  }

  elements.inventoryList.innerHTML = items
    .map((item) => `<div>${item.name} - ${item.kind} - ${item.rarity}</div>`)
    .join("");
};

const renderParcels = () => {
  if (!state.parcels.length) {
    elements.parcelList.textContent = "No parcels loaded yet.";
    return;
  }

  elements.parcelList.innerHTML = state.parcels
    .map((parcel) => {
      const owner = parcel.ownerDisplayName ? `owned by ${parcel.ownerDisplayName}` : "unclaimed";
      const canClaim = state.session && !parcel.ownerAccountId;

      return `
        <div class="card compact-card">
          <strong>${parcel.name}</strong>
          <div>${parcel.tier} parcel - ${owner}</div>
          ${canClaim ? `<button data-claim-parcel="${parcel.id}" style="margin-top:10px;">Claim parcel</button>` : ""}
        </div>
      `;
    })
    .join("");

  syncParcelLines();
};

const loadParcels = async (regionId) => {
  const response = await fetch(`/api/regions/${regionId}/parcels`);
  const data = await response.json();
  state.parcels = data.parcels;
  renderParcels();
};

const hashNoise = (x, z) => {
  const value = Math.sin(x * 12.9898 + z * 78.233) * 43758.5453;
  return value - Math.floor(value);
};

const getTerrainHeight = (x, z) => {
  const radial = Math.max(0, 1 - Math.sqrt(x * x + z * z) / 32);
  const waves = Math.sin(x * 0.22) * 0.8 + Math.cos(z * 0.18) * 0.7 + Math.sin((x + z) * 0.15) * 0.5;
  const grit = (hashNoise(x * 0.3, z * 0.3) - 0.5) * 0.6;
  return Math.max(-1.2, waves * radial + grit);
};

const clampToWorld = (vector) => {
  vector.x = Math.max(-viewer.terrainBounds + 1.5, Math.min(viewer.terrainBounds - 1.5, vector.x));
  vector.z = Math.max(-viewer.terrainBounds + 1.5, Math.min(viewer.terrainBounds - 1.5, vector.z));
  vector.y = getTerrainHeight(vector.x, vector.z);
  return vector;
};

const makeLabelSprite = (text) => {
  const canvas = document.createElement("canvas");
  canvas.width = 256;
  canvas.height = 64;
  const context = canvas.getContext("2d");

  context.fillStyle = "rgba(5, 12, 16, 0.72)";
  context.beginPath();
  context.roundRect(8, 8, 240, 48, 18);
  context.fill();
  context.fillStyle = "#e9f8ff";
  context.font = "600 28px Segoe UI";
  context.textAlign = "center";
  context.textBaseline = "middle";
  context.fillText(text.slice(0, 20), canvas.width / 2, canvas.height / 2);

  const texture = new THREE.CanvasTexture(canvas);
  const material = new THREE.SpriteMaterial({ map: texture, transparent: true });
  const sprite = new THREE.Sprite(material);
  sprite.scale.set(4.8, 1.2, 1);
  sprite.position.y = 4.9;
  return sprite;
};

const createHumanoid = (avatarId, displayName, isSelf) => {
  const root = new THREE.Group();
  root.userData.avatarId = avatarId;

  const palette = isSelf
    ? { body: 0xffb36a, trim: 0x3d1f02, head: 0xf1c6a0 }
    : { body: 0x7ef5c6, trim: 0x103229, head: 0xcbd6db };

  const bodyMaterial = new THREE.MeshStandardMaterial({ color: palette.body, roughness: 0.48, metalness: 0.16 });
  const trimMaterial = new THREE.MeshStandardMaterial({ color: palette.trim, roughness: 0.7, metalness: 0.05 });
  const headMaterial = new THREE.MeshStandardMaterial({ color: palette.head, roughness: 0.95, metalness: 0.02 });

  const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.52, 1.35, 6, 12), bodyMaterial);
  body.position.y = 2.1;
  body.castShadow = true;
  root.add(body);

  const head = new THREE.Mesh(new THREE.SphereGeometry(0.42, 20, 20), headMaterial);
  head.position.y = 3.5;
  head.castShadow = true;
  root.add(head);

  const shoulderBar = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.18, 0.24), trimMaterial);
  shoulderBar.position.set(0, 2.55, 0);
  root.add(shoulderBar);

  const makeLimb = (x) => {
    const limb = new THREE.Mesh(new THREE.CapsuleGeometry(0.14, 0.82, 4, 10), trimMaterial);
    limb.position.set(x, 1.05, 0);
    limb.castShadow = true;
    return limb;
  };

  const leftLeg = makeLimb(-0.24);
  const rightLeg = makeLimb(0.24);
  const leftArm = makeLimb(-0.78);
  leftArm.position.y = 2.3;
  const rightArm = makeLimb(0.78);
  rightArm.position.y = 2.3;
  root.add(leftLeg, rightLeg, leftArm, rightArm);

  const shadow = new THREE.Mesh(
    new THREE.CircleGeometry(0.75, 24),
    new THREE.MeshBasicMaterial({ color: 0x061217, transparent: true, opacity: 0.26 })
  );
  shadow.rotation.x = -Math.PI / 2;
  shadow.position.y = 0.02;
  root.add(shadow);

  root.add(makeLabelSprite(displayName));
  root.userData.parts = { leftLeg, rightLeg, leftArm, rightArm };
  return root;
};

const syncParcelLines = () => {
  if (!viewer.scene) {
    return;
  }

  for (const [parcelId, line] of viewer.parcelLines.entries()) {
    if (!state.parcels.some((parcel) => parcel.id === parcelId)) {
      viewer.scene.remove(line);
      viewer.parcelLines.delete(parcelId);
    }
  }

  for (const parcel of state.parcels) {
    let line = viewer.parcelLines.get(parcel.id);

    if (!line) {
      const geometry = new THREE.BufferGeometry().setFromPoints(Array.from({ length: 5 }, () => new THREE.Vector3()));
      const material = new THREE.LineBasicMaterial({ color: parcel.ownerAccountId ? 0xffb36a : 0x66ffd1 });
      line = new THREE.Line(geometry, material);
      viewer.scene.add(line);
      viewer.parcelLines.set(parcel.id, line);
    }

    const positions = line.geometry.attributes.position;
    const coords = [
      [parcel.minX, parcel.minZ],
      [parcel.maxX, parcel.minZ],
      [parcel.maxX, parcel.maxZ],
      [parcel.minX, parcel.maxZ],
      [parcel.minX, parcel.minZ]
    ];
    coords.forEach(([x, z], index) => positions.setXYZ(index, x, getTerrainHeight(x, z) + 0.14, z));
    positions.needsUpdate = true;
    line.material.color.setHex(parcel.ownerAccountId ? 0xffb36a : 0x66ffd1);
  }
};

const makeTerrain = () => {
  const terrainGeometry = new THREE.PlaneGeometry(60, 60, 120, 120);
  terrainGeometry.rotateX(-Math.PI / 2);
  const positions = terrainGeometry.attributes.position;
  for (let index = 0; index < positions.count; index += 1) {
    const x = positions.getX(index);
    const z = positions.getZ(index);
    positions.setY(index, getTerrainHeight(x, z));
  }
  terrainGeometry.computeVertexNormals();

  const terrain = new THREE.Mesh(
    terrainGeometry,
    new THREE.MeshStandardMaterial({ color: 0x24586a, roughness: 0.96, metalness: 0.06 })
  );
  terrain.receiveShadow = true;
  return terrain;
};

const loadGltfAsset = async (url) => {
  if (!viewer.assetCache.has(url)) {
    viewer.assetCache.set(url, loader.loadAsync(url).then((gltf) => gltf.scene));
  }

  const scene = await viewer.assetCache.get(url);
  return scene.clone(true);
};

const createLanternGlow = () => {
  const light = new THREE.PointLight(0x8cecff, 4, 7, 2);
  light.position.y = 2.3;
  return light;
};

const applySceneObject = async (item) => {
  const object = await loadGltfAsset(item.asset);
  const [x, y = 0, z] = item.position;
  const [rx = 0, ry = 0, rz = 0] = item.rotation ?? [0, 0, 0];
  const [sx = 1, sy = 1, sz = 1] = item.scale ?? [1, 1, 1];

  object.position.set(x, getTerrainHeight(x, z) + y, z);
  object.rotation.set(rx, ry, rz);
  object.scale.set(sx, sy, sz);
  object.traverse((child) => {
    if (child.isMesh) {
      child.castShadow = true;
      child.receiveShadow = true;
    }
  });

  if (item.asset.includes("street-lantern")) {
    object.add(createLanternGlow());
  }

  viewer.decorRoot.add(object);
};

const loadRegionScene = async (regionId) => {
  if (!viewer.decorRoot) {
    return;
  }

  viewer.decorRoot.clear();

  const response = await fetch(`/scenes/${regionId}.json`);
  if (!response.ok) {
    throw new Error(`Scene manifest missing for ${regionId}`);
  }

  state.regionScene = await response.json();
  await Promise.all(state.regionScene.assets.map((item) => applySceneObject(item)));
};

const ensureViewer = () => {
  if (viewer.renderer) {
    return;
  }

  viewer.scene = new THREE.Scene();
  viewer.scene.fog = new THREE.Fog(0x0a1117, 24, 78);
  viewer.camera = new THREE.PerspectiveCamera(60, 1, 0.1, 300);
  viewer.camera.position.set(0, 8, 14);

  viewer.renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  viewer.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  viewer.renderer.outputColorSpace = THREE.SRGBColorSpace;
  viewer.renderer.shadowMap.enabled = true;
  viewer.renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  elements.viewport.prepend(viewer.renderer.domElement);

  const hemi = new THREE.HemisphereLight(0xa8ecff, 0x183140, 1.9);
  const sun = new THREE.DirectionalLight(0xfff4dd, 2.4);
  sun.position.set(18, 24, 7);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.camera.left = -40;
  sun.shadow.camera.right = 40;
  sun.shadow.camera.top = 40;
  sun.shadow.camera.bottom = -40;
  viewer.scene.add(hemi, sun);

  const sky = new THREE.Mesh(
    new THREE.SphereGeometry(140, 48, 32),
    new THREE.ShaderMaterial({
      side: THREE.BackSide,
      uniforms: {
        topColor: { value: new THREE.Color(0x6cc2ff) },
        bottomColor: { value: new THREE.Color(0x081018) }
      },
      vertexShader: `varying vec3 vWorldPosition; void main() { vec4 worldPosition = modelMatrix * vec4(position, 1.0); vWorldPosition = worldPosition.xyz; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
      fragmentShader: `uniform vec3 topColor; uniform vec3 bottomColor; varying vec3 vWorldPosition; void main() { float h = normalize(vWorldPosition + vec3(0.0, 40.0, 0.0)).y; gl_FragColor = vec4(mix(bottomColor, topColor, max(pow(max(h, 0.0), 1.3), 0.0)), 1.0); }`
    })
  );
  viewer.scene.add(sky);

  viewer.terrain = makeTerrain();
  viewer.decorRoot = new THREE.Group();
  viewer.avatarRoot = new THREE.Group();
  viewer.scene.add(viewer.terrain, viewer.decorRoot, viewer.avatarRoot);

  const waterRing = new THREE.Mesh(
    new THREE.RingGeometry(28, 38, 80),
    new THREE.MeshBasicMaterial({ color: 0x4ee4ff, transparent: true, opacity: 0.15, side: THREE.DoubleSide })
  );
  waterRing.rotation.x = -Math.PI / 2;
  waterRing.position.y = -0.2;
  viewer.scene.add(waterRing);

  const resize = () => {
    const width = elements.viewport.clientWidth;
    const height = Math.max(460, elements.viewport.clientHeight);
    viewer.camera.aspect = width / height;
    viewer.camera.updateProjectionMatrix();
    viewer.renderer.setSize(width, height);
  };

  window.addEventListener("resize", resize);
  resize();

  const animate = () => {
    window.requestAnimationFrame(animate);
    updateLocalMovement();
    updateCamera();
    animateAvatars();
    viewer.renderer.render(viewer.scene, viewer.camera);
  };

  animate();
};

const syncAvatarMeshes = () => {
  ensureViewer();

  for (const [avatarId, mesh] of state.avatarMeshes.entries()) {
    if (!state.avatars.has(avatarId)) {
      viewer.avatarRoot.remove(mesh);
      state.avatarMeshes.delete(avatarId);
    }
  }

  for (const [avatarId, avatar] of state.avatars.entries()) {
    let mesh = state.avatarMeshes.get(avatarId);
    if (!mesh) {
      mesh = createHumanoid(avatarId, avatar.displayName, state.session && avatarId === state.session.avatarId);
      viewer.avatarRoot.add(mesh);
      state.avatarMeshes.set(avatarId, mesh);
    }

    if (!mesh.userData.targetPosition) {
      mesh.userData.targetPosition = new THREE.Vector3();
    }

    mesh.userData.targetPosition.set(avatar.x, getTerrainHeight(avatar.x, avatar.z), avatar.z);
  }
};

const getSelfAvatar = () => state.session ? state.avatars.get(state.session.avatarId) : undefined;

const updateCamera = () => {
  const selfAvatar = getSelfAvatar();
  const mesh = selfAvatar ? state.avatarMeshes.get(selfAvatar.avatarId) : null;
  if (!mesh) {
    return;
  }

  const target = mesh.position.clone();
  target.y += 2.6;

  const offset = new THREE.Vector3(
    Math.sin(state.yaw) * Math.cos(state.pitch) * state.cameraDistance,
    Math.sin(state.pitch) * state.cameraDistance + 2,
    Math.cos(state.yaw) * Math.cos(state.pitch) * state.cameraDistance
  );

  tempVectorA.copy(target).add(offset);
  viewer.camera.position.lerp(tempVectorA, 0.08);
  viewer.camera.lookAt(target);
};

const animateAvatars = () => {
  const elapsed = state.clock.getElapsedTime();

  for (const [avatarId, mesh] of state.avatarMeshes.entries()) {
    const target = mesh.userData.targetPosition;
    if (!target) {
      continue;
    }

    const previous = mesh.position.clone();
    mesh.position.lerp(target, avatarId === state.session?.avatarId ? 0.24 : 0.12);
    const delta = previous.distanceTo(mesh.position);
    if (delta > 0.0001) {
      tempVectorB.copy(target).sub(previous);
      mesh.rotation.y = Math.atan2(tempVectorB.x, tempVectorB.z);
    }

    const stride = Math.min(1, delta * 32);
    const swing = Math.sin(elapsed * 8 + avatarId.length) * stride;
    mesh.userData.parts.leftLeg.rotation.x = swing;
    mesh.userData.parts.rightLeg.rotation.x = -swing;
    mesh.userData.parts.leftArm.rotation.x = -swing * 0.7;
    mesh.userData.parts.rightArm.rotation.x = swing * 0.7;
  }
};

const updateLocalMovement = () => {
  const selfAvatar = getSelfAvatar();
  if (!selfAvatar || !state.socket || state.socket.readyState !== WebSocket.OPEN) {
    state.clock.getDelta();
    return;
  }

  const delta = Math.min(0.05, state.clock.getDelta());
  state.movementVector.set(0, 0, 0);
  if (state.keys.has("KeyW")) state.movementVector.z -= 1;
  if (state.keys.has("KeyS")) state.movementVector.z += 1;
  if (state.keys.has("KeyA")) state.movementVector.x -= 1;
  if (state.keys.has("KeyD")) state.movementVector.x += 1;

  if (state.movementVector.lengthSq() === 0) {
    state.localVelocity.lerp(new THREE.Vector3(), 0.18);
    return;
  }

  state.movementVector.normalize();
  const forward = new THREE.Vector3(Math.sin(state.yaw), 0, Math.cos(state.yaw));
  const right = new THREE.Vector3(forward.z, 0, -forward.x);
  tempVectorA.copy(forward).multiplyScalar(-state.movementVector.z).add(right.multiplyScalar(state.movementVector.x)).normalize();
  state.localVelocity.lerp(tempVectorA.multiplyScalar(7.5), 0.16);

  const next = new THREE.Vector3(selfAvatar.x, selfAvatar.y, selfAvatar.z);
  next.x += state.localVelocity.x * delta;
  next.z += state.localVelocity.z * delta;
  clampToWorld(next);

  selfAvatar.x = Number(next.x.toFixed(2));
  selfAvatar.y = Number(next.y.toFixed(2));
  selfAvatar.z = Number(next.z.toFixed(2));
  selfAvatar.updatedAt = new Date().toISOString();

  const now = performance.now();
  if (now - state.lastSentAt > 70) {
    state.lastSentAt = now;
    state.socket.send(JSON.stringify({ type: "move", x: selfAvatar.x, y: selfAvatar.y, z: selfAvatar.z }));
  }
};

const loadRegions = async () => {
  const response = await fetch("/api/regions");
  const data = await response.json();
  state.regions = data.regions;
  elements.regionSelect.innerHTML = state.regions
    .map((region) => `<option value="${region.id}">${region.name} - ${region.population}/${region.capacity}</option>`)
    .join("");
  status("Ready to join.");
};

const connect = async () => {
  if (state.socket) {
    state.socket.close();
  }

  const response = await fetch("/api/auth/guest", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      displayName: elements.displayName.value,
      regionId: elements.regionSelect.value
    })
  });

  const data = await response.json();
  state.session = data.session;
  state.account = data.account;
  state.persistence = data.persistence;
  state.parcels = data.parcels;
  state.avatars = new Map([[data.avatar.avatarId, data.avatar]]);
  renderInventory(data.inventory);
  renderParcels();
  syncAvatarMeshes();
  await loadRegionScene(state.session.regionId);

  elements.activeRegion.textContent = state.regions.find((region) => region.id === state.session.regionId)?.name ?? state.session.regionId;
  elements.viewerHint.textContent = `Scene streaming live - ${state.session.regionId}`;

  const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
  const socket = new WebSocket(`${protocol}//${window.location.host}/ws/regions/${state.session.regionId}?token=${state.session.token}`);

  socket.addEventListener("open", () => {
    status(`Connected as ${state.session.displayName} (${state.persistence}).`);
    appendChat(`System: ${state.session.displayName} entered ${elements.activeRegion.textContent}.`);
  });

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);

    if (message.type === "snapshot") {
      state.avatars = new Map(message.avatars.map((avatar) => [avatar.avatarId, avatar]));
    }
    if (message.type === "avatar:joined" || message.type === "avatar:moved") {
      state.avatars.set(message.avatar.avatarId, message.avatar);
    }
    if (message.type === "avatar:left") {
      state.avatars.delete(message.avatarId);
    }
    if (message.type === "chat") {
      appendChat(`${message.displayName}: ${message.message}`);
    }

    syncAvatarMeshes();
  });

  socket.addEventListener("close", () => {
    status("Disconnected from region.", true);
  });

  state.socket = socket;
};

const sendChat = () => {
  const message = elements.chatInput.value.trim();
  if (!message || !state.socket || state.socket.readyState !== WebSocket.OPEN) {
    return;
  }

  state.socket.send(JSON.stringify({ type: "chat", message }));
  elements.chatInput.value = "";
};

elements.joinButton.addEventListener("click", () => {
  connect().catch((error) => status(error.message, true));
});

elements.parcelList.addEventListener("click", async (event) => {
  const target = event.target;
  if (!(target instanceof HTMLElement)) {
    return;
  }

  const parcelId = target.dataset.claimParcel;
  if (!parcelId || !state.session) {
    return;
  }

  const response = await fetch("/api/parcels/claim", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: state.session.token, parcelId })
  });

  if (!response.ok) {
    const error = await response.json();
    status(error.error ?? "Unable to claim parcel.", true);
    return;
  }

  await loadParcels(state.session.regionId);
  status("Parcel claimed.");
});

elements.chatButton.addEventListener("click", sendChat);
elements.chatInput.addEventListener("keydown", (event) => {
  if (event.key === "Enter") {
    sendChat();
  }
});

window.addEventListener("keydown", (event) => {
  if (event.target === elements.chatInput || event.target === elements.displayName) {
    return;
  }

  state.keys.add(event.code);
});

window.addEventListener("keyup", (event) => {
  state.keys.delete(event.code);
});

elements.viewport.addEventListener("pointerdown", () => {
  state.pointerActive = true;
});

window.addEventListener("pointerup", () => {
  state.pointerActive = false;
});

window.addEventListener("pointermove", (event) => {
  if (!state.pointerActive) {
    return;
  }

  state.yaw -= event.movementX * 0.005;
  state.pitch = Math.max(0.15, Math.min(1.1, state.pitch - event.movementY * 0.004));
});

elements.viewport.addEventListener(
  "wheel",
  (event) => {
    event.preventDefault();
    state.cameraDistance = Math.max(7, Math.min(18, state.cameraDistance + event.deltaY * 0.01));
  },
  { passive: false }
);

ensureViewer();
loadRegions().catch((error) => status(error.message, true));
