const functions = require('firebase-functions');
const { db } = require('../utils/firestore');

/**
 * Firestore trigger: fires when a feePayments doc is updated.
 * When status changes to 'accepted', recalculates remainingBalance and creditBalance
 * in /studentBalance/{userId}.
 *
 * Doc fields expected:
 *   userId        : string
 *   amount        : number  — challan face value
 *   paidAmount    : number  — actual amount received from student
 *   status        : string  — 'pending' | 'accepted' | 'rejected'
 */
exports.onChallanAccepted = functions.firestore
  .document('feePayments/{paymentId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after  = change.after.data();

    // Only run when status transitions to 'accepted'
    if (before.status === after.status || after.status !== 'accepted') return null;

    const { userId, amount = 0, paidAmount = 0 } = after;
    if (!userId) return null;

    const firestore  = db();
    const balanceRef = firestore.collection('studentBalance').doc(userId);
    const balSnap    = await balanceRef.get();
    const existing   = balSnap.exists ? balSnap.data() : {};

    const prevRemaining = existing.remainingBalance || 0;
    const prevCredit    = existing.creditBalance    || 0;

    const diff = paidAmount - amount; // positive = overpaid, negative = underpaid

    let newRemaining = 0;
    let newCredit    = 0;

    if (diff >= 0) {
      // Overpaid or exact — carry surplus as credit
      newCredit    = prevCredit + diff;
      newRemaining = Math.max(0, prevRemaining); // keep existing unpaid balance
    } else {
      // Underpaid
      const shortfall = Math.abs(diff);
      if (prevCredit >= shortfall) {
        // Credit covers the gap
        newCredit    = prevCredit - shortfall;
        newRemaining = prevRemaining;
      } else {
        // Not enough credit
        newRemaining = prevRemaining + (shortfall - prevCredit);
        newCredit    = 0;
      }
    }

    await balanceRef.set({
      userId,
      remainingBalance: newRemaining,
      creditBalance:    newCredit,
      lastUpdated:      new Date(),
    }, { merge: true });

    console.log(`[Payments] Balance updated for ${userId} — remaining: ${newRemaining}, credit: ${newCredit}`);
    return null;
  });
