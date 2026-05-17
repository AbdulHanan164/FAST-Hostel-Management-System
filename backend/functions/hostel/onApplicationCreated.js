const functions = require('firebase-functions');
const { db } = require('../utils/firestore');

/**
 * Firestore trigger: fires when a new hostel application is created.
 * Assigns a FIFO queue number if one hasn't been set yet.
 *
 * Doc fields expected:
 *   userId      : string
 *   queueNumber : number (0 = not yet assigned)
 */
exports.onApplicationCreated = functions.firestore
  .document('hostelApplications/{applicationId}')
  .onCreate(async (snap) => {
    const data = snap.data();

    // Skip if already has a queue number (shouldn't happen on create, but guard anyway)
    if (data.queueNumber && data.queueNumber > 0) return null;

    const firestore = db();
    const countSnap = await firestore.collection('hostelApplications').count().get();
    const queueNumber = (countSnap.count ?? 0); // already includes this doc

    await snap.ref.set({ queueNumber }, { merge: true });
    console.log(`[Hostel] Application ${snap.id} assigned queue #${queueNumber}`);
    return null;
  });
