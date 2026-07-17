function recipeKindFor(recipe) {
  const isVariation =
    typeof recipe.parentRecipeId === 'string' && recipe.parentRecipeId.trim();
  return isVariation ? 'variation' : 'main';
}

function createRecipeCounterReconciler({ db }) {
  return async function reconcileRecipeCounters(
    recipeId,
    fields,
    collectionName = 'recipes',
  ) {
    const recipeRef = db.collection(collectionName).doc(recipeId);
    const recipeSnapshot = await recipeRef.get();
    if (!recipeSnapshot.exists) return null;

    const updates = {};
    await Promise.all(
      fields.map(async (field) => {
        const childCollection = field === 'likeCount' ? 'likes' : 'comments';
        const countSnapshot = await recipeRef
          .collection(childCollection)
          .count()
          .get();
        const actual = countSnapshot.data().count;
        if (recipeSnapshot.data()?.[field] !== actual) updates[field] = actual;
      }),
    );
    if (Object.keys(updates).length > 0) await recipeRef.update(updates);
    return updates;
  };
}

module.exports = {
  createRecipeCounterReconciler,
  recipeKindFor,
};
