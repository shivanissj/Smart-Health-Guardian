/*
  Smart Health Guardian - ESP32-C3 Super Mini + MAX30102 + OLED -> Firebase RTDB
*/

#define ENABLE_USER_AUTH
#define ENABLE_DATABASE

#include <Wire.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include <FirebaseClient.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

// ===============================
// WIFI (2.4 GHz only)
// ===============================
#define WIFI_SSID     "iPhone (2)"
#define WIFI_PASSWORD "Shivani."

// ===============================
// FIREBASE
// ===============================
#define API_KEY       "AIzaSyCpCEA0pU1dj5CiMzlwYDjl83mLmIha538"
#define USER_EMAIL    "shivanisivakumar27@gmail.com"
#define USER_PASSWORD "20072019"
#define DATABASE_URL  "https://smarthealthguardian-22ad0-default-rtdb.asia-southeast1.firebasedatabase.app"

#define DEVICE_ID          "SHG001"
#define UPLOAD_INTERVAL    10000UL
#define HISTORY_INTERVAL   60000UL
#define REMINDER_FETCH_INTERVAL 30000UL // Fetch reminder every 30 seconds

// ===============================
// SENSOR & DISPLAY SETTINGS
// ===============================
#define I2C_SDA        4
#define I2C_SCL        5
#define FINGER_IR_MIN  50000UL
#define BUF_SIZE       100
#define STEP_SIZE      25

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define OLED_RESET    -1
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

MAX30105 particleSensor;

uint32_t irBuf[BUF_SIZE];
uint32_t redBuf[BUF_SIZE];
int bufCount = 0;
int newSamples = 0;

int32_t spo2Raw, hrRaw;
int8_t  spo2Valid, hrValid;

float hrAvg = 0, spo2Avg = 0;
bool  fingerOn = false;

// ===============================
// FIREBASE OBJECTS
// ===============================
WiFiClientSecure ssl_client;
using AsyncClient = AsyncClientClass;
AsyncClient aClient(ssl_client);

UserAuth user_auth(API_KEY, USER_EMAIL, USER_PASSWORD, 3000);
FirebaseApp app;
RealtimeDatabase Database;

// ===============================
// REMINDER STATE
// ===============================
String currentMedName = "No Reminders";
String currentLabel = "";
int currentReminderHour = -1;
int currentReminderMinute = -1;
bool currentReminderTaken = false;

// UI state
bool showReminderScreen = false;
unsigned long reminderDisplayStart = 0;
const unsigned long REMINDER_DISPLAY_DURATION = 30000; // Show for 30 seconds
unsigned long lastReminderFetch = 0;

// Display power management
bool displayOn = false;
unsigned long lastFingerSeen = 0;
const unsigned long FINGER_GRACE_MS = 3000;  // keep OLED on 3s after finger lift

// ===============================
// WIFI
// ===============================
void onWiFiEvent(WiFiEvent_t event, WiFiEventInfo_t info) {
  if (event == ARDUINO_EVENT_WIFI_STA_DISCONNECTED)
    Serial.printf("[WiFi] Disconnected, reason %d\n", info.wifi_sta_disconnected.reason);
}

bool connectWiFi(unsigned long timeoutMs = 20000) {
  WiFi.disconnect(true, true);
  delay(500);
  WiFi.mode(WIFI_STA);
  WiFi.persistent(false);
  WiFi.setAutoReconnect(true);
  WiFi.setSleep(false);
  WiFi.setTxPower(WIFI_POWER_8_5dBm);

  Serial.printf("Connecting to \"%s\" ", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
    Serial.print(".");
    delay(500);
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("WiFi connected! IP: ");
    Serial.println(WiFi.localIP());
    return true;
  }
  Serial.println("WiFi failed.");
  return false;
}

// ===============================
// SENSOR
// ===============================
void resetBuffer() {
  bufCount = 0;
  newSamples = 0;
}

void calculateVitals() {
  maxim_heart_rate_and_oxygen_saturation(
    irBuf, BUF_SIZE, redBuf,
    &spo2Raw, &spo2Valid, &hrRaw, &hrValid);

  if (hrValid && hrRaw >= 40 && hrRaw <= 180)
    hrAvg = (hrAvg == 0) ? hrRaw : (0.7f * hrAvg + 0.3f * hrRaw);

  if (spo2Valid && spo2Raw >= 80 && spo2Raw <= 100)
    spo2Avg = (spo2Avg == 0) ? spo2Raw : (0.7f * spo2Avg + 0.3f * spo2Raw);
}

