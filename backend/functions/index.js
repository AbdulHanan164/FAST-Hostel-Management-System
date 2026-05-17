/**
 * FAST Hostel System — Firebase Cloud Functions
 * ────────────────────────────────────────────────────────────────────
 * Entry point.  Each domain module lives in its own folder and exports
 * only named Cloud Function objects — nothing else leaks across modules.
 *
 * Deployment:
 *   cd backend
 *   npm install
 *   firebase deploy --only functions
 */

const { initAdmin } = require('./utils/admin');
initAdmin();                          // must run before any module is required

const notifications = require('./notifications');
const auth          = require('./auth');
const payments      = require('./payments');
const hostel        = require('./hostel');

// ── Notification triggers ────────────────────────────────────────────
exports.onNotificationCreated       = notifications.onNotificationCreated;

// ── Auth triggers ────────────────────────────────────────────────────
exports.onUserCreated               = auth.onUserCreated;
exports.onUserDeleted               = auth.onUserDeleted;

// ── Payment triggers ─────────────────────────────────────────────────
exports.onChallanAccepted           = payments.onChallanAccepted;
exports.onNewChallan                = payments.onNewChallan;

// ── Hostel triggers ──────────────────────────────────────────────────
exports.onApplicationCreated        = hostel.onApplicationCreated;
exports.onApplicationStatusChanged  = hostel.onApplicationStatusChanged;
