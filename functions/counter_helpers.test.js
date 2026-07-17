const { after, before, describe, test } = require("node:test");
const assert = require("node:assert/strict");
const { deleteApp, initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const {
  createRecipeCounterReconciler,
  recipeKindFor,
} = require("./counter_helpers");

let app;
let db;
let reconcileRecipeCounters;

before(() => {
  app = initializeApp({ projectId: "demo-kolay-tarifler" }, "counter-tests");
  db = getFirestore(app);
  reconcileRecipeCounters = createRecipeCounterReconciler({ db });
});

after(async () => {
  await deleteApp(app);
});

describe("recipe counter events", () => {
  test("ignores a missing recipe without failing", async () => {
    const result = await reconcileRecipeCounters(
      "missing-counter-recipe",
      ["likeCount"],
    );
    assert.equal(result, null);
  });

  test("reconciles manipulated counters with real child documents", async () => {
    const recipeRef = db.collection("recipes").doc("counter-reconcile");
    await recipeRef.set({ likeCount: 99, commentCount: 77 });
    await recipeRef.collection("likes").doc("user-1").set({ userId: "user-1" });
    await recipeRef.collection("comments").doc("comment-1").set({
      userId: "user-1",
    });

    await reconcileRecipeCounters(recipeRef.id, ["likeCount", "commentCount"]);
    await reconcileRecipeCounters(recipeRef.id, ["likeCount", "commentCount"]);

    const recipe = (await recipeRef.get()).data();
    assert.equal(recipe.likeCount, 1);
    assert.equal(recipe.commentCount, 1);
  });

  test("reconciles counters in the isolated variations collection", async () => {
    const variationRef = db
      .collection("recipe_variations")
      .doc("variation-counter");
    await variationRef.set({ likeCount: 0, commentCount: 0 });
    await variationRef.collection("likes").doc("user-1").set({
      userId: "user-1",
    });

    await reconcileRecipeCounters(
      variationRef.id,
      ["likeCount"],
      "recipe_variations",
    );

    assert.equal((await variationRef.get()).data().likeCount, 1);
  });
});

test("derives recipe kind for legacy client writes", () => {
  assert.equal(recipeKindFor({}), "main");
  assert.equal(recipeKindFor({ parentRecipeId: "main" }), "variation");
  assert.equal(recipeKindFor({ parentRecipeId: "  " }), "main");
});
