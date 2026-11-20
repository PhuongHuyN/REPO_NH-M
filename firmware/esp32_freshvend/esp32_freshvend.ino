/*
 * FreshVend ESP32 firmware reference
 * Target: Arduino IDE 2, ESP32 Dev Module
 *
 * Reference only. No ESP32, DHT22, door switch, or servo has been used to
 * validate this sketch. The tested system path currently uses esp32.js.
 */
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <ESP32Servo.h>

// Configure for the local installation. Use the API host's LAN address;
// localhost on the ESP32 would refer to the ESP32 itself.
const char *WIFI_SSID = "CHANGE_ME_WIFI";
const char *WIFI_PASSWORD = "CHANGE_ME_PASSWORD";
const char *API_BASE_URL = "http://192.168.1.10:3000";
const char *DEVICE_API_KEY = "CHANGE_ME_DEVICE_API_KEY";
const int MACHINE_ID = 1;

constexpr uint8_t DHT_PIN = 4;
constexpr uint8_t DHT_TYPE = DHT22;
constexpr uint8_t DOOR_PIN = 27;
constexpr uint8_t SERVO_PIN = 18;
// With a switch wired between GPIO27 and GND, HIGH (open circuit) means door open.
constexpr int DOOR_OPEN_LEVEL = HIGH;
constexpr int SERVO_CLOSED_ANGLE = 0;
constexpr int SERVO_DISPENSE_ANGLE = 90;

constexpr unsigned long TELEMETRY_INTERVAL_MS = 5000;
constexpr unsigned long QUEUE_POLL_INTERVAL_MS = 1500;
constexpr unsigned long WIFI_RETRY_INTERVAL_MS = 5000;

DHT dht(DHT_PIN, DHT_TYPE);
Servo dispenseServo;
unsigned long lastTelemetryMs = 0;
unsigned long lastQueuePollMs = 0;
unsigned long lastWifiRetryMs = 0;

String endpoint(const char *path) {
  String url(API_BASE_URL);
  while (url.endsWith("/")) url.remove(url.length() - 1);
  url += path;
  return url;
}

bool ensureWiFi() {
  if (WiFi.status() == WL_CONNECTED) return true;
  const unsigned long now = millis();
  if (now - lastWifiRetryMs >= WIFI_RETRY_INTERVAL_MS) {
    lastWifiRetryMs = now;
    Serial.println("WiFi disconnected; reconnecting...");
    WiFi.disconnect();
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  }
  return false;
}

void addDeviceHeaders(HTTPClient &http) {
  http.addHeader("X-Device-Key", DEVICE_API_KEY);
  http.addHeader("Content-Type", "application/json");
}

void sendTelemetry() {
  if (!ensureWiFi()) return;
  const float temperature = dht.readTemperature();
  const float humidity = dht.readHumidity();
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("DHT22 read failed; telemetry skipped");
    return;
  }

  JsonDocument doc;
  doc["machineId"] = MACHINE_ID;
  JsonArray readings = doc["readings"].to<JsonArray>();
  JsonObject reading = readings.add<JsonObject>();
  reading["temp"] = temperature;
  reading["hum"] = humidity;
  reading["door"] = digitalRead(DOOR_PIN) == DOOR_OPEN_LEVEL ? 1 : 0;
  // Omit t so the API/SQL assigns receive time, matching esp32.js.

  String payload;
  serializeJson(doc, payload);
  HTTPClient http;
  if (!http.begin(endpoint("/api/iot/telemetry"))) return;
  addDeviceHeaders(http);
  const int status = http.POST(payload);
  if (status > 0) {
    Serial.printf("Telemetry HTTP %d: %s\n", status, http.getString().c_str());
  } else {
    Serial.printf("Telemetry request failed: %s\n", http.errorToString(status).c_str());
  }
  http.end();
}

void dispenseOne(long orderItemId) {
  // Placeholder actuation cycle; real motor timing has not been validated.
  dispenseServo.write(SERVO_DISPENSE_ANGLE);
  delay(700);
  dispenseServo.write(SERVO_CLOSED_ANGLE);
  delay(300);

  String path = "/api/orders/items/" + String(orderItemId) + "/dispense";
  HTTPClient http;
  if (!http.begin(endpoint(path.c_str()))) return;
  addDeviceHeaders(http);
  const int status = http.POST("{\"result\":\"SUCCESS\"}");
  if (status > 0) {
    Serial.printf("Dispense item %ld HTTP %d: %s\n", orderItemId, status, http.getString().c_str());
  } else {
    Serial.printf("Dispense report failed for item %ld: %s\n", orderItemId, http.errorToString(status).c_str());
  }
  http.end();
}

void pollDispenseQueue() {
  if (!ensureWiFi()) return;

  String path = "/api/dispense-queue?machineId=" + String(MACHINE_ID);
  HTTPClient http;
  if (!http.begin(endpoint(path.c_str()))) return;
  http.addHeader("X-Device-Key", DEVICE_API_KEY);
  const int status = http.GET();
  if (status != HTTP_CODE_OK) {
    if (status > 0) Serial.printf("Queue poll HTTP %d\n", status);
    else Serial.printf("Queue poll failed: %s\n", http.errorToString(status).c_str());
    http.end();
    return;
  }

  JsonDocument doc;
  DeserializationError error = deserializeJson(doc, http.getString());
  http.end();
  if (error) {
    Serial.printf("Queue JSON parse failed: %s\n", error.c_str());
    return;
  }
  if (!doc.is<JsonArray>()) {
    Serial.println("Queue response is not a JSON array");
    return;
  }

  for (JsonObjectConst item : doc.as<JsonArrayConst>()) {
    const long itemId = item["OrderItemId"] | 0L;
    if (itemId > 0) dispenseOne(itemId);
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(DOOR_PIN, INPUT_PULLUP);
  dht.begin();
  dispenseServo.setPeriodHertz(50);
  dispenseServo.attach(SERVO_PIN, 500, 2400);
  dispenseServo.write(SERVO_CLOSED_ANGLE);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  lastWifiRetryMs = millis();
  Serial.println("FreshVend ESP32 reference firmware starting");
}

void loop() {
  const unsigned long now = millis();
  if (now - lastTelemetryMs >= TELEMETRY_INTERVAL_MS) {
    lastTelemetryMs = now;
    sendTelemetry();
  }
  if (now - lastQueuePollMs >= QUEUE_POLL_INTERVAL_MS) {
    lastQueuePollMs = now;
    pollDispenseQueue();
  }
  delay(10);
}
