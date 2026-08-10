require_wifi_credentials() {
  if [ -z "${ESP_WIFI_SSID:-}" ] || [ -z "${ESP_WIFI_PASSWORD:-}" ]; then
    echo "config/wifi.env missing" >&2
    exit 1
  fi
}
