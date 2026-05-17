const functions = require('firebase-functions');
const { db } = require('../utils/firestore');

/**
 * Firestore trigger: fires when a hostel application status changes.
 * Sends a notification document to /notifications/ so the push trigger picks it up.
 *
 * Status values: pending | approved | rejected | fee_challan_generated | fee_confirmed | room_assigned
 */
const STATUS_MESSAGES = {
  approved:               { title: 'Application Approved',       body: 'Your hostel application has been approved! Please select a room.' },
  rejected:               { title: 'Application Rejected',       body: 'Your hostel application was not approved this time.' },
  fee_challan_generated:  { title: 'Fee Challan Ready',          body: 'Your fee challan has been generated. Please make the payment.' },
  fee_confirmed:          { title: 'Fee Payment Confirmed',      body: 'Your payment has been confirmed. Your room is being finalised.' },
  room_assigned:          { title: 'Room Assigned',              body: 'Congratulations! Your room has been assigned. Welcome to the hostel.' },
};

exports.onApplicationStatusChanged = functions.firestore
  .document('hostelApplications/{applicationId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();

    if (before.status === after.status) return null;

    const msg = STATUS_MESSAGES[after.status];
    if (!msg || !after.userId) return null;

    await db().collection('notifications').add({
      userId:    after.userId,
      title:     msg.title,
      body:      msg.body,
      payload:   { applicationId: change.after.id, status: after.status },
      createdAt: new Date(),
      read:      false,
    });

    console.log(`[Hostel] Notification queued for ${after.userId} — status: ${after.status}`);
    return null;
  });