void readSensor() {
  particleSensor.check();

  while (particleSensor.available()) {
    uint32_t red = particleSensor.getFIFORed();
    uint32_t ir  = particleSensor.getFIFOIR();
    particleSensor.nextSample();

    if (ir < FINGER_IR_MIN) {
      if (fingerOn) Serial.println("Finger removed.");
      fingerOn = false;
      hrAvg = 0;
      spo2Avg = 0;
      resetBuffer();
      continue;
    }

    if (!fingerOn) Serial.println("Finger detected - measuring (takes ~5 s)...");
    fingerOn = true;

    if (bufCount < BUF_SIZE) {
      redBuf[bufCount] = red;
      irBuf[bufCount]  = ir;
      bufCount++;
      if (bufCount == BUF_SIZE) newSamples = STEP_SIZE;
    } else {
      memmove(redBuf, redBuf + 1, (BUF_SIZE - 1) * sizeof(uint32_t));
      memmove(irBuf,  irBuf + 1,  (BUF_SIZE - 1) * sizeof(uint32_t));
      redBuf[BUF_SIZE - 1] = red;
      irBuf[BUF_SIZE - 1]  = ir;
      newSamples++;
    }

    if (bufCount == BUF_SIZE && newSamples >= STEP_SIZE) {
      calculateVitals();
      newSamples = 0;
    }
  }
}

// ===============================
// FIREBASE RTDB UPLOAD (Health Data)
// ===============================
String buildJson() {
  time_t now = time(nullptr);
  unsigned long ts = (now > 100000) ? (unsigned long)now : 0;
  bool good = fingerOn && hrAvg > 0 && spo2Avg > 0;

  String json = "{";
  json += "\"heart_rate\":" + String(good ? (int)(hrAvg + 0.5f) : 0) + ",";
  json += "\"spo2\":"       + String(good ? (int)(spo2Avg + 0.5f) : 0) + ",";
  json += "\"finger_detected\":" + String(fingerOn ? "true" : "false") + ",";
  json += "\"status\":\"" + String(good ? "OK" : (fingerOn ? "Measuring" : "No finger")) + "\",";
  json += "\"timestamp\":" + String(ts) + ",";
  json += "\"rssi\":" + String(WiFi.RSSI());
  json += "}";
  return json;
}

void uploadLatest() {
  String payload = buildJson();
  object_t json(payload);
  String path = "/health_data/" DEVICE_ID "/latest";
  bool ok = Database.set<object_t>(aClient, path, json);
  if (ok) Serial.println(">> Uploaded to RTDB: " + payload);
  else Serial.println(">> RTDB Upload FAILED: " + aClient.lastError().message());
}

void pushHistory() {
  if (!(fingerOn && hrAvg > 0 && spo2Avg > 0)) return;
  String payload = buildJson();
  object_t json(payload);
  String path = "/health_data/" DEVICE_ID "/history";
  Database.push<object_t>(aClient, path, json);
}
// ===============================
// FIREBASE RTDB FETCH (Reminder)
// ===============================
void fetchReminderFromRTDB() {
 String path = "/reminders/SHG001/next_reminder";
  
  Serial.println(">> Fetching reminder from RTDB...");
  
  // Fetch as a String - note: get() returns the value directly
  String jsonStr = Database.get<String>(aClient, path);
  
  if (jsonStr.length() == 0) {
    Serial.print(">> RTDB Fetch Failed or empty. Error: ");
    Serial.println(aClient.lastError().message());
    return;
  }
  
  Serial.print(">> RTDB Raw: ");
  Serial.println(jsonStr);
  
  // Manual JSON parsing - extract values by key
  auto extractInt = [&](String key) -> int {
    String searchKey = "\"" + key + "\":";
    int idx = jsonStr.indexOf(searchKey);
    if (idx == -1) return -1;
    idx += searchKey.length();
    while (idx < (int)jsonStr.length() && (jsonStr[idx] == ' ' || jsonStr[idx] == '\t')) idx++;
    int endIdx = idx;
    while (endIdx < (int)jsonStr.length() && (isdigit(jsonStr[endIdx]) || jsonStr[endIdx] == '-')) endIdx++;
    return jsonStr.substring(idx, endIdx).toInt();
  };
  
  auto extractString = [&](String key) -> String {
    String searchKey = "\"" + key + "\":\"";
    int idx = jsonStr.indexOf(searchKey);
    if (idx == -1) return "";
    idx += searchKey.length();
    int endIdx = jsonStr.indexOf("\"", idx);
    if (endIdx == -1) return "";
    return jsonStr.substring(idx, endIdx);
  };
  
  auto extractBool = [&](String key) -> bool {
    String searchKey = "\"" + key + "\":";
    int idx = jsonStr.indexOf(searchKey);
    if (idx == -1) return false;
    idx += searchKey.length();
    while (idx < (int)jsonStr.length() && jsonStr[idx] == ' ') idx++;
    if (jsonStr.substring(idx, idx + 4) == "true") return true;
    return false;
  };
  
  int hour = extractInt("hour");
  int minute = extractInt("minute");
  String label = extractString("label");
  String name = extractString("name");
  bool taken = extractBool("taken");
  
  if (hour != -1 && minute != -1 && name.length() > 0) {
    currentReminderHour = hour;
    currentReminderMinute = minute;
    currentLabel = label;
    currentMedName = name;
    currentReminderTaken = taken;
    
    Serial.printf(">> RTDB Reminder: %s at %02d:%02d (taken: %s)\n",
                  currentMedName.c_str(), currentReminderHour, currentReminderMinute,
                  currentReminderTaken ? "true" : "false");
  } else {
    Serial.println(">> RTDB: Could not parse reminder data.");
  }
}

