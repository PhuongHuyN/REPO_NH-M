# FreshVend ESP32 reference firmware

`esp32_freshvend/esp32_freshvend.ino` is reference firmware for an ESP32 Dev Module. **It has not been flashed to or tested on real hardware.** The project has no physical ESP32, DHT22, door switch, or servo; all system IoT data and end-to-end testing use the simulator at `app/simulator/esp32.js`. The servo action in the sketch is only a placeholder sequence, not a validated dispenser.

## Suggested wiring

| Part | ESP32 connection | Notes |
|---|---|---|
| DHT22 DATA | GPIO4 | Pull DATA up to 3.3 V with a 10 kΩ resistor. Power the sensor from 3.3 V and share GND. |
| SG90 signal | GPIO18 | Use a separate regulated 5 V supply sized for servo current. Join its GND to ESP32 GND; do not power the servo from the ESP32 3.3 V pin. |
| Door switch | GPIO27 to GND | Uses `INPUT_PULLUP`: open circuit reads HIGH (door open), switch closed to GND reads LOW. Change `DOOR_OPEN_LEVEL` if the switch behaves oppositely. |

Check the exact board and module pinouts before wiring. Keep servo power separate from the ESP32 regulator while maintaining a common ground.

## Configuration

Edit the constants at the top of the sketch:

- `WIFI_SSID` / `WIFI_PASSWORD`: Wi-Fi credentials.
- `API_BASE_URL`: reachable API address, such as `http://192.168.1.10:3000`. Use the API host's LAN address, not `localhost` (which would mean the ESP32 itself). Docker Compose publishes API port 3000 on the host.
- `DEVICE_API_KEY`: must match the API's `DEVICE_API_KEY` configuration. The repository default is for development only; keep real credentials private.
- `MACHINE_ID`: an existing machine ID in FreshVendDB.

Default server-side machine thresholds are `MinTemp=2°C`, `MaxTemp=8°C`, `ConsecutiveBreaches=3`, and `DoorOpenMaxMinutes=2`. Firmware sends sensor readings; threshold evaluation is server-side, not implemented locally here. Telemetry interval is 5 seconds and dispense queue polling interval is 1.5 seconds.

## API protocol

- Requests include `X-Device-Key`.
- Every 5 seconds, `POST /api/iot/telemetry` sends JSON such as `{"machineId":1,"readings":[{"temp":4.5,"hum":80,"door":0}]}`. As in the simulator, `t` is omitted and the server assigns receive time.
- Every 1.5 seconds, `GET /api/dispense-queue?machineId=1` reads a JSON array. For each row containing `OrderItemId`, the sketch moves the servo and posts `{"result":"SUCCESS"}` to `/api/orders/items/:itemId/dispense`.
- This sketch always reports `SUCCESS` after its placeholder movement. It has no motor feedback or jam sensor; actual hardware needs feedback logic and must report `JAM` with an `errorCode` where appropriate.

The reference uses HTTP for compatibility with the local simulator setup. Use TLS or a secured gateway and a device credential strategy before sending secrets over an untrusted network. This sketch skips failed DHT reads and does not persist telemetry offline or retry dispense reports.

## Arduino IDE 2: install libraries and Verify

1. Install Arduino IDE 2 and add Espressif's ESP32 board package through Boards Manager, following the current Arduino IDE instructions.
2. Select **Tools → Board → esp32 → ESP32 Dev Module**. Upload/serial port selection is not required just to compile.
3. Open **Tools → Manage Libraries** and install **ArduinoJson** (v7), **DHT sensor library** by Adafruit, **Adafruit Unified Sensor** (dependency), and **ESP32Servo**.
4. Open `firmware/esp32_freshvend/esp32_freshvend.ino`, set configuration constants as needed, then click **Verify** (✓). A successful Verify only confirms compilation for the selected board/library versions; it does not validate wiring, Wi-Fi, API connectivity, real sensor readings, or dispensing mechanics.

For tested system behavior, continue to use `node app/simulator/esp32.js`. This firmware remains an untested hardware reference until separately compiled, flashed, and exercised on the actual hardware.
