import { describe, it, expect, beforeEach } from "vitest";
import {
  createRegionObject,
  updateRegionObject,
  deleteRegionObject,
  listRegionObjects,
  claimParcel,
  handleGroupObjects,
  handleUngroupObjects,
} from "../world/store.js";
import {
  resetWorldStore,
  createTestSession,
  TEST_REGION_ID,
  PUBLIC_PARCEL_ID,
  PRIVATE_PARCEL_ID,
} from "./helpers.js";

describe("Object CRUD", () => {
  beforeEach(async () => {
    await resetWorldStore();
  });

  it("creates an object inside a public parcel", async () => {
    const { token } = await createTestSession("Builder");

    const { object, permission } = await createRegionObject(token, {
      asset: "cube",
      x: 0,
      y: 0,
      z: 0,
      rotationY: 0,
      scale: 1,
    });

    expect(permission.allowed).toBe(true);
    expect(object).toBeDefined();
    expect(object!.asset).toBe("cube");
    expect(object!.regionId).toBe(TEST_REGION_ID);
  });

  it("updates an object position", async () => {
    const { token } = await createTestSession("Mover");

    const { object } = await createRegionObject(token, {
      asset: "sphere",
      x: 0,
      y: 0,
      z: 0,
      rotationY: 0,
      scale: 1,
    });

    const updated = await updateRegionObject(token, object!.id, {
      x: 5,
      y: 1,
      z: 3,
      rotationY: 90,
      scale: 2,
    });

    expect(updated.permission.allowed).toBe(true);
    expect(updated.object).toBeDefined();
    expect(updated.object!.x).toBe(5);
    expect(updated.object!.y).toBe(1);
    expect(updated.object!.z).toBe(3);
    expect(updated.object!.scale).toBe(2);
  });

  it("deletes an object", async () => {
    const { token, session } = await createTestSession("Deleter");

    const { object } = await createRegionObject(token, {
      asset: "tree",
      x: 0,
      y: 0,
      z: 0,
      rotationY: 0,
      scale: 1,
    });

    const deleted = await deleteRegionObject(token, object!.id);
    expect(deleted).toBe(true);

    const remaining = await listRegionObjects(session.regionId);
    expect(remaining.find((o) => o.id === object!.id)).toBeUndefined();
  });

  it("prevents editing another user's object in a private parcel", async () => {
    // Owner claims the private parcel and builds an object
    const owner = await createTestSession("Owner");
    await claimParcel(owner.token, PRIVATE_PARCEL_ID);

    const { object } = await createRegionObject(owner.token, {
      asset: "house",
      x: 15,
      y: 0,
      z: 0,
      rotationY: 0,
      scale: 1,
    });

    expect(object).toBeDefined();

    // Another user tries to update it -- should fail because they don't own the
    // parcel and are not a collaborator.
    const intruder = await createTestSession("Intruder");

    const result = await updateRegionObject(intruder.token, object!.id, {
      x: 16,
      y: 0,
      z: 0,
      rotationY: 0,
      scale: 1,
    });

    // The permission check should deny because the intruder doesn't own the parcel
    expect(result.permission.allowed).toBe(false);
  });

  it("groups and ungroups objects", async () => {
    const { token } = await createTestSession("Grouper");

    const { object: obj1 } = await createRegionObject(token, {
      asset: "a",
      x: 0,
      y: 0,
      z: 0,
      rotationY: 0,
      scale: 1,
    });
    const { object: obj2 } = await createRegionObject(token, {
      asset: "b",
      x: 1,
      y: 0,
      z: 1,
      rotationY: 0,
      scale: 1,
    });

    const group = await handleGroupObjects(
      token,
      [obj1!.id, obj2!.id],
      "MyGroup",
    );

    expect(group).toBeDefined();
    expect(group!.name).toBe("MyGroup");
    expect(group!.objectIds).toHaveLength(2);

    const ungrouped = handleUngroupObjects(token, group!.id);
    expect(ungrouped).toBe(true);
  });
});
