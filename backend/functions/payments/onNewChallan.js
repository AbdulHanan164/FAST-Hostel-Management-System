const functions = require('firebase-functions');
const { db } = require('../utils/firestore');

/**
 * Firestore trigger: fires when a new fee challan is created in /feeChallans/{challanId}.
 * Automatically deducts any existing creditBalance from the challan amount.
 *
 * Doc fields expected:
 *   userId : string
 *   amount : number — original challan amount
 */
exports.onNewChallan = functions.firestore
  .document('feeChallans/{challanId}')
  .onCreate(async (snap) => {
    const { userId, amount = 0 } = snap.data();
    if (!userId || amount <= 0) return null;

    const firestore  = db();
    const balanceRef = firestore.collection('studentBalance').doc(userId);
    const balSnap    = await balanceRef.get();
    if (!balSnap.exists) return null;

    const { creditBalance = 0 } = balSnap.data();
    if (creditBalance <= 0) return null;

    const deduction   = Math.min(creditBalance, amount);
    const netAmount   = amount - deduction;
    const newCredit   = creditBalance - deduction;

    // Update challan with deducted amount
    await snap.ref.set({ netAmount, creditApplied: deduction }, { merge: true });

    // Reduce credit balance
    await balanceRef.set({
      creditBalance: newCredit,
      lastUpdated:   new Date(),
    }, { merge: true });

    console.log(`[Payments] Credit Rs.${deduction} auto-applied to challan for ${userId}`);
    return null;
  });
