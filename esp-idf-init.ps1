# ESP-IDF v5.5.3 initialization for DingDong firmware sessions
# Usage: . .\esp-idf-init.ps1 (note the dot-space before the path)

$env:IDF_PATH = "C:\Espressif\frameworks\esp-idf-v5.5.3"
. C:\Espressif\frameworks\esp-idf-v5.5.3\export.ps1
Write-Host "ESP-IDF v5.5.3 ready." -ForegroundColor Green
Write-Host "cd to firmware/ and run: idf.py build" -ForegroundColor Green