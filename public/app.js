import * as THREE from "/vendor/three/build/three.module.js";
import { GLTFLoader } from "/vendor/three/examples/jsm/loaders/GLTFLoader.js";
import { TransformControls } from "/vendor/three/examples/jsm/controls/TransformControls.js";

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
  builderObjectList: document.querySelector("#builderObjectList"),
  bodyColor: document.querySelector("#bodyColor"),
  accentColor: document.querySelector("#accentColor"),
  hairColor: document.querySelector("#hairColor"),
  saveAvatarButton: document.querySelector("#saveAvatarButton"),
  gizmoModeButtons: document.querySelector("#gizmoModeButtons"),
  snapSizeSelect: document.querySelector("#snapSizeSelect"),
  duplicateSelectionButton: document.querySelector("#duplicateSelectionButton"),
  clearSelectionButton: document.querySelector("#clearSelectionButton"),
  presetNameInput: document.querySelector("#presetNameInput"),
  savePresetButton: document.querySelector("#savePresetButton"),
  clearPresetButton: document.querySelector("#clearPresetButton"),
  presetList: document.querySelector("#presetList")
};

const loader = new GLTFLoader();

const state = {
  socket: null,
  session: null,
  account: null,
  regions: [],
  persistence: "memory",
  inventory: [],
  parcels: [],
  avatars: new Map(),
  avatarMeshes: new Map(),
  regionObjects: [],
  buildMode: false,
  selectedObjectId: null,
  selectedObjectIds: [],
  appearance: null,
  gizmoMode: "translate",
  snapSize: 1,
  activeParcelId: null,
  presets: [],
  activePresetId: null,
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
  transformControls: null,
  terrainBounds: 30,
  assetCache: new Map(),
  avatarMixers: new Map(),
  parcelFills: new Map(),
  previewObject: null
};

let viewerBootError = null;

const tempVectorA = new THREE.Vector3();
const tempVectorB = new THREE.Vector3();
const raycaster = new THREE.Raycaster();
const pointer = new THREE.Vector2();

const status = (message, isError = false) => {
  elements.status.textContent = message;
  elements.status.className = isError ? "warning" : "muted";
};

const presetStorageKey = "thirdlife-build-presets";

const loadPresets = () => {
  try {
    return JSON.parse(window.localStorage.getItem(presetStorageKey) ?? "[]");
  } catch {
    return [];
  }
};

const persistPresets = () => {
  window.localStorage.setItem(presetStorageKey, JSON.stringify(state.presets));
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
    .map((item) => {
      const equipable = item.slot && item.appearanceKey;
      const equipped = item.equipped ? "equipped" : "stored";
      return `
        <div class="card compact-card">
          <strong>${item.name}</strong>
          <div>${item.kind} - ${item.rarity} - ${equipped}</div>
          ${equipable ? `<button data-equip-item="${item.id}" style="margin-top:10px;">Equip ${item.slot}</button>` : ""}
        </div>
      `;
    })
    .join("");
};

const getAppearanceFormValue = () => ({
  bodyColor: elements.bodyColor.value,
  accentColor: elements.accentColor.value,
  headColor: "#f2c7a8",
  hairColor: elements.hairColor.value,
  outfit: state.appearance?.outfit ?? "voyager",
  accessory: state.appearance?.accessory ?? "none"
});

