// findpin.ino — 只在 P0.06(Arduino 脚6) 输出 0.25Hz 慢方波(2s 高/2s 低)
// 用万用表盯着候选针：读数在 0V↔3.3V 之间慢慢变的，就是 P0.06
void setup() {
  pinMode(6, OUTPUT);
}

void loop() {
  digitalWrite(6, HIGH);
  delay(2000);
  digitalWrite(6, LOW);
  delay(2000);
}
