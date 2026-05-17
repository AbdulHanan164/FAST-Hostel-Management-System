const { admin } = require('./admin');

/** Return the Firestore instance */
const db = () => admin.firestore();

/** Get a single doc; returns null if missing */
async function getDoc(collection, docId) {
  const snap = await db().collection(collection).doc(docId).get();
  if (!snap.exists) return null;
  return { id: snap.id, ...snap.data() };
}

/** Query a collection with optional where clauses */
async function queryDocs(collection, ...wheres) {
  let ref = db().collection(collection);
  for (const [field, op, value] of wheres) {
    ref = ref.where(field, op, value);
  }
  const snap = await ref.get();
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
}

module.exports = { db, getDoc, queryDocs };
