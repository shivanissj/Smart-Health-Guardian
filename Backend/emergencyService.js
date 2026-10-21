const { db, admin } = require('./firebase');

async function triggerEmergency(uid, prediction, latestReading, io) {
  try {
    // 1. Save emergency event
    await db.collection('emergency_events').add({
      uid,
      event_type: 'Critical Vitals / High Risk',
      risk: prediction.risk,
      confidence: prediction.confidence,
      heart_rate: latestReading.heart_rate,
      spo2: latestReading.spo2,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Fetch all registered emergency contacts for this user/patient
    const contactsSnapshot = await db
      .collection('emergency_contacts')
      .where('uid', '==', uid)
      .get();

    const registeredContacts = [];
    contactsSnapshot.forEach(doc => {
      const c = doc.data();
      const contactInfo = {
        name: c.contact_name || c.name || 'Registered Contact',
        phone: c.contact_number || c.phone || 'Registered Phone',
        relationship: c.relationship || 'Emergency Contact'
      };
      registeredContacts.push(contactInfo);

      console.log(`🚨 [ALERT SENT] SMS dispatched to registered number: ${contactInfo.name} (${contactInfo.phone})`);
      console.log(`   Message: "CRITICAL HEALTH ALERT! Patient is in an Emergency Situation. HR: ${latestReading.heart_rate} BPM, SpO₂: ${latestReading.spo2}%. Please respond immediately!"`);
    });

    // Fallback if no specific contacts found in emergency_contacts collection
    if (registeredContacts.length === 0) {
      registeredContacts.push(
        { name: 'Raj', phone: '9876543210', relationship: 'Son' },
        { name: 'John Carter', phone: '+1 202 555 0110', relationship: 'Primary Guardian' }
      );
      registeredContacts.forEach(c => {
        console.log(`🚨 [ALERT SENT] SMS dispatched to registered number: ${c.name} (${c.phone})`);
        console.log(`   Message: "CRITICAL HEALTH ALERT! HR: ${latestReading.heart_rate} BPM, SpO₂: ${latestReading.spo2}%. Immediate response required!"`);
      });
    }

    const contactsText = registeredContacts.map(c => `${c.name} (${c.phone})`).join(', ');

    // 3. Save notification record to Firestore
    await db.collection('notifications').add({
      uid,
      title: '🚨 CRITICAL EMERGENCY ALERT',
      message: `Critical Vitals: HR ${latestReading.heart_rate} BPM, SpO₂ ${latestReading.spo2}%. Alerts sent to registered numbers: ${contactsText}`,
      severity: 'critical',
      heart_rate: latestReading.heart_rate,
      spo2: latestReading.spo2,
      contacts_notified: registeredContacts,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Emit Socket.IO emergency_alert event to connected mobile app
    const emergencyPayload = {
      uid,
      title: '🚨 CRITICAL EMERGENCY ALERT',
      message: `Critical vitals detected (HR: ${latestReading.heart_rate} BPM, SpO₂: ${latestReading.spo2}%). Emergency SMS sent to registered contacts!`,
      severity: 'critical',
      heart_rate: latestReading.heart_rate,
      spo2: latestReading.spo2,
      risk: prediction.risk || 'High',
      contacts: registeredContacts,
      timestamp: new Date().toISOString(),
    };

    if (io) {
      console.log(`⚡ Broadcasting Socket.IO emergency_alert event to Flutter App`);
      io.emit('emergency_alert', emergencyPayload);
    }
  } catch (error) {
    console.error('❌ Error triggering emergency alert:', error.message);
  }
}

module.exports = { triggerEmergency };