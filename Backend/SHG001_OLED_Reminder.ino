/**
 * SHG001_OLED_Reminder.ino
 * 
 * ESP32-C3 Mini firmware snippet for displaying medicine reminders
 * fetched from Firebase Realtime Database.
 * 
 * Dependencies (install via Arduino Library Manager):
 *   - Firebase ESP Client  : mobizt/Firebase ESP Client
 *   - Adafruit SSD1306     : Adafruit SSD1306
 *   - Adafruit GFX         : Adafruit GFX Library
 *   - ArduinoJson          : bblanchon/ArduinoJson
 *   - NTPClient            : arduino-libraries/NTPClient
 * 
 * RTDB path read:  reminders/SHG001/upcoming  (array of reminder objects)
 *                  reminders/SHG001/next_reminder
 */

#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h>
#include <addons/RTDBHelper.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <NTPClient.h>
#include <WiFiUDP.h>
#include <ArduinoJson.h>

// ─────────────────────────────────────────────
// CONFIG — update these
// ─────────────────────────────────────────────
#define WIFI_SSID       "YOUR_WIFI_SSID"
#define WIFI_PASSWORD   "YOUR_WIFI_PASSWORD"

// Firebase project settings
#define FIREBASE_API_KEY    "AIzaSyCpCEA0pU1dj5CiMzlwYDjl83mLmIha538"
#define FIREBASE_DB_URL     "https://smarthealthguardian-22ad0-default-rtdb.asia-southeast1.firebasedatabase.app/"
#define FIREBASE_USER_EMAIL    "shiv@gamil.com"   // same account used in the app
#define FIREBASE_USER_PASSWORD "admin123"

// Device ID — must match Realtime DB key
#define DEVICE_ID       "SHG001"

// OLED — 128x64 SSD1306 via I2C
#define SCREEN_WIDTH  128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1     // Reset pin (not used)
#define OLED_I2C_ADDR 0x3C

// ─────────────────────────────────────────────
// Globals
// ─────────────────────────────────────────────
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

WiFiUDP ntpUDP;
NTPClient timeClient(ntpUDP, "pool.ntp.org", 19800); // IST = UTC+5:30

unsigned long lastReminderCheck = 0;
const unsigned long REMINDER_CHECK_INTERVAL = 30000; // Check every 30 seconds

struct Reminder {
  String name;
  String time;
  String label;
  int    hour;
  int    minute;
  bool   taken;
};

Reminder nextReminder;
bool hasReminder = false;

// ─────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Wire.begin();

  // Init OLED
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR)) {
    Serial.println("SSD1306 allocation failed");
    for (;;);
  }
  display.clearDisplay();
  showBootScreen();

  // Connect WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi connected: " + WiFi.localIP().toString());

  // Start NTP
  timeClient.begin();
  timeClient.update();

  // Configure Firebase
  config.api_key = FIREBASE_API_KEY;
  config.database_url = FIREBASE_DB_URL;
  auth.user.email = FIREBASE_USER_EMAIL;
  auth.user.password = FIREBASE_USER_PASSWORD;
  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.println("Firebase initialized. Fetching reminders...");
  fetchReminders();
}

// ─────────────────────────────────────────────
void loop() {
  timeClient.update();

  unsigned long now = millis();
  if (now - lastReminderCheck >= REMINDER_CHECK_INTERVAL) {
    lastReminderCheck = now;
    fetchReminders();
  }

  // Check if current time matches a reminder (within 1-minute window)
  if (hasReminder) {
    int currentHour   = timeClient.getHours();
    int currentMinute = timeClient.getMinutes();

    if (currentHour == nextReminder.hour && currentMinute == nextReminder.minute) {
      showReminderAlert(nextReminder);
    } else {
      showIdleWithNextReminder(nextReminder);
    }
  } else {
    showNoReminders();
  }

  delay(5000); // Refresh display every 5 seconds
}

// ─────────────────────────────────────────────
// Fetch next_reminder from RTDB
// ─────────────────────────────────────────────
void fetchReminders() {
  if (!Firebase.ready()) {
    Serial.println("Firebase not ready yet...");
    return;
  }

  String path = "/reminders/" + String(DEVICE_ID) + "/next_reminder";
  Serial.println("Fetching: " + path);

  if (Firebase.RTDB.getJSON(&fbdo, path.c_str())) {
    String jsonStr = fbdo.to<String>();
    Serial.println("Got reminder JSON: " + jsonStr);

    StaticJsonDocument<256> doc;
    DeserializationError err = deserializeJson(doc, jsonStr);
    if (!err && !doc.isNull()) {
      nextReminder.name   = doc["name"]   | "Medicine";
      nextReminder.time   = doc["time"]   | "--:--";
      nextReminder.label  = doc["label"]  | "Reminder";
      nextReminder.hour   = doc["hour"]   | 0;
      nextReminder.minute = doc["minute"] | 0;
      nextReminder.taken  = doc["taken"]  | false;
      hasReminder = true;
      Serial.println("Next reminder: " + nextReminder.name + " at " + nextReminder.time);
    } else {
      hasReminder = false;
    }
  } else {
    Serial.println("RTDB error: " + fbdo.errorReason());
    hasReminder = false;
  }
}

// ─────────────────────────────────────────────
// OLED display helpers
// ─────────────────────────────────────────────

void showBootScreen() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(20, 20);
  display.println("Smart Health");
  display.setCursor(30, 32);
  display.println("Guardian");
  display.display();
  delay(1500);
}

void showReminderAlert(Reminder& r) {
  display.clearDisplay();

  // Header bar
  display.fillRect(0, 0, SCREEN_WIDTH, 14, SSD1306_WHITE);
  display.setTextColor(SSD1306_BLACK);
  display.setTextSize(1);
  display.setCursor(4, 3);
  display.println("MEDICINE REMINDER");

  display.setTextColor(SSD1306_WHITE);

  // Medicine name (large)
  display.setTextSize(2);
  display.setCursor(4, 18);
  // Truncate if too long
  String name = r.name.length() > 9 ? r.name.substring(0, 9) : r.name;
  display.println(name);

  // Time & label
  display.setTextSize(1);
  display.setCursor(4, 40);
  display.println(r.label + "  " + r.time);

  // Take now prompt
  display.setCursor(4, 52);
  display.println(">>> Take Now <<<");

  display.display();
}

void showIdleWithNextReminder(Reminder& r) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // Header
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("Next Medicine:");

  // Medicine name
  display.setTextSize(2);
  display.setCursor(0, 14);
  String name = r.name.length() > 9 ? r.name.substring(0, 9) : r.name;
  display.println(name);

  // Time
  display.setTextSize(1);
  display.setCursor(0, 36);
  display.println(r.label + " - " + r.time);

  // Current time (bottom right)
  String currentTime = String(timeClient.getHours()) + ":" +
                       (timeClient.getMinutes() < 10 ? "0" : "") +
                       String(timeClient.getMinutes());
  display.setCursor(88, 56);
  display.println(currentTime);

  display.display();
}

void showNoReminders() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(10, 24);
  display.println("No reminders set");
  display.setCursor(20, 38);

  String currentTime = String(timeClient.getHours()) + ":" +
                       (timeClient.getMinutes() < 10 ? "0" : "") +
                       String(timeClient.getMinutes());
  display.println("Time: " + currentTime);
  display.display();
}