const renderAppearanceControls = (appearance) => {
  if (!appearance) {
    return;
  }

  elements.bodyColor.value = appearance.bodyColor;
  elements.accentColor.value = appearance.accentColor;
  elements.hairColor.value = appearance.hairColor;
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
      const canRelease = state.session && parcel.ownerAccountId === state.session.accountId;

      return `
        <div class="card compact-card">
          <strong>${parcel.name}</strong>
          <div>${parcel.tier} parcel - ${owner}</div>
          ${canClaim ? `<button data-claim-parcel="${parcel.id}" style="margin-top:10px;">Claim parcel</button>` : ""}
          ${canRelease ? `<button data-release-parcel="${parcel.id}" style="margin-top:10px;">Release parcel</button>` : ""}
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
      const activeClass = state.selectedObjectIds.includes(item.id) ? " active" : "";
      return `
        <button class="card compact-card${activeClass}" data-select-object="${item.id}">
          <strong>${assetName}</strong>
          <div>x ${item.x.toFixed(1)} / z ${item.z.toFixed(1)}</div>
        </button>
      `;
    })
    .join("");
};

const renderPresets = () => {
  if (!state.presets.length) {
    elements.presetList.textContent = "No presets saved yet.";
    return;
  }

  elements.presetList.innerHTML = state.presets.map((preset) => {
    const activeClass = preset.id === state.activePresetId ? " active" : "";
    return `
      <div class="card compact-card${activeClass}">
        <strong>${preset.name}</strong>
        <div>${preset.items.length} objects</div>
        <div class="chat-row" style="margin-top:10px;">
          <button data-activate-preset="${preset.id}">Activate</button>
          <button data-delete-preset="${preset.id}">Delete</button>
        </div>
      </div>
    `;
  }).join("");
};

const loadParcels = async (regionId) => {
  const response = await fetch(`/api/regions/${regionId}/parcels`);
  const data = await response.json();
  state.parcels = data.parcels;
  renderParcels();
};

const getParcelAt = (x, z) => state.parcels.find((parcel) => x >= parcel.minX && x <= parcel.maxX && z >= parcel.minZ && z <= parcel.maxZ) ?? null;

const snapValue = (value) => {
  if (!state.snapSize) {
    return value;
  }

  return Math.round(value / state.snapSize) * state.snapSize;
};

const snapPoint = (point) => {
  const x = snapValue(point.x);
  const z = snapValue(point.z);
  return new THREE.Vector3(x, getTerrainHeight(x, z), z);
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
      const fill = viewer.parcelFills.get(parcelId);
      if (fill) {
        viewer.scene.remove(fill);
        viewer.parcelFills.delete(parcelId);
      }
    }
  }

  for (const parcel of state.parcels) {
    let line = viewer.parcelLines.get(parcel.id);
    let fill = viewer.parcelFills.get(parcel.id);

    if (!line) {
      const geometry = new THREE.BufferGeometry().setFromPoints(Array.from({ length: 5 }, () => new THREE.Vector3()));
      const material = new THREE.LineBasicMaterial({ color: parcel.ownerAccountId ? 0xffb36a : 0x66ffd1 });
      line = new THREE.Line(geometry, material);
      viewer.scene.add(line);
      viewer.parcelLines.set(parcel.id, line);
    }

    if (!fill) {
      fill = new THREE.Mesh(
        new THREE.PlaneGeometry(parcel.maxX - parcel.minX, parcel.maxZ - parcel.minZ),
        new THREE.MeshBasicMaterial({ color: 0x66ffd1, transparent: true, opacity: 0.04, side: THREE.DoubleSide })
      );
      fill.rotation.x = -Math.PI / 2;
      viewer.scene.add(fill);
      viewer.parcelFills.set(parcel.id, fill);
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
    const active = parcel.id === state.activeParcelId;
    line.material.color.setHex(active ? 0xfff18a : parcel.ownerAccountId ? 0xffb36a : 0x66ffd1);
    line.material.linewidth = active ? 2 : 1;

    fill.position.set((parcel.minX + parcel.maxX) / 2, getTerrainHeight((parcel.minX + parcel.maxX) / 2, (parcel.minZ + parcel.maxZ) / 2) + 0.03, (parcel.minZ + parcel.maxZ) / 2);
    fill.material.color.setHex(active ? 0xfff18a : parcel.ownerAccountId ? 0xffb36a : 0x66ffd1);
    fill.material.opacity = active ? 0.16 : 0.05;
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
    viewer.assetCache.set(url, loader.loadAsync(url));
  }

  const gltf = await viewer.assetCache.get(url);
  const scene = gltf.scene.clone(true);
  scene.animations = gltf.animations;
  return scene;
};

const createLanternGlow = () => {
  const light = new THREE.PointLight(0x8cecff, 4, 7, 2);
  light.position.y = 2.3;
  return light;
};

const addOutfitMesh = (root, appearance) => {
  const material = new THREE.MeshStandardMaterial({ color: appearance.accentColor, roughness: 0.55, metalness: 0.16 });

  if (appearance.outfit === "voyager") {
    const coat = new THREE.Mesh(new THREE.CylinderGeometry(0.58, 0.72, 1.6, 8, 1, true), material);
    coat.position.y = 2.05;
    coat.userData.generatedWearable = true;
    root.add(coat);
  }

  if (appearance.outfit === "pilot") {
    const jacket = new THREE.Mesh(new THREE.BoxGeometry(1.15, 1.45, 0.72), material);
    jacket.position.y = 2.1;
    jacket.userData.generatedWearable = true;
    root.add(jacket);
  }

  if (appearance.outfit === "formal") {
    const sash = new THREE.Mesh(new THREE.TorusGeometry(0.42, 0.12, 8, 20), material);
    sash.rotation.x = Math.PI / 2;
    sash.position.set(0, 2.2, 0.1);
    sash.userData.generatedWearable = true;
    root.add(sash);
  }
};

const addAccessoryMesh = (root, appearance) => {
  const material = new THREE.MeshStandardMaterial({ color: appearance.hairColor, roughness: 0.62, metalness: 0.08 });

  if (appearance.accessory === "visor") {
    const visor = new THREE.Mesh(new THREE.TorusGeometry(0.38, 0.05, 8, 24), material);
    visor.rotation.x = Math.PI / 2;
    visor.position.set(0, 3.38, 0.22);
    visor.userData.generatedWearable = true;
    root.add(visor);
  }

  if (appearance.accessory === "cape") {
    const cape = new THREE.Mesh(new THREE.BoxGeometry(0.95, 1.4, 0.08), material);
    cape.position.set(0, 1.95, -0.36);
    cape.userData.generatedWearable = true;
    root.add(cape);
  }

  if (appearance.accessory === "pack") {
    const pack = new THREE.Mesh(new THREE.BoxGeometry(0.62, 0.82, 0.32), material);
    pack.position.set(0, 2.02, -0.42);
    pack.userData.generatedWearable = true;
    root.add(pack);
  }
};

const applyAppearanceToAvatar = (object, appearance) => {
  if (!appearance) {
    return;
  }

  object.userData.appearance = appearance;
  object.children
    .filter((child) => child.userData.generatedWearable)
    .forEach((child) => object.remove(child));
  object.traverse((child) => {
    if (!child.isMesh || !child.material?.color) {
      return;
    }

    if (child.name.includes("Torso")) {
      child.material = child.material.clone();
      child.material.color.set(appearance.bodyColor);
    }

    if (child.name.includes("LeftArm") || child.name.includes("RightArm") || child.name.includes("LeftLeg") || child.name.includes("RightLeg")) {
      child.material = child.material.clone();
      child.material.color.set(appearance.accentColor);
    }

    if (child.name.includes("Head")) {
      child.material = child.material.clone();
      child.material.color.set(appearance.headColor);
    }
  });

  addOutfitMesh(object, appearance);
  addAccessoryMesh(object, appearance);
};

const createAvatarEntity = async (avatarId, displayName, isSelf) => {
  try {
    const object = await loadGltfAsset("/assets/models/avatar-runner.gltf");
    object.userData.avatarId = avatarId;
    object.userData.isAvatar = true;
    object.userData.parts = {};
    object.userData.targetPosition = new THREE.Vector3();
    object.userData.displayName = displayName;
    object.userData.appearance = null;

    object.traverse((child) => {
      if (child.isMesh) {
        child.castShadow = true;
        child.receiveShadow = true;
      }
    });

    object.add(makeLabelSprite(displayName));

    const avatarScene = object.getObjectByName("AvatarRoot") ?? object;
    const mixer = new THREE.AnimationMixer(avatarScene);
    const actions = {};

    if (object.animations && object.animations.length) {
      for (const clip of object.animations) {
        actions[clip.name] = mixer.clipAction(clip);
      }
      actions.Idle?.play();
    }

    viewer.avatarMixers.set(avatarId, { mixer, actions, active: "Idle" });
    return object;
  } catch {
    return createHumanoid(avatarId, displayName, isSelf);
  }
};

const buildRenderableObject = async (item, editable = false) => {
  const object = await loadGltfAsset(item.asset);
  object.animations = object.animations ?? [];
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

const ensurePreviewObject = async () => {
  const asset = elements.buildAssetSelect.value;

  if (viewer.previewObject?.userData.asset === asset) {
    return viewer.previewObject;
  }

  if (viewer.previewObject) {
    viewer.scene.remove(viewer.previewObject);
    viewer.previewObject = null;
  }

  const preview = await buildRenderableObject({
    id: "preview",
    asset,
    x: 0,
    y: 0,
    z: 0,
    rotationY: 0,
    scale: 1
  });
  preview.userData.asset = asset;
  preview.traverse((child) => {
    if (child.isMesh && child.material) {
      child.material = child.material.clone();
      child.material.transparent = true;
      child.material.opacity = 0.45;
    }
  });
  viewer.previewObject = preview;
  viewer.scene.add(preview);
  return preview;
};

const hidePreviewObject = () => {
  if (viewer.previewObject) {
    viewer.previewObject.visible = false;
  }
  state.activeParcelId = null;
  syncParcelLines();
};

const updatePreviewObject = async (event) => {
  if (!state.buildMode || !state.session) {
    hidePreviewObject();
    return;
  }

  const target = pickBuildTarget(event);
  if (!target || target.type !== "terrain") {
    hidePreviewObject();
    return;
  }

  const snapped = snapPoint(target.point);
  const preview = await ensurePreviewObject();
  preview.visible = true;
  preview.position.copy(snapped);
  state.activeParcelId = getParcelAt(snapped.x, snapped.z)?.id ?? null;
  syncParcelLines();
};

const selectObject = (objectId, additive = false) => {
  if (!objectId) {
    state.selectedObjectId = null;
    state.selectedObjectIds = [];
  } else if (additive) {
    if (state.selectedObjectIds.includes(objectId)) {
      state.selectedObjectIds = state.selectedObjectIds.filter((id) => id !== objectId);
    } else {
      state.selectedObjectIds = [...state.selectedObjectIds, objectId];
    }
    state.selectedObjectId = state.selectedObjectIds[0] ?? null;
  } else {
    state.selectedObjectId = objectId;
    state.selectedObjectIds = [objectId];
  }

  if (viewer.selectionHelper) {
    viewer.scene.remove(viewer.selectionHelper);
    viewer.selectionHelper = null;
  }

  if (objectId && viewer.dynamicObjects.has(objectId)) {
    viewer.selectionHelper = new THREE.BoxHelper(viewer.dynamicObjects.get(objectId), 0xffb36a);
    viewer.scene.add(viewer.selectionHelper);
  }

  syncTransformSelection();

  renderBuilderList();
};

const refreshSelectionHelper = () => {
  if (viewer.selectionHelper) {
    viewer.selectionHelper.update();
  }
};

const syncTransformSelection = () => {
  if (!viewer.transformControls) {
    return;
  }

  viewer.transformControls.setTranslationSnap(state.snapSize || null);
  viewer.transformControls.setRotationSnap(state.snapSize ? Math.PI / 8 : null);
  viewer.transformControls.setScaleSnap(state.snapSize ? Math.max(0.1, state.snapSize / 2) : null);

  if (state.selectedObjectId && viewer.dynamicObjects.has(state.selectedObjectId)) {
    const selected = viewer.dynamicObjects.get(state.selectedObjectId);
    viewer.transformControls.attach(selected);
    viewer.transformControls.setMode(state.gizmoMode);
    state.activeParcelId = getParcelAt(selected.position.x, selected.position.z)?.id ?? null;
  } else {
    viewer.transformControls.detach();
    if (!state.buildMode) {
      state.activeParcelId = null;
    }
  }

  syncParcelLines();
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

const applyRegionObjects = async () => {
  
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

  state.selectedObjectIds = state.selectedObjectIds.filter((id) => state.regionObjects.some((item) => item.id === id));
  if (!state.selectedObjectIds.length) {
    state.selectedObjectId = null;
  }

  syncTransformSelection();
  renderBuilderList();
};

const syncRegionObjects = async () => {
  if (!state.session) {
    return;
  }

  const response = await fetch(`/api/regions/${state.session.regionId}/objects`);
  const data = await response.json();
  state.regionObjects = data.objects;
  await applyRegionObjects();
};

const ensureViewer = () => {
  if (viewer.renderer) {
    return;
  }

  if (viewerBootError) {
    throw viewerBootError;
  }

  try {
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

    viewer.transformControls = new TransformControls(viewer.camera, viewer.renderer.domElement);
    viewer.transformControls.setMode(state.gizmoMode);
    viewer.transformControls.setTranslationSnap(state.snapSize || null);
    viewer.transformControls.setRotationSnap(state.snapSize ? Math.PI / 8 : null);
    viewer.transformControls.setScaleSnap(state.snapSize ? Math.max(0.1, state.snapSize / 2) : null);
    viewer.transformControls.addEventListener("dragging-changed", (event) => {
      state.pointerActive = event.value;
    });
    viewer.transformControls.addEventListener("objectChange", () => {
      if (viewer.transformControls.object) {
        state.activeParcelId = getParcelAt(viewer.transformControls.object.position.x, viewer.transformControls.object.position.z)?.id ?? null;
        syncParcelLines();
      }
      refreshSelectionHelper();
    });
    viewer.transformControls.addEventListener("mouseUp", async () => {
      if (!state.selectedObjectId || !viewer.dynamicObjects.has(state.selectedObjectId)) {
        return;
      }

      const object = viewer.dynamicObjects.get(state.selectedObjectId);
      await updateSelectedObject({
        x: Number(object.position.x.toFixed(2)),
        y: Number(object.position.y.toFixed(2)),
        z: Number(object.position.z.toFixed(2)),
        rotationY: Number(object.rotation.y.toFixed(2)),
        scale: Number(object.scale.x.toFixed(2))
      });
    });
    viewer.scene.add(viewer.transformControls);

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
  } catch (error) {
    viewerBootError = error;
    throw error;
  }
};

const syncAvatarMeshes = async () => {
  ensureViewer();

  for (const [avatarId, mesh] of state.avatarMeshes.entries()) {
    if (!state.avatars.has(avatarId)) {
      viewer.avatarRoot.remove(mesh);
      state.avatarMeshes.delete(avatarId);
      viewer.avatarMixers.delete(avatarId);
    }
  }

  for (const [avatarId, avatar] of state.avatars.entries()) {
    let mesh = state.avatarMeshes.get(avatarId);
    if (!mesh) {
      mesh = await createAvatarEntity(avatarId, avatar.displayName, state.session && avatarId === state.session.avatarId);
      viewer.avatarRoot.add(mesh);
      state.avatarMeshes.set(avatarId, mesh);
    }

    if (JSON.stringify(mesh.userData.appearance) !== JSON.stringify(avatar.appearance)) {
      applyAppearanceToAvatar(mesh, avatar.appearance);
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
  const deltaTime = state.clock.getDelta();

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
    if (mesh.userData.parts?.leftLeg) {
      mesh.userData.parts.leftLeg.rotation.x = swing;
      mesh.userData.parts.rightLeg.rotation.x = -swing;
      mesh.userData.parts.leftArm.rotation.x = -swing * 0.7;
      mesh.userData.parts.rightArm.rotation.x = swing * 0.7;
    }

    const controller = viewer.avatarMixers.get(avatarId);
    if (controller) {
      controller.mixer.update(deltaTime);
      const nextAction = stride > 0.08 ? "Walk" : "Idle";
      if (controller.active !== nextAction && controller.actions[nextAction]) {
        controller.actions[controller.active]?.fadeOut(0.18);
        controller.actions[nextAction].reset().fadeIn(0.18).play();
        controller.active = nextAction;
      }
    }
  }
};

const updateLocalMovement = () => {
  const selfAvatar = getSelfAvatar();
  if (!selfAvatar || !state.socket || state.socket.readyState !== WebSocket.OPEN) {
    return;
  }

  const delta = Math.min(0.05, 1 / 60);
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
  const snapped = snapPoint(point);
  const response = await fetch(`/api/regions/${state.session.regionId}/objects`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      token: state.session.token,
      asset: elements.buildAssetSelect.value,
      x: Number(snapped.x.toFixed(2)),
      y: Number(snapped.y.toFixed(2)),
      z: Number(snapped.z.toFixed(2)),
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

const duplicateSelection = async () => {
  if (!state.selectedObjectIds.length || !state.session) {
    return;
  }

  const selected = state.regionObjects.filter((item) => state.selectedObjectIds.includes(item.id));
  const createdIds = [];

  for (const item of selected) {
    const response = await fetch(`/api/regions/${state.session.regionId}/objects`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: state.session.token,
        asset: item.asset,
        x: Number((item.x + (state.snapSize || 1)).toFixed(2)),
        y: item.y,
        z: Number((item.z + (state.snapSize || 1)).toFixed(2)),
        rotationY: item.rotationY,
        scale: item.scale
      })
    });

    if (response.ok) {
      const data = await response.json();
      createdIds.push(data.object.id);
    }
  }

  await syncRegionObjects();
  if (createdIds.length) {
    state.selectedObjectIds = createdIds;
    state.selectedObjectId = createdIds[0];
    syncTransformSelection();
    renderBuilderList();
    status(`Duplicated ${createdIds.length} object${createdIds.length === 1 ? "" : "s"}.`);
  }
};

const savePresetFromSelection = () => {
  const name = elements.presetNameInput.value.trim();
  if (!name || !state.selectedObjectIds.length) {
    status("Select objects and enter a preset name.", true);
    return;
  }

  const selected = state.regionObjects.filter((item) => state.selectedObjectIds.includes(item.id));
  const anchor = selected[0];
  const preset = {
    id: crypto.randomUUID(),
    name,
    items: selected.map((item) => ({
      asset: item.asset,
      dx: Number((item.x - anchor.x).toFixed(2)),
      dy: Number((item.y - anchor.y).toFixed(2)),
      dz: Number((item.z - anchor.z).toFixed(2)),
      rotationY: item.rotationY,
      scale: item.scale
    }))
  };

  state.presets = [...state.presets, preset];
  state.activePresetId = preset.id;
  persistPresets();
  renderPresets();
  status(`Saved preset ${name}.`);
};

const placeActivePreset = async (point) => {
  const preset = state.presets.find((entry) => entry.id === state.activePresetId);
  if (!preset || !state.session) {
    return false;
  }

  const anchor = snapPoint(point);
  const createdIds = [];

  for (const item of preset.items) {
    const response = await fetch(`/api/regions/${state.session.regionId}/objects`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token: state.session.token,
        asset: item.asset,
        x: Number((anchor.x + item.dx).toFixed(2)),
        y: Number((anchor.y + item.dy).toFixed(2)),
        z: Number((anchor.z + item.dz).toFixed(2)),
        rotationY: item.rotationY,
        scale: item.scale
      })
    });

    if (response.ok) {
      const data = await response.json();
      createdIds.push(data.object.id);
    }
  }

  await syncRegionObjects();
  state.selectedObjectIds = createdIds;
  state.selectedObjectId = createdIds[0] ?? null;
  syncTransformSelection();
  renderBuilderList();
  status(`Placed preset ${preset.name}.`);
  return true;
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
  try {
    ensureViewer();
  } catch (error) {
    status(`3D viewer failed to start: ${error.message}`, true);
    throw error;
  }

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
  state.appearance = data.appearance;
  state.persistence = data.persistence;
  state.inventory = data.inventory;
  state.parcels = data.parcels;
  state.avatars = new Map([[data.avatar.avatarId, data.avatar]]);
  renderInventory(state.inventory);
  renderAppearanceControls(data.appearance);
  renderParcels();
  await syncAvatarMeshes();
  await loadRegionScene(state.session.regionId);
  await syncRegionObjects();

  elements.activeRegion.textContent = state.regions.find((region) => region.id === state.session.regionId)?.name ?? state.session.regionId;
  elements.viewerHint.textContent = `Scene streaming live - ${state.session.regionId}`;
  elements.builderHelp.textContent = "Enable build mode, click terrain to place, click your object to select, use gizmo buttons for drag editing, arrows still nudge, Q/E rotate, R/F scale, Delete removes.";

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
      state.regionObjects = message.objects;
      void applyRegionObjects();
    }
    if (message.type === "avatar:joined" || message.type === "avatar:moved") {
      state.avatars.set(message.avatar.avatarId, message.avatar);
    }
    if (message.type === "avatar:updated") {
      state.avatars.set(message.avatar.avatarId, message.avatar);
      if (message.avatar.avatarId === state.session?.avatarId) {
        state.appearance = message.avatar.appearance;
        renderAppearanceControls(state.appearance);
      }
    }
    if (message.type === "avatar:left") {
      state.avatars.delete(message.avatarId);
    }
    if (message.type === "chat") {
      appendChat(`${message.displayName}: ${message.message}`);
    }

    if (message.type === "object:created") {
      state.regionObjects = [...state.regionObjects.filter((item) => item.id !== message.object.id), message.object];
      void applyRegionObjects();
    }

    if (message.type === "object:updated") {
      state.regionObjects = state.regionObjects.map((item) => item.id === message.object.id ? message.object : item);
      void applyRegionObjects();
    }

    if (message.type === "object:deleted") {
      state.regionObjects = state.regionObjects.filter((item) => item.id !== message.objectId);
      void applyRegionObjects();
    }

    if (message.type === "parcel:updated") {
      state.parcels = state.parcels.some((item) => item.id === message.parcel.id)
        ? state.parcels.map((item) => item.id === message.parcel.id ? message.parcel : item)
        : [...state.parcels, message.parcel];
      renderParcels();
    }

    void syncAvatarMeshes();
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
  if (!state.buildMode) {
    hidePreviewObject();
  }
  syncTransformSelection();
  status(state.buildMode ? "Build mode enabled." : "Build mode disabled.");
});

elements.saveAvatarButton.addEventListener("click", async () => {
  if (!state.session) {
    return;
  }

  const response = await fetch("/api/avatar/appearance", {
    method: "PATCH",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: state.session.token, ...getAppearanceFormValue() })
  });

  if (!response.ok) {
    const error = await response.json();
    status(error.error ?? "Unable to save avatar style.", true);
    return;
  }

  const data = await response.json();
  state.appearance = data.avatar.appearance;
  state.avatars.set(data.avatar.avatarId, data.avatar);
  await syncAvatarMeshes();
  status("Avatar style updated.");
});

elements.gizmoModeButtons.addEventListener("click", (event) => {
  const target = event.target;
  if (!(target instanceof HTMLElement)) {
    return;
  }

  const modeButton = target.closest("[data-gizmo-mode]");
  if (!(modeButton instanceof HTMLElement)) {
    return;
  }

  state.gizmoMode = modeButton.dataset.gizmoMode;
  syncTransformSelection();
});

elements.snapSizeSelect.addEventListener("change", () => {
  state.snapSize = Number(elements.snapSizeSelect.value);
  syncTransformSelection();
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

  selectObject(button.dataset.selectObject ?? null, event.shiftKey);
});

elements.duplicateSelectionButton.addEventListener("click", () => {
  void duplicateSelection();
});

elements.clearSelectionButton.addEventListener("click", () => {
  selectObject(null);
});

elements.savePresetButton.addEventListener("click", savePresetFromSelection);

elements.clearPresetButton.addEventListener("click", () => {
  state.activePresetId = null;
  renderPresets();
  status("Preset placement cleared.");
});

elements.presetList.addEventListener("click", (event) => {
  const target = event.target;
  if (!(target instanceof HTMLElement)) {
    return;
  }

  const activateButton = target.closest("[data-activate-preset]");
  if (activateButton instanceof HTMLElement) {
    state.activePresetId = activateButton.dataset.activatePreset;
    renderPresets();
    status("Preset activated for placement.");
    return;
  }

  const deleteButton = target.closest("[data-delete-preset]");
  if (deleteButton instanceof HTMLElement) {
    state.presets = state.presets.filter((preset) => preset.id !== deleteButton.dataset.deletePreset);
    if (state.activePresetId === deleteButton.dataset.deletePreset) {
      state.activePresetId = null;
    }
    persistPresets();
    renderPresets();
    status("Preset deleted.");
  }
});

elements.parcelList.addEventListener("click", async (event) => {
  const target = event.target;
  if (!(target instanceof HTMLElement)) {
    return;
  }

  const parcelId = target.dataset.claimParcel;
  const releaseParcelId = target.dataset.releaseParcel;
  const selectedParcelId = parcelId || releaseParcelId;

  if (!selectedParcelId || !state.session) {
    return;
  }

  const response = await fetch(parcelId ? "/api/parcels/claim" : "/api/parcels/release", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: state.session.token, parcelId: selectedParcelId })
  });

  if (!response.ok) {
    const error = await response.json();
    status(error.error ?? `Unable to ${parcelId ? "claim" : "release"} parcel.`, true);
    return;
  }

  await loadParcels(state.session.regionId);
  status(parcelId ? "Parcel claimed." : "Parcel released.");
});

elements.inventoryList.addEventListener("click", async (event) => {
  const target = event.target;
  if (!(target instanceof HTMLElement)) {
    return;
  }

  const itemId = target.dataset.equipItem;
  if (!itemId || !state.session) {
    return;
  }

  const response = await fetch("/api/inventory/equip", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token: state.session.token, itemId })
  });

  if (!response.ok) {
    const error = await response.json();
    status(error.error ?? "Unable to equip item.", true);
    return;
  }

  const data = await response.json();
  state.inventory = data.inventory;
  renderInventory(state.inventory);
  if (data.avatar) {
    state.appearance = data.avatar.appearance;
    state.avatars.set(data.avatar.avatarId, data.avatar);
    await syncAvatarMeshes();
  }
  status("Wearable equipped.");
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
        next.x = Number(snapValue(tempVectorA.x).toFixed(2));
        next.y = Number(Math.max(tempVectorA.y, next.y).toFixed(2));
        next.z = Number(snapValue(tempVectorA.z).toFixed(2));
        await updateSelectedObject(next);
        return;
      }
    }
  }

  if (state.buildMode && (event.ctrlKey || event.metaKey) && event.code === "KeyD") {
    event.preventDefault();
    await duplicateSelection();
    return;
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
        selectObject(ownedObject ? ownedObject.id : null, event.shiftKey);
        if (!ownedObject) {
          status("You can only edit your own objects.", true);
        }
        return;
      }

      try {
        if (state.activePresetId) {
          const placed = await placeActivePreset(target.point);
          if (placed) {
            return;
          }
        }
        await createObject(target.point);
      } catch (error) {
        status(error.message, true);
      }
    }
  }
});

window.addEventListener("pointermove", (event) => {
  void updatePreviewObject(event);

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

state.presets = loadPresets();
renderBuilderList();
renderPresets();
loadRegions().catch((error) => status(error.message, true));