// ===============================
// OLED DISPLAY FUNCTIONS
// ===============================
void drawHealthScreen() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 0);
  display.println(F("SMART HEALTH GUARDIAN"));
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  display.setCursor(0, 20);
  display.print(F("Heart Rate: "));
  if (fingerOn && hrAvg > 0) {
    display.print((int)hrAvg);
    display.println(F(" BPM"));
  } else {
    display.println(F("-- BPM"));
  }

  display.setCursor(0, 35);
  display.print(F("SpO2:       "));
  if (fingerOn && spo2Avg > 0) {
    display.print((int)spo2Avg);
    display.println(F(" %"));
  } else {
    display.println(F("-- %"));
  }

  display.setCursor(0, 55);
  display.print(F("Sensor: "));
  display.println(fingerOn ? F("Connected") : F("No Finger"));

  display.display();
}

// ===============================
// DISPLAY POWER CONTROL
// ===============================
void updateDisplayPower() {
  // Keep display on for 3 seconds after finger is removed (prevents flicker)
  if (fingerOn) lastFingerSeen = millis();

  bool shouldBeOn = (millis() - lastFingerSeen < FINGER_GRACE_MS) || showReminderScreen;

  if (shouldBeOn && !displayOn) {
    display.ssd1306_command(SSD1306_DISPLAYON);
    displayOn = true;
    Serial.println(">> OLED turned ON");
  } else if (!shouldBeOn && displayOn) {
    display.clearDisplay();
    display.display();                             // Clear pixel buffer first
    display.ssd1306_command(SSD1306_DISPLAYOFF);
    displayOn = false;
    Serial.println(">> OLED turned OFF (idle)");
  }
}

void drawReminderScreen() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(0, 0);
  display.println(F("*** MEDICINE REMINDER ***"));
  display.drawLine(0, 10, 128, 10, SSD1306_WHITE);

  display.setCursor(0, 20);
  display.print(F("Medicine: "));
  display.println(currentMedName);

  display.setCursor(0, 35);
  display.print(F("Time: "));
  if (currentReminderHour != -1 && currentReminderMinute != -1) {
    // Format time as HH:MM AM/PM
    int displayHour = currentReminderHour % 12;
    if (displayHour == 0) displayHour = 12;
    const char* ampm = (currentReminderHour >= 12) ? "PM" : "AM";
    char timeStr[20];
    snprintf(timeStr, sizeof(timeStr), "%02d:%02d %s", displayHour, currentReminderMinute, ampm);
    display.println(timeStr);
  } else {
    display.println(F("Not Set"));
  }

  display.setCursor(0, 50);
  display.print(F("Label: "));
  display.println(currentLabel);

  display.display();
}

