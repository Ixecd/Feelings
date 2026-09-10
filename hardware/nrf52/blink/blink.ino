// blink.ino — nRF52832 工具链/烧录/串口验证
// BSP: adafruit:nrf52:feather52832
// nRF52832 上硬件 UART 就叫 Serial：TX=P0.06(GPIO6), RX=P0.08(GPIO8)
void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  Serial.begin(115200);
  Serial.println("nrf52832 alive");
}

void loop() {
  digitalWrite(LED_BUILTIN, HIGH);
  Serial.println("tick");
  delay(200);
  digitalWrite(LED_BUILTIN, LOW);
  delay(800);
}
