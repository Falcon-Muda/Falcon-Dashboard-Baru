@echo off
title SIMIN-INTEL — Shutdown
color 0C

echo.
echo  ======================================================
echo   SIMIN-INTEL — Mematikan Semua Layanan
echo  ======================================================
echo.
echo  Menghentikan Docker containers...
cd /d "%~dp0platform-main"
docker compose down

echo.
echo  Semua layanan berhasil dimatikan.
echo  Data tersimpan dengan aman di database.
echo.
pause
