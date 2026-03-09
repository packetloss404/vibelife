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
  parcelList: document.querySelector("#parcelList"),
  buildModeButton: document.querySelector("#buildModeButton"),
  buildAssetSelect: document.querySelector("#buildAssetSelect"),
  builderHelp: document.querySelector("#builderHelp"),
  builderObjectList: document.querySelector("#builderObjectList")
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
  regionObjects: [],
  buildMode: false,
  selectedObjectId: null,
  keys: new Set(),
  pointerActive: false,
  pointerMoved: false,
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
  staticRoot: null,
  dynamicRoot: null,
  parcelLines: new Map(),
  dynamicObjects: new Map(),
  selectionHelper: null,
  terrainBounds: 30,
  assetCache: new Map()
};

const tempVectorA = new THREE.Vector3();
const tempVectorB = new THREE.Vector3();
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();

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

const renderBuilderList = () => {
  if (!state.session) {
    elements.builderObjectList.textContent = "Join a region to load buildable objects.";
    return;
  }

  const mine = state.regionObjects.filter((item) => item.ownerAccountId === state.session.accountId);

  if (!mine.length) {
    elements.builderObjectList.textContent = "No editable objects yet.";
    return;
  }

  elements.builderObjectList.innerHTML = mine
    .map((item) => {
      const assetName = item.asset.split("/").pop().replace(".gltf", "").replaceAll("-", " ");
      const activeClass = item.id === state.selectedObjectId ? " active" : "";
      return `
        <button class="card compact-card${activeClass}" data-select-object="${item.id}">
          <strong>${assetName}</strong>
          <div>x ${item.x.toFixed(1)} / z ${item.z.toFixed(1)}</div>
        </button>
      `;
    })
    .join("");
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

const buildRenderableObject = async (item, editable = false) => {
  const object = await loadGltfAsset(item.asset);
  object.position.set(item.x, item.y, item.z);
  object.rotation.y = item.rotationY ?? 0;
  object.scale.setScalar(item.scale ?? 1);
  object.userData.objectId = item.id;
  object.userData.editable = editable;
  object.userData.ownerAccountId = item.ownerAccountId ?? null;
  object.userData.asset = item.asset;

  object.traverse((child) => {
    if (child.isMesh) {
      child.castShadow = true;
      child.receiveShadow = true;
      child.userData.objectId = item.id;
      child.userData.editable = editable;
    }
  });

  if (item.asset.includes("street-lantern")) {
    object.add(createLanternGlow());
  }

  return object;
};

const selectObject = (objectId) => {
  state.selectedObjectId = objectId;

  if (viewer.selectionHelper) {
    viewer.scene.remove(viewer.selectionHelper);
    viewer.selectionHelper = null;
  }

  if (objectId && viewer.dynamicObjects.has(objectId)) {
    viewer.selectionHelper = new THREE.BoxHelper(viewer.dynamicObjects.get(objectId), 0xffb36a);
    viewer.scene.add(viewer.selectionHelper);
  }

  renderBuilderList();
};

const refreshSelectionHelper = () => {
  if (viewer.selectionHelper) {
    viewer.selectionHelper.update();
  }
};

const loadRegionScene = async (regionId) => {
  if (!viewer.staticRoot) {
    return;
  }

  viewer.staticRoot.clear();
  const response = await fetch(`/scenes/${regionId}.json`);
  if (!response.ok) {
    throw new Error(`Scene manifest missing for ${regionId}`);
  }

  state.regionScene = await response.json();
  await Promise.all(
    state.regionScene.assets.map(async (item) => {
      const instance = await buildRenderableObject({
        id: item.id,
        asset: item.asset,
        x: item.position[0],
        y: getTerrainHeight(item.position[0], item.position[2]) + (item.position[1] ?? 0),
        z: item.position[2],
        rotationY: item.rotation?.[1] ?? 0,
        scale: item.scale?.[0] ?? 1
      });
      viewer.staticRoot.add(instance);
    })
  );
};

const syncRegionObjects = async () => {
  if (!state.session) {
    return;
  }

  const response = await fetch(`/api/regions/${state.session.regionId}/objects`);
  const data = await response.json();
  state.regionObjects = data.objects;

  for (const [objectId, mesh] of viewer.dynamicObjects.entries()) {
    if (!state.regionObjects.some((item) => item.id === objectId)) {
      viewer.dynamicRoot.remove(mesh);
      viewer.dynamicObjects.delete(objectId);
    }
  }

  for (const item of state.regionObjects) {
    const mesh = viewer.dynamicObjects.get(item.id);
    if (!mesh) {
      const instance = await buildRenderableObject(item, true);
      viewer.dynamicRoot.add(instance);
      viewer.dynamicObjects.set(item.id, instance);
    } else {
      mesh.position.set(item.x, item.y, item.z);
      mesh.rotation.y = item.rotationY;
      mesh.scale.setScalar(item.scale);
      mesh.userData.asset = item.asset;
    }
  }

  if (state.selectedObjectId && !state.regionObjects.some((item) => item.id === state.selectedObjectId)) {
    selectObject(null);
  }

  renderBuilderList();
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
  viewer.staticRoot = new THREE.Group();
  viewer.dynamicRoot = new THREE.Group();
  viewer.avatarRoot = new THREE.Group();
  viewer.scene.add(viewer.terrain, viewer.staticRoot, viewer.dynamicRoot, viewer.avatarRoot);

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
    refreshSelectionHelper();
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

const screenToNdc = (event) => {
  const rect = elements.viewport.getBoundingClientRect();
  pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
  pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
};

const pickBuildTarget = (event) => {
  screenToNdc(event);
  raycaster.setFromCamera(pointer, viewer.camera);

  const editableHits = raycaster.intersectObjects([...viewer.dynamicObjects.values()], true);
  const objectHit = editableHits.find((hit) => hit.object.userData.editable);
  if (objectHit) {
    let current = objectHit.object;
    while (current && !current.userData.objectId) {
      current = current.parent;
    }
    return { type: "object", objectId: current?.userData.objectId ?? null };
  }

  const [terrainHit] = raycaster.intersectObject(viewer.terrain);
  if (!terrainHit) {
    return null;
  }

  return { type: "terrain", point: terrainHit.point };
};

const createObject = async (point) => {
  const response = await fetch(`/api/regions/${state.session.regionId}/objects`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      token: state.session.token,
      asset: elements.buildAssetSelect.value,
      x: Number(point.x.toFixed(2)),
      y: Number(getTerrainHeight(point.x, point.z).toFixed(2)),
      z: Number(point.z.toFixed(2)),
      rotationY: 0,
      scale: 1
    })
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error ?? "Unable to place object");
  }

  const data = await response.json();
  await syncRegionObjects();
  selectObject(data.object.id);
  status("Object placed.");
};

