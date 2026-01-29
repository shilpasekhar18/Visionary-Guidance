#include <WebServer.h>
#include <WiFi.h>
#include <esp32cam.h>
#include <ESPmDNS.h>

const char* WIFI_SSID = "JioFi_21549E7";
const char* WIFI_PASS = "kycqhf42j7";

WebServer server(80);

static auto loRes = esp32cam::Resolution::find(320, 240);
static auto midRes = esp32cam::Resolution::find(350, 530);
static auto hiRes = esp32cam::Resolution::find(800, 600);

void serveJpg()
{
  auto frame = esp32cam::capture();
  if (frame == nullptr) {
    Serial.println("CAPTURE FAIL");
    server.send(503, "", "");
    return;
  }

  server.setContentLength(frame->size());
  server.send(200, "image/jpeg");
  WiFiClient client = server.client();
  frame->writeTo(client);
}

void handleJpgLo()
{
  esp32cam::Camera.changeResolution(loRes);
  serveJpg();
}

void handleJpgHi()
{
  esp32cam::Camera.changeResolution(hiRes);
  serveJpg();
}

void handleJpgMid()
{
  esp32cam::Camera.changeResolution(midRes);
  serveJpg();
}

void setup()
{
  Serial.begin(115200);

  using namespace esp32cam;
  Config cfg;
  cfg.setPins(pins::AiThinker);
  cfg.setResolution(loRes);
  cfg.setBufferCount(2);
  cfg.setJpeg(80);

  Camera.begin(cfg);

  WiFi.begin(WIFI_SSID, WIFI_PASS);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }

  MDNS.begin("espcam");

  server.on("/cam-lo.jpg", handleJpgLo);
  server.on("/cam-hi.jpg", handleJpgHi);
  server.on("/cam-mid.jpg", handleJpgMid);

  server.begin();
}

void loop()
{
  server.handleClient();
}
