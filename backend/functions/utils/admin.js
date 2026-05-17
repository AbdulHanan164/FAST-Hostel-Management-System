const admin = require('firebase-admin');

// Initialise only once (called from index.js before any module loads)
function initAdmin() {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  return admin;
}

module.exports = { admin, initAdmin };