const updateSelectedObject = async (updates) => {
  if (!state.selectedObjectId) {
    return;
  }

  const current = state.regionObjects.find((item) => item.id === state.selectedObjectId);
  if (!current) {
    return;
  }

  const next = {
    x: updates.x ?? current.x,
    y: updates.y ?? current.y,
    z: updates.z ?? current.z,
    rotationY: updates.rotationY ?? current.rotationY,
    scale: updates.scale ?? current.scale
  };

  const response = await fetch(`/api/objects/${current.id}`, {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: state.session.token, ...next })
  });

  if (!response.ok) {
    const error = await response.json();
    status(error.error ?? "Unable to update object.", true);
    return;
  }

  await syncRegionObjects();
  selectObject(current.id);
};

const deleteSelectedObject = async () => {
  if (!state.selectedObjectId) {
    return;
  }

  const response = await fetch(`/api/objects/${state.selectedObjectId}`, {
    method: "DELETE",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: state.session.token })
  });

  if (!response.ok) {
    const error = await response.json();
    status(error.error ?? "Unable to delete object.", true);
    return;
  }

  await syncRegionObjects();
  selectObject(null);
  status("Object deleted.");
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
  await syncRegionObjects();

  elements.activeRegion.textContent = state.regions.find((region) => region.id === state.session.regionId)?.name ?? state.session.regionId;
  elements.viewerHint.textContent = `Scene streaming live - ${state.session.regionId}`;
  elements.builderHelp.textContent = "Enable build mode, click terrain to place, click your object to select, arrows move, Q/E rotate, R/F scale, Delete removes.";

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

