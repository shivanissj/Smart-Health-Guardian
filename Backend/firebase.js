const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const serviceAccountPath = path.join(__dirname, 'firebase-adminsdk.json');
let credentialOption;

try {
  if (fs.existsSync(serviceAccountPath)) {
    const fileContent = fs.readFileSync(serviceAccountPath, 'utf8').trim();
    if (fileContent.startsWith('{')) {
      const serviceAccount = JSON.parse(fileContent);
      credentialOption = admin.credential.cert(serviceAccount);
    }
  }
} catch (e) {
  console.warn('⚠️ Could not parse firebase-adminsdk.json as JSON credentials:', e.message);
}

if (!credentialOption) {
  // Default fallback if service account JSON isn't provided yet
  credentialOption = admin.credential.applicationDefault();
}

if (!admin.apps.length) {
  admin.initializeApp({
    credential: credentialOption,
    databaseURL: 'https://smarthealthguardian-22ad0-default-rtdb.asia-southeast1.firebasedatabase.app/'
  });
}

const db = admin.firestore();
const rtdb = admin.database();

module.exports = { admin, db, rtdb };

