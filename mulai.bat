@echo off
title SIMIN-INTEL — Starter
color 0A

echo.
echo  ======================================================
echo   SIMIN-INTEL — Sistem Monitoring Intelijen
echo  ======================================================
echo.
echo  [1/3] Masuk ke folder platform...
cd /d "%~dp0platform-main"

echo  [2/3] Menyalakan semua layanan (Docker)...
docker compose up -d

echo.
echo  [3/3] Menunggu sistem siap...
timeout /t 5 /nobreak >nul

echo.
echo  ======================================================
echo   SISTEM SIAP!
echo.
echo   Buka browser dan akses:
echo   http://localhost:8000
echo.
echo   Login:
echo   Email    : admin@simin.intel
echo   Password : simin2026
echo  ======================================================
echo.
pause
