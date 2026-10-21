const axios = require('axios');
const { db, admin } = require('./firebase');
const { triggerEmergency } = require('./emergencyService');

let ioInstance = null;
let cachedVitalsPayload = null;

function setSocketServer(io) {
  ioInstance = io;
  if (ioInstance) {
    ioInstance.on('connection', (socket) => {
      if (cachedVitalsPayload) {
        socket.emit('vitals_update', cachedVitalsPayload);
      }
    });
  }
}

/**
 * Processes health data received from IoT Device in Realtime Database.
 * @param {string} deviceId - E.g., 'SHG001'
 * @param {object} deviceData - The data payload under health_data/deviceId containing history & latest
 */
async function processDeviceData(deviceId, deviceData) {
  try {
    if (!deviceData || !deviceData.latest) {
      console.log(`⚠️ No latest reading available for device ${deviceId}`);
      return;
    }

    const latest = deviceData.latest;

    // Ignore reading if finger is not detected
    if (latest.finger_detected === false || latest.status === 'No finger') {
      console.log(`ℹ️ Device ${deviceId}: No finger detected. Skipping ML prediction.`);
      return;
    }

    // 1. Map Device ID (SHG001) to Patient / User UID from Firestore
    let uid = deviceId;
    let patient = null;

    // Check watch_details mapping first (device_id -> uid)
    const watchDoc = await db.collection('watch_details').doc(deviceId).get();
    if (watchDoc.exists) {
      uid = watchDoc.data().uid || deviceId;
    } else {
      const watchQuery = await db.collection('watch_details').where('device_id', '==', deviceId).limit(1).get();
      if (!watchQuery.empty) {
        uid = watchQuery.docs[0].data().uid || deviceId;
      }
    }

    // Check care_recipient_details for patient profile using linked uid or device_id
    const patientDoc = await db.collection('care_recipient_details').doc(uid).get();
    if (patientDoc.exists) {
      patient = patientDoc.data();
    } else {
      const altQuery = await db.collection('care_recipient_details').where('device_id', '==', deviceId).limit(1).get();
      if (!altQuery.empty) {
        uid = altQuery.docs[0].id;
        patient = altQuery.docs[0].data();
      } else {
        const uidQuery = await db.collection('care_recipient_details').where('uid', '==', uid).limit(1).get();
        if (!uidQuery.empty) {
          patient = uidQuery.docs[0].data();
        } else {
          // Fallback to first registered patient profile in Firestore
          const anyPatient = await db.collection('care_recipient_details').limit(1).get();
          if (!anyPatient.empty) {
            uid = anyPatient.docs[0].id;
            patient = anyPatient.docs[0].data();
          }
        }
      }
    }

    if (!patient) {
      console.log(`⚠️ Patient details not found for device ${deviceId}. Using default profile.`);
      patient = { patient_name: 'Care Recipient', age: 21, gender: 'Female', medical_conditions: ['Diabetes', 'Asthma'], allergies: ['No'] };
    }

    const patientName = patient.patient_name || patient.name || 'Care Recipient';
    const patientAge = Number(patient.age) || 21;
    const patientGender = (patient.gender || 'Female').toString();
    const conditions = patient.medical_conditions || patient.diseases || [];
    const allergiesList = patient.allergies || [];
    const hasRealAllergies = allergiesList.length > 0 && !allergiesList.includes('No') && !allergiesList.includes('None');

    console.log(`👤 [Patient Linked for ML] Device: ${deviceId} ➡️ Patient: "${patientName}" (UID: ${uid})`);
    console.log(`   Profile Attributes: Age ${patientAge}, Gender ${patientGender}, Conditions: ${JSON.stringify(conditions)}, Allergies: ${JSON.stringify(allergiesList)}`);

    // 2. Extract recent readings history
    let readings = [];
    if (deviceData.history && typeof deviceData.history === 'object') {
      readings = Object.values(deviceData.history);
      // Sort history descending by timestamp
      readings.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));
    }

    // Include latest reading if history is sparse
    if (readings.length === 0) {
      readings = [latest];
    } else {
      // Take up to 10 latest readings
      readings = readings.slice(0, 10);
    }

    // 3. Calculate vitals summary
    const validHRs = readings.map(r => r.heart_rate).filter(hr => hr > 0);
    const validSpO2s = readings.map(r => r.spo2).filter(sp => sp > 0);

    const avgHR = validHRs.length > 0 ? validHRs.reduce((s, r) => s + r, 0) / validHRs.length : latest.heart_rate;
    const avgSpO2 = validSpO2s.length > 0 ? validSpO2s.reduce((s, r) => s + r, 0) / validSpO2s.length : latest.spo2;
    const maxHR = validHRs.length > 0 ? Math.max(...validHRs) : latest.heart_rate;
    const minSpO2 = validSpO2s.length > 0 ? Math.min(...validSpO2s) : latest.spo2;

    // 4. Check for previous emergency events
    const emergencySnapshot = await db
      .collection('emergency_events')
      .where('uid', '==', uid)
      .limit(1)
      .get();

    const previousEmergency = emergencySnapshot.empty ? 0 : 1;

    // 5. Build ML payload expected by Python model
    const payload = {
      HeartRate: latest.heart_rate,
      SpO2: latest.spo2,
      Age: patientAge,
      Gender: patientGender.toLowerCase() === 'female' ? 0 : 1,
      Hypertension: conditions.includes('Hypertension') ? 1 : 0,
      Diabetes: conditions.includes('Diabetes') ? 1 : 0,
      Asthma: conditions.includes('Asthma') ? 1 : 0,
      Allergies: hasRealAllergies ? 1 : 0,
      PreviousEmergency: previousEmergency,
      AverageHR: Math.round(avgHR),
      AverageSpO2: Math.round(avgSpO2),
      MaximumHR: maxHR,
      MinimumSpO2: minSpO2,
    };

    console.log(`📤 [Device ${deviceId}] Sending payload to ML backend:`, payload);

    // 6. Call ML Prediction Microservice (FastAPI / Flask)
    const mlUrl = process.env.ML_SERVICE_URL || 'http://127.0.0.1:8000/predict';
    const response = await axios.post(mlUrl, payload);
    const prediction = response.data;

    console.log(`🤖 [Device ${deviceId}] ML Prediction Result:`, prediction);

    const vitalsPayload = {
      device_id: deviceId,
      uid: uid,
      heart_rate: latest.heart_rate ?? 0,
      spo2: latest.spo2 ?? 0,
      avg_heart_rate: Math.round(avgHR),
      avg_spo2: Math.round(avgSpO2),
      risk_level: prediction.risk || 'Low',
      confidence: Math.round(prediction.confidence || 0),
      recommendation:
        prediction.risk === 'High'
          ? 'Seek immediate medical attention'
          : prediction.risk === 'Medium'
          ? 'Monitor closely'
          : 'Healthy',
      status: prediction.risk === 'High' ? 'EMERGENCY' : (prediction.risk === 'Medium' ? 'NEEDS ATTENTION' : 'GOOD'),
      battery_percentage: latest.battery ?? 100,
      timestamp: new Date().toISOString(),
    };

    cachedVitalsPayload = vitalsPayload;

    if (ioInstance) {
      console.log(`📡 Emitting Socket.IO vitals_update event for device ${deviceId}:`, vitalsPayload);
      ioInstance.emit('vitals_update', vitalsPayload);
    }

    // Also write to Firestore vitals_live/{uid} so Flutter Web can subscribe
    // directly via Firestore real-time listener (no Socket.IO/CORS needed)
    await db.collection('vitals_live').doc(uid).set({
      ...vitalsPayload,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log(`🔥 [Firestore] vitals_live/${uid} updated for Flutter real-time listener.`);

    // 7. Save prediction log & latest valid health data to Firestore
    await db.collection('ml_predictions').add({
      uid,
      device_id: deviceId,
      risk_level: prediction.risk,
      probability: prediction.confidence / 100,
      recommendation:
        prediction.risk === 'High'
          ? 'Seek immediate medical attention'
          : prediction.risk === 'Medium'
          ? 'Monitor closely'
          : 'Healthy',
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (latest.heart_rate > 0 || latest.spo2 > 0) {
      await db.collection('health_data').add({
        uid,
        device_id: deviceId,
        heart_rate: latest.heart_rate,
        spo2: latest.spo2,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await db.collection('watch_details').doc(deviceId).set({
      uid,
      device_id: deviceId,
      paired: true,
      battery_percentage: latest.battery ?? 100,
      last_sync: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // 8. Emergency Evaluation
    const criticalVitals =
      latest.heart_rate > 120 ||
      latest.heart_rate < 50 ||
      latest.spo2 < 90;

    if (
      prediction.risk === 'High' &&
      prediction.confidence >= 90 &&
      criticalVitals
    ) {
      console.log(`🚨 HIGH RISK CONFIRMED for ${deviceId} (User: ${uid})`);
      await triggerEmergency(uid, prediction, latest);
    } else {
      console.log(`✅ [Device ${deviceId}] Risk evaluated cleanly without emergency trigger.`);
    }
  } catch (error) {
    console.error(`❌ Error processing device data for ${deviceId}:`, error.message);
  }
}

module.exports = { processDeviceData, setSocketServer };