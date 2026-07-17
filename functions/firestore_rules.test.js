const fs = require("node:fs");
const path = require("node:path");
const { after, before, beforeEach, describe, test } = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collectionGroup,
  doc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} = require("firebase/firestore");

const projectId = "demo-kolay-tarifler";
const acceptedTermsVersion = "2026-07-13";
let testEnv;

function userDb(uid, email = `${uid}@example.com`) {
  return testEnv.authenticatedContext(uid, { email }).firestore();
}

function anonymousDb(uid = "anonymous-user") {
  return testEnv
    .authenticatedContext(uid, {
      firebase: { sign_in_provider: "anonymous" },
    })
    .firestore();
}

async function seed(data) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [documentPath, value] of Object.entries(data)) {
      await setDoc(doc(db, documentPath), value);
    }
  });
}

function variation({ authorId, parentRecipeId, includeKind = true }) {
  const data = {
    name: "Topluluk varyasyonu",
    description: "Açıklama",
    cuisine: "Türk",
    type: "Topluluk",
    duration: "30 dk",
    servings: "4 kişilik",
    emoji: "🍲",
    imageUrls: [],
    imageSources: [],
    ingredients: [],
    steps: [],
    tags: [],
    officialLikeCount: 0,
    communityLikeCount: 0,
    authorId,
    authorName: "Kullanıcı",
    isOfficial: false,
    parentRecipeId,
    likeCount: 0,
    commentCount: 0,
    createdAt: new Date("2026-07-17T10:00:00Z"),
  };
  if (includeKind) data.recipeKind = "variation";
  return data;
}

function pendingRecipe(authorId) {
  return {
    name: "Yeni ana tarif",
    description: "Açıklama",
    cuisine: "Türk",
    type: "Ana Yemek",
    duration: "30 dk",
    emoji: "🍲",
    imageUrls: [],
    ingredients: [{ ingredientId: "mercimek", name: "Mercimek", amount: "1 su bardağı" }],
    steps: [{ order: 1, text: "Pişir" }],
    tags: [],
    authorId,
    authorName: "Kullanıcı",
    status: "pending",
    rejectionComment: null,
    createdAt: new Date("2026-07-17T10:00:00Z"),
    reviewedAt: null,
  };
}

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
        path.resolve(__dirname, "../firestore.rules"),
        "utf8",
      ),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

describe("recipe hierarchy rules", () => {
  test("allows an accepted user to create a first-level variation", async () => {
    await seed({
      "recipes/main": {
        authorId: "official",
        isOfficial: true,
        recipeKind: "main",
      },
      "users/owner": { communityTermsVersion: acceptedTermsVersion },
    });

    await assertSucceeds(
      setDoc(
        doc(userDb("owner"), "recipe_variations/variation"),
        variation({ authorId: "owner", parentRecipeId: "main" }),
      ),
    );
    await assertFails(
      setDoc(
        doc(userDb("owner"), "recipe_variations/missing-kind"),
        variation({
          authorId: "owner",
          parentRecipeId: "main",
          includeKind: false,
        }),
      ),
    );
  });

  test("never allows a variation into the main recipes collection", async () => {
    await seed({
      "recipes/main": {
        authorId: "official",
        isOfficial: true,
        recipeKind: "main",
      },
      "users/owner": { communityTermsVersion: acceptedTermsVersion },
    });

    await assertFails(
      setDoc(
        doc(userDb("owner"), "recipes/legacy-visible-variation"),
        variation({ authorId: "owner", parentRecipeId: "main" }),
      ),
    );
  });

  test("denies a direct main-recipe create and a missing parent", async () => {
    await seed({
      "users/owner": { communityTermsVersion: acceptedTermsVersion },
    });
    const db = userDb("owner");

    await assertFails(
      setDoc(doc(db, "recipes/direct-main"), {
        name: "Yetkisiz ana tarif",
        authorId: "owner",
        isOfficial: false,
      }),
    );
    await assertFails(
      setDoc(
        doc(db, "recipe_variations/orphan"),
        variation({ authorId: "owner", parentRecipeId: "missing" }),
      ),
    );
  });

  test("denies a variation below another variation", async () => {
    await seed({
      "recipes/main": {
        authorId: "official",
        isOfficial: true,
        recipeKind: "main",
      },
      "recipe_variations/first-level": {
        authorId: "someone",
        isOfficial: false,
        recipeKind: "variation",
        parentRecipeId: "main",
      },
      "users/owner": { communityTermsVersion: acceptedTermsVersion },
    });

    await assertFails(
      setDoc(
        doc(userDb("owner"), "recipe_variations/nested"),
        variation({ authorId: "owner", parentRecipeId: "first-level" }),
      ),
    );
  });

  test("prevents an author from changing hierarchy fields", async () => {
    await seed({
      "recipe_variations/variation": variation({
        authorId: "owner",
        parentRecipeId: "main",
      }),
    });

    await assertFails(
      setDoc(
        doc(userDb("owner"), "recipe_variations/variation"),
        variation({ authorId: "owner", parentRecipeId: "other-main" }),
      ),
    );
  });

  test("prevents an author from changing recipe counters", async () => {
    await seed({
      "recipes/user-main": {
        authorId: "owner",
        isOfficial: false,
        recipeKind: "main",
        likeCount: 0,
        commentCount: 0,
      },
    });

    await assertFails(
      updateDoc(doc(userDb("owner"), "recipes/user-main"), {
        likeCount: 999,
      }),
    );
    await assertFails(
      updateDoc(doc(userDb("owner"), "recipes/user-main"), {
        commentCount: 1,
      }),
    );
    await assertFails(
      updateDoc(doc(userDb("owner"), "recipes/user-main"), {
        name: "Moderasyon sonrası değiştirildi",
      }),
    );
    await assertSucceeds(
      (() => {
        const db = userDb("owner");
        const batch = writeBatch(db);
        batch.set(doc(db, "recipes/user-main/likes/owner"), {
          userId: "owner",
          createdAt: new Date("2026-07-17T10:00:00Z"),
        });
        batch.update(doc(db, "recipes/user-main"), { likeCount: 1 });
        return batch.commit();
      })(),
    );
  });

  test("rejects inflated initial variation counters", async () => {
    await seed({
      "recipes/main": {
        authorId: "official",
        isOfficial: true,
        recipeKind: "main",
      },
      "users/owner": { communityTermsVersion: acceptedTermsVersion },
    });
    const payload = variation({ authorId: "owner", parentRecipeId: "main" });
    payload.likeCount = 999;

    await assertFails(
      setDoc(doc(userDb("owner"), "recipe_variations/inflated"), payload),
    );
  });

  test("denies community writes from anonymous identities", async () => {
    await seed({
      "recipes/main": {
        authorId: "official",
        isOfficial: true,
        recipeKind: "main",
      },
      "users/anonymous-user": {
        communityTermsVersion: acceptedTermsVersion,
      },
    });
    const db = anonymousDb();

    await assertFails(
      setDoc(
        doc(db, "recipe_variations/anonymous-variation"),
        variation({
          authorId: "anonymous-user",
          parentRecipeId: "main",
        }),
      ),
    );
    await assertFails(
      setDoc(doc(db, "recipes/main/likes/anonymous-user"), {
        userId: "anonymous-user",
        createdAt: new Date("2026-07-17T10:00:00Z"),
      }),
    );
  });
});

