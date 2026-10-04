@echo off
set LOG=C:\radar\run.log
set LOCK=C:\radar\run.lock

rem Supprimer un verrou de plus d'un jour (reste d'un plantage)
forfiles /p C:\radar /m run.lock /d -1 /c "cmd /c del @path" >nul 2>&1

rem Ne pas lancer deux instances en meme temps
if exist %LOCK% (
  echo [%date% %time%] deja en cours, abandon >> %LOG%
  exit /b 0
)
echo %date% %time% > %LOCK%

echo [%date% %time%] start >> %LOG%

rem 1. Demarrer Docker Desktop s'il ne tourne pas
tasklist | find /i "Docker Desktop.exe" >nul || start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"

rem 2. Attendre que le moteur Docker reponde (5 minutes max)
set /a n=0
:waitdocker
docker info >nul 2>&1 && goto dockerok
set /a n+=1
if %n% GEQ 60 (echo [%date% %time%] docker timeout >> %LOG% & goto cleanup)
ping -n 6 127.0.0.1 >nul
goto waitdocker
:dockerok

rem 3. Creer et demarrer n8n (les donnees restent dans le volume n8n_data)
docker rm -f n8n >nul 2>&1
docker run -d --rm --name n8n -p 127.0.0.1:5678:5678 -v n8n_data:/home/node/.n8n -e "NODES_EXCLUDE=[]" -e GENERIC_TIMEZONE=Africa/Casablanca -e TZ=Africa/Casablanca n8nio/n8n >> %LOG% 2>&1

rem 4. Declencher le workflow (reessaie jusqu'a ce que n8n soit pret, 5 minutes max)
set /a k=0
:callhook
curl -fsS -X POST http://localhost:5678/webhook/run-radar >> %LOG% 2>&1 && goto called
set /a k+=1
if %k% GEQ 30 (echo [%date% %time%] webhook failed >> %LOG% & goto cleanup)
ping -n 11 127.0.0.1 >nul
goto callhook
:called
echo [%date% %time%] workflow triggered >> %LOG%

rem 5. Laisser le temps au workflow de finir (15 minutes)
powershell -NoProfile -Command "Start-Sleep -Seconds 900"

:cleanup
docker stop n8n >> %LOG% 2>&1
taskkill /IM "Docker Desktop.exe" /F >nul 2>&1
wsl --shutdown
del %LOCK% >nul 2>&1
echo [%date% %time%] done >> %LOG%