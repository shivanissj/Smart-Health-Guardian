const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cron = require('node-cron');
const { rtdb, db, admin } = require('./firebase');
const { processDeviceData, setSocketServer } = require('./predictionService');
const { startReminderSync } = require('./reminderService');

// Track devices already synced to avoid duplicate listeners
const syncedDevices = new Set();

const app = express();
app.use(express.json());

// Enable CORS for Flutter Web client
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  if (req.method === 'OPTIONS') {
    return res.sendStatus(200);
  }
  next();
});

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Pass Socket.IO instance to prediction service
setSocketServer(io);

let latestVitalsCache = null;

io.on('connection', (socket) => {
  console.log(`⚡ Socket.IO client connected: ${socket.id}`);
  
  // If we have cached latest readings, push immediately on connect
  if (latestVitalsCache) {
    socket.emit('vitals_update', latestVitalsCache);
  }

  socket.on('disconnect', () => {
    console.log(`🔌 Socket.IO client disconnected: ${socket.id}`);
  });
});

app.get('/', (req, res) => {
  res.send('SHG Backend Running with Realtime Database & Socket.IO');
});

// Endpoint to save care recipient details via Admin SDK (bypassing Firestore client security rules)
app.post('/api/save-care-recipient', async (req, res) => {
  try {
    const { db } = require('./firebase');
    const { uid, careRecipient, doctor, emergencyContacts } = req.body;

    if (!uid) {
      return res.status(400).json({ success: false, error: 'UID is required' });
    }

    if (careRecipient) {
      await db.collection('care_recipient_details').doc(uid).set(careRecipient, { merge: true });
    }

    if (doctor) {
      await db.collection('doctor_details').doc(uid).set(doctor, { merge: true });
    }

    if (emergencyContacts && Array.isArray(emergencyContacts)) {
      const contactsQuery = await db.collection('emergency_contacts').where('uid', '==', uid).get();
      for (const doc of contactsQuery.docs) {
        await doc.ref.delete();
      }
      for (const contact of emergencyContacts) {
        if (contact.contact_name || contact.contact_number || contact.relationship) {
          await db.collection('emergency_contacts').add({
            uid,
            ...contact
          });
        }
      }
    }

    console.log(`✅ Successfully saved care recipient details for UID: ${uid} via Admin SDK`);
    res.json({ success: true, message: 'Details saved successfully' });
  } catch (error) {
    console.error('❌ Error saving care recipient via Admin SDK:', error);
    res.status(500).json({ success: false, error: error.message });
  }
});

// Setup Realtime Database listener on 'health_data'
const healthDataRef = rtdb.ref('health_data');

console.log('📡 Subscribing to Firebase Realtime Database: health_data');

healthDataRef.on('child_changed', (snapshot) => {
  const deviceId = snapshot.key;
  const deviceData = snapshot.val();
  console.log(`🔥 Realtime DB Event: Device update received for ${deviceId}`);
  processDeviceData(deviceId, deviceData);
});

healthDataRef.on('child_added', async (snapshot) => {
  const deviceId = snapshot.key;
  const deviceData = snapshot.val();
  console.log(`🔥 Realtime DB Event: Initial/New device data loaded for ${deviceId}`);
  processDeviceData(deviceId, deviceData);

  // Start reminder sync once per device (resolve uid from watch_details)
  if (!syncedDevices.has(deviceId)) {
    syncedDevices.add(deviceId);
    try {
      let uid = deviceId;
      const watchDoc = await db.collection('watch_details').doc(deviceId).get();
      if (watchDoc.exists && watchDoc.data().uid) {
        uid = watchDoc.data().uid;
      } else {
        const q = await db.collection('watch_details').where('device_id', '==', deviceId).limit(1).get();
        if (!q.empty) uid = q.docs[0].data().uid || deviceId;
      }
      startReminderSync(uid, deviceId);
    } catch (e) {
      console.error(`❌ [Reminders] Could not resolve uid for ${deviceId}:`, e.message);
    }
  }
});

// ─────────────────────────────────────────────────────────────
// Cron: every minute — expire reminders whose repeat_to_date < now
// Emits `reminder_expired` via Socket.IO so the Flutter UI
// removes the card in real-time, then deletes from Firestore.
// ─────────────────────────────────────────────────────────────
cron.schedule('* * * * *', async () => {
  try {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await db
      .collection('medicine_reminders')
      .where('repeat_to_date', '<', now)
      .get();

    if (snapshot.empty) return;

    const expiredIds = [];
    const batch = db.batch();

    snapshot.forEach((doc) => {
      expiredIds.push(doc.id);
      batch.delete(doc.ref);
    });

    // 1️⃣ Notify all connected Flutter clients immediately
    io.emit('reminder_expired', { expiredIds });
    console.log(`🗑️  [Reminders] Expired ${expiredIds.length} reminder(s) → notified clients: ${expiredIds.join(', ')}`);

    // 2️⃣ Delete from Firestore
    await batch.commit();
    console.log(`✅ [Reminders] Deleted ${expiredIds.length} expired reminder(s) from Firestore.`);
  } catch (err) {
    console.error('❌ [Reminders] Expiry cron error:', err.message);
  }
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`🚀 Node.js Backend server running on port ${PORT} with Socket.IO`);
});