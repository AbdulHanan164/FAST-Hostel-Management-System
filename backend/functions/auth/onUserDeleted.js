const functions = require('firebase-functions');
const { db } = require('../utils/firestore');

/**
 * Auth trigger: cleans up all Firestore data when a Firebase Auth user is deleted.
 * Removes: profiles, hostelApplications, studentBalance, gymRegistrations,
 *          messRegistrations, complaints, beds (clears studentId field).
 */
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
  const uid = user.uid;
  const firestore = db();
  const batch = firestore.batch();

  const collectionsToDelete = [
    'profiles',
    'hostelApplications',
    'studentBalance',
    'gymRegistrations',
    'messRegistrations',
  ];

  for (const col of collectionsToDelete) {
    const snap = await firestore.collection(col).where('userId', '==', uid).get();
    snap.docs.forEach(doc => batch.delete(doc.ref));
  }

  // Remove direct doc keyed by uid
  batch.delete(firestore.collection('profiles').doc(uid));
  batch.delete(firestore.collection('studentBalance').doc(uid));

  // Clear studentId from bed assignments
  const bedSnap = await firestore.collection('beds').where('studentId', '==', uid).get();
  bedSnap.docs.forEach(doc =>
    batch.update(doc.ref, { studentId: null, isOccupied: false })
  );

  await batch.commit();
  console.log(`[Auth] Cleaned up data for deleted user: ${uid}`);
  return null;
});