elements.buildModeButton.addEventListener("click", () => {
  state.buildMode = !state.buildMode;
  elements.buildModeButton.textContent = state.buildMode ? "Disable build mode" : "Enable build mode";
  status(state.buildMode ? "Build mode enabled." : "Build mode disabled.");
});

elements.builderObjectList.addEventListener("click", (event) => {
  const target = event.target;
  if (!(target instanceof HTMLElement)) {
    return;
  }

  const button = target.closest("[data-select-object]");
  if (!(button instanceof HTMLElement)) {
    return;
  }

  selectObject(button.dataset.selectObject ?? null);
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

window.addEventListener("keydown", async (event) => {
  if (event.target === elements.chatInput || event.target === elements.displayName) {
    return;
  }

  if (state.buildMode && state.selectedObjectId) {
    const current = state.regionObjects.find((item) => item.id === state.selectedObjectId);
    if (current) {
      if (event.code === "Delete") {
        await deleteSelectedObject();
        return;
      }

      const moveStep = 0.8;
      const next = { ...current };
      if (event.code === "ArrowUp") next.z -= moveStep;
      if (event.code === "ArrowDown") next.z += moveStep;
      if (event.code === "ArrowLeft") next.x -= moveStep;
      if (event.code === "ArrowRight") next.x += moveStep;
      if (event.code === "PageUp") next.y += 0.4;
      if (event.code === "PageDown") next.y = Math.max(getTerrainHeight(next.x, next.z), next.y - 0.4);
      if (event.code === "KeyQ") next.rotationY -= 0.2;
      if (event.code === "KeyE") next.rotationY += 0.2;
      if (event.code === "KeyR") next.scale = Math.min(3, next.scale + 0.1);
      if (event.code === "KeyF") next.scale = Math.max(0.4, next.scale - 0.1);

      if (next.x !== current.x || next.y !== current.y || next.z !== current.z || next.rotationY !== current.rotationY || next.scale !== current.scale) {
        tempVectorA.set(next.x, next.y, next.z);
        clampToWorld(tempVectorA);
        next.x = Number(tempVectorA.x.toFixed(2));
        next.y = Number(Math.max(tempVectorA.y, next.y).toFixed(2));
        next.z = Number(tempVectorA.z.toFixed(2));
        await updateSelectedObject(next);
        return;
      }
    }
  }

  state.keys.add(event.code);
});

window.addEventListener("keyup", (event) => {
  state.keys.delete(event.code);
});

elements.viewport.addEventListener("pointerdown", () => {
  state.pointerActive = true;
  state.pointerMoved = false;
});

window.addEventListener("pointerup", async (event) => {
  if (!state.pointerActive) {
    return;
  }

  state.pointerActive = false;

  if (!state.pointerMoved || (Math.abs(event.movementX) < 2 && Math.abs(event.movementY) < 2)) {
    if (state.buildMode && state.session) {
      const target = pickBuildTarget(event);
      if (!target) {
        return;
      }

      if (target.type === "object") {
        const ownedObject = state.regionObjects.find((item) => item.id === target.objectId && item.ownerAccountId === state.session.accountId);
        selectObject(ownedObject ? ownedObject.id : null);
        if (!ownedObject) {
          status("You can only edit your own objects.", true);
        }
        return;
      }

      try {
        await createObject(target.point);
      } catch (error) {
        status(error.message, true);
      }
    }
  }
});

window.addEventListener("pointermove", (event) => {
  if (!state.pointerActive) {
    return;
  }

  if (Math.abs(event.movementX) > 1 || Math.abs(event.movementY) > 1) {
    state.pointerMoved = true;
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
renderBuilderList();
loadRegions().catch((error) => status(error.message, true));
