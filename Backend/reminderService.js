/**
 * reminderService.js
 * 
 * Watches Firestore `medicine_reminders` collection and syncs upcoming
 * reminders into Firebase Realtime Database under:
 *   reminders/{deviceId}/upcoming  →  array of { name, time, label }
 * 
 * The ESP32-C3 firmware can then subscribe to this RTDB path over WiFi
 * and display the reminder on the OLED at the correct time.
 */

const { db, rtdb, admin } = require('./firebase');

/**
 * Syncs medicine reminders for a given uid/deviceId into RTDB.
 * Called once at startup and whenever a reminder changes.
 */
async function syncRemindersToRTDB(uid, deviceId) {
  try {
    const now = admin.firestore.Timestamp.now();

    // Fetch all reminders for this uid
    const snapshot = await db
      .collection('medicine_reminders')
      .where('uid', '==', uid)
      .get();

    if (snapshot.empty) {
      // Clear reminders on device if none exist
      await rtdb.ref(`reminders/${deviceId}`).set(null);
      console.log(`🗓️ [Reminders] No reminders for ${deviceId} — cleared RTDB.`);
      return;
    }

    const upcoming = [];
    snapshot.forEach((doc) => {
      const data = doc.data();
      const reminderTime = data.reminder_time; // Firestore Timestamp

      if (!reminderTime) return;

      const reminderDate = reminderTime.toDate();
      const hours = reminderDate.getHours();
      const minutes = reminderDate.getMinutes();
      const ampm = hours >= 12 ? 'PM' : 'AM';
      const displayHour = hours % 12 === 0 ? 12 : hours % 12;
      const timeStr = `${displayHour}:${String(minutes).padStart(2, '0')} ${ampm}`;

      upcoming.push({
        id: doc.id,
        name: data.medicine_name || 'Medicine',
        time: timeStr,
        hour: hours,
        minute: minutes,
        label: data.reminder_label || 'Reminder',
        taken: data.taken || false,
      });
    });

    // Sort by time of day
    upcoming.sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));

    // Find the next upcoming reminder (by current time of day)
    const nowDate = new Date();
    const nowMinutes = nowDate.getHours() * 60 + nowDate.getMinutes();
    const next = upcoming.find(r => r.hour * 60 + r.minute >= nowMinutes) || upcoming[0];

    // Write to RTDB
    await rtdb.ref(`reminders/${deviceId}`).set({
      upcoming,
      next_reminder: next || null,
      last_synced: Date.now(),
    });

    console.log(`📋 [Reminders] Synced ${upcoming.length} reminder(s) for ${deviceId} → RTDB`);
    if (next) {
      console.log(`⏰ [Reminders] Next reminder: "${next.name}" at ${next.time}`);
    }
  } catch (err) {
    console.error(`❌ [Reminders] Sync failed for ${deviceId}:`, err.message);
  }
}

/**
 * Starts a Firestore real-time listener on medicine_reminders.
 * When any reminder changes, re-syncs to RTDB for the affected device.
 * 
 * @param {string} uid - Firebase Auth UID of the caregiver
 * @param {string} deviceId - RTDB device key (e.g. 'SHG001')
 */
function startReminderSync(uid, deviceId) {
  console.log(`🔔 [Reminders] Starting reminder sync watcher for ${deviceId} (uid: ${uid})`);

  // Initial sync
  syncRemindersToRTDB(uid, deviceId);

  // Listen for real-time changes
  const unsubscribe = db
    .collection('medicine_reminders')
    .where('uid', '==', uid)
    .onSnapshot(
      () => {
        console.log(`🔄 [Reminders] Change detected — re-syncing for ${deviceId}...`);
        syncRemindersToRTDB(uid, deviceId);
      },
      (err) => {
        console.error(`❌ [Reminders] Firestore listener error:`, err.message);
      }
    );

  // Also re-sync every 5 minutes to keep RTDB fresh
  const interval = setInterval(() => syncRemindersToRTDB(uid, deviceId), 5 * 60 * 1000);

  return () => {
    unsubscribe();
    clearInterval(interval);
  };
}

module.exports = { startReminderSync, syncRemindersToRTDB };
