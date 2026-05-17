const functions = require('firebase-functions');
const { admin } = require('../utils/admin');

/**
 * Firestore trigger: fires when a doc is created in /notifications/{notificationId}.
 * Reads the target user's FCM tokens from /profiles/{userId} and sends a multicast push.
 *
 * Expected document fields:
 *   userId  : string  — recipient UID
 *   title   : string  — notification title
 *   body    : string  — notification body
 *   payload : object  — optional key/value data (all values coerced to strings)
 */
exports.onNotificationCreated = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap) => {
    const data = snap.data();
    if (!data) return null;

    const { userId, title = 'Notification', body = '', payload = {} } = data;
    if (!userId) return null;

    try {
      const profileSnap = await admin.firestore()
        .collection('profiles')
        .doc(userId)
        .get();

      if (!profileSnap.exists) return null;

      const tokens = (profileSnap.data().fcmTokens) || [];
      if (!tokens.length) return null;

      const message = {
        notification: { title, body },
        data: Object.fromEntries(
          Object.entries(payload).map(([k, v]) => [k, String(v)])
        ),
        tokens,
      };

      const response = await admin.messaging().sendMulticast(message);
      console.log(`[FCM] sent — success: ${response.successCount}, failure: ${response.failureCount}`);

      await snap.ref.set(
        { pushResult: { successCount: response.successCount, failureCount: response.failureCount } },
        { merge: true }
      );
    } catch (err) {
      console.error('[FCM] Error sending push notification:', err);
    }

    return null;
  });