// ===============================
// SETUP
// ===============================
void setup() {
  Serial.begin(115200);
  delay(2000);

  Serial.println();
  Serial.println("================================");
  Serial.println(" Smart Health Guardian");
  Serial.println(" ESP32-C3 + MAX30102 + OLED");
  Serial.println("================================");

  // ---- I2C & OLED ----
  Wire.begin(I2C_SDA, I2C_SCL);

  if (!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("SSD1306 allocation failed"));
  } else {
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 0);
    display.println("Booting...");
    display.display();
  }

  // ---- Sensor ----
  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("ERROR: MAX30102 not found!");
    while (true) delay(1000);
  }
  Serial.println("MAX30102 found.");
  particleSensor.setup(60, 4, 2, 100, 411, 4096);

  // ---- WiFi ----
  WiFi.onEvent(onWiFiEvent);
  while (!connectWiFi()) {
    Serial.println("Retrying in 3 s...");
    delay(3000);
  }

  // ---- Time (NTP) ----
  // Set to IST (UTC+5:30) to match your local time
  configTime(19800, 0, "pool.ntp.org", "time.google.com");

  Serial.print("Waiting for NTP time sync");
  time_t now = 0;
  unsigned long ntpStart = millis();
  while (now < 100000 && millis() - ntpStart < 10000) {
    Serial.print(".");
    delay(500);
    now = time(nullptr);
  }
  Serial.println();
  if (now > 100000) {
    Serial.print("NTP synced. Current time: ");
    Serial.print(ctime(&now));
  } else {
    Serial.println("NTP sync failed.");
  }

  // ---- Firebase ----
  Serial.println("Initializing Firebase...");
  ssl_client.setInsecure();
  initializeApp(aClient, app, getAuth(user_auth), 3000);
  app.getApp<RealtimeDatabase>(Database);
  Database.url(DATABASE_URL);

  Serial.print("Waiting for Firebase auth");
  unsigned long fbStart = millis();
  while (!app.ready() && millis() - fbStart < 15000) {
    app.loop();
    Serial.print(".");
    delay(100);
  }
  Serial.println();

  if (app.ready()) {
    Serial.println("Firebase ready!");
  } else {
    Serial.println("Firebase auth timeout. Will retry in loop.");
  }

  Serial.println("Setup complete. Place your finger on the sensor.");
}

// ===============================
// LOOP
// ===============================
void loop() {
  // 1. Read sensor
  readSensor();

  // 2. Manage display power (turn on/off based on finger or reminder)
  updateDisplayPower();

  // 3. Only draw when display is on
  if (displayOn) {
    if (showReminderScreen) {
      drawReminderScreen();
    } else {
      drawHealthScreen();
    }
  }
  // 3. WiFi reconnection check
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost. Reconnecting...");
    connectWiFi();
    resetBuffer();
    delay(1000);
    return;
  }

  // 4. Firebase loop
  app.loop();

  // 5. Firebase-dependent tasks
  if (app.ready()) {
    static unsigned long lastUpload  = 0;
    static unsigned long lastHistory = 0;

    // Upload Health Data
    if (millis() - lastUpload >= UPLOAD_INTERVAL) {
      lastUpload = millis();
      uploadLatest();
      if (millis() - lastHistory >= HISTORY_INTERVAL) {
        lastHistory = millis();
        pushHistory();
      }
      particleSensor.clearFIFO();
      resetBuffer();
    }

    // Fetch Reminder from RTDB
    if (millis() - lastReminderFetch >= REMINDER_FETCH_INTERVAL) {
      lastReminderFetch = millis();
      fetchReminderFromRTDB();
    }
  }

  // 6. Check reminder time logic
  time_t now = time(nullptr);
  if (now > 100000) {
    struct tm *timeinfo = localtime(&now);
    
    bool timeMatches = false;
    if (currentReminderHour != -1 && currentReminderMinute != -1) {
      if (timeinfo->tm_hour == currentReminderHour && 
          timeinfo->tm_min == currentReminderMinute) {
        timeMatches = true;
      }
    }

    // Trigger reminder if time matches AND it hasn't been taken yet
    if (timeMatches && currentMedName != "No Reminders" && !currentReminderTaken) {
      if (!showReminderScreen) {
        Serial.println(">>> REMINDER TRIGGERED! Displaying on OLED.");
        showReminderScreen = true;
        reminderDisplayStart = millis();
      }
    }

    // Hide reminder after 30 seconds
    if (showReminderScreen &&
        (millis() - reminderDisplayStart >= REMINDER_DISPLAY_DURATION)) {
      showReminderScreen = false;
      Serial.println(">>> Reminder display timeout.");
    }
  }

  delay(10);
}