describe("pending recipe rules", () => {
  test("accepts only a complete pending submission owned by the user", async () => {
    await seed({
      "users/owner": { communityTermsVersion: acceptedTermsVersion },
    });
    const db = userDb("owner");

    await assertSucceeds(
      setDoc(doc(db, "pending_recipes/valid"), pendingRecipe("owner")),
    );

    const approved = pendingRecipe("owner");
    approved.status = "approved";
    await assertFails(setDoc(doc(db, "pending_recipes/approved"), approved));

    const malformed = pendingRecipe("owner");
    malformed.ingredients = "not-a-list";
    await assertFails(setDoc(doc(db, "pending_recipes/malformed"), malformed));

    await assertFails(
      setDoc(doc(db, "pending_recipes/forged"), pendingRecipe("victim")),
    );
  });
});

describe("comment and activity rules", () => {
  const recipePath = "recipes/main";
  const commentPath = `${recipePath}/comments/comment-1`;

  async function seedComment() {
    await seed({
      [recipePath]: {
        authorId: "official",
        isOfficial: true,
        recipeKind: "main",
        likeCount: 0,
        commentCount: 1,
      },
      [commentPath]: {
        recipeId: "main",
        userId: "owner",
        text: "Yorum",
      },
    });
  }

  test("lets an owner delete their comment", async () => {
    await seedComment();
    const db = userDb("owner");
    const batch = writeBatch(db);
    batch.delete(doc(db, commentPath));

    await assertSucceeds(batch.commit());
  });

  test("denies another user from deleting the comment", async () => {
    await seedComment();
    const db = userDb("other");
    const batch = writeBatch(db);
    batch.delete(doc(db, commentPath));

    await assertFails(batch.commit());
  });

  test("lets an admin delete any comment", async () => {
    await seedComment();
    await seed({
      "admins/admin@example.com": { role: "admin" },
    });
    const db = userDb("admin-id", "admin@example.com");
    const batch = writeBatch(db);
    batch.delete(doc(db, commentPath));

    await assertSucceeds(batch.commit());
  });

  test("prevents forged like and comment ownership", async () => {
    await seedComment();
    await seed({
      "users/attacker": { communityTermsVersion: acceptedTermsVersion },
    });
    await assertFails(
      setDoc(doc(userDb("attacker"), "recipes/main/likes/attacker"), {
        userId: "victim",
        createdAt: new Date("2026-07-17T10:00:00Z"),
      }),
    );
    await assertFails(
      updateDoc(doc(userDb("owner"), commentPath), { userId: "victim" }),
    );
    await assertFails(
      setDoc(doc(userDb("attacker"), "recipes/main/comments/malformed"), {
        recipeId: "main",
        userId: "attacker",
        userDisplayName: 42,
        text: "Yorum",
        createdAt: new Date("2026-07-17T10:00:00Z"),
      }),
    );
  });

  test("allows scoped profile activity queries", async () => {
    await seedComment();
    await seed({
      "recipes/main/likes/owner": {
        userId: "owner",
        createdAt: new Date("2026-07-17T10:00:00Z"),
      },
      "recipes/main/likes/other": {
        userId: "other",
        createdAt: new Date("2026-07-17T11:00:00Z"),
      },
    });
    const db = userDb("owner");

    await assertSucceeds(
      getDocs(
        query(collectionGroup(db, "comments"), where("userId", "==", "owner")),
      ),
    );
    await assertSucceeds(
      getDocs(
        query(collectionGroup(db, "likes"), where("userId", "==", "owner")),
      ),
    );
    await assertFails(
      getDocs(
        query(collectionGroup(db, "likes"), where("userId", "==", "other")),
      ),
    );
    await assertFails(
      getDocs(
        query(collectionGroup(db, "comments"), where("userId", "==", "other")),
      ),
    );
  });
});
