const functions = require('firebase-functions');
const { db } = require('../utils/firestore');

/**
 * Auth trigger: creates an initial profile document in /profiles/{uid}
 * when a new Firebase Auth user is registered.
 */
exports.onUserCreated = functions.auth.user().onCreate(async (user) => {
  const { uid, email, displayName, photoURL } = user;

  await db().collection('profiles').doc(uid).set({
    userId: uid,
    email: email || '',
    name: displayName || '',
    photoUrl: photoURL || '',
    role: 'student',
    createdAt: new Date(),
    isVerified: false,
  }, { merge: true });

  console.log(`[Auth] Profile created for new user: ${uid}`);
  return null;
});
