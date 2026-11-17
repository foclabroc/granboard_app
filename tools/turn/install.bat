@echo off
rem Installe le relais TURN de Foclaboard (a lancer en administrateur).
rem Lancement automatique au demarrage de Windows + ouverture du pare-feu.
cd /d "%~dp0"
net session >nul 2>&1
if errorlevel 1 (
  echo Clic droit sur install.bat puis "Executer en tant qu'administrateur".
  pause
  exit /b 1
)
if not exist "%~dp0foclaboard-turn.exe" (
  echo foclaboard-turn.exe introuvable a cote de install.bat.
  pause
  exit /b 1
)
echo Pare-feu Windows...
netsh advfirewall firewall delete rule name="Foclaboard TURN" >nul 2>&1
netsh advfirewall firewall add rule name="Foclaboard TURN" dir=in action=allow program="%~dp0foclaboard-turn.exe" enable=yes >nul
netsh advfirewall firewall add rule name="Foclaboard TURN" dir=in action=allow protocol=UDP localport=3478,49152-49251 enable=yes >nul
netsh advfirewall firewall add rule name="Foclaboard TURN" dir=in action=allow protocol=TCP localport=3478 enable=yes >nul
echo Tache au demarrage...
schtasks /end /tn "Foclaboard TURN" >nul 2>&1
schtasks /create /tn "Foclaboard TURN" /tr "\"%~dp0foclaboard-turn.exe\"" /sc onstart /ru SYSTEM /rl HIGHEST /f >nul
if errorlevel 1 (
  echo Echec de la creation de la tache.
  pause
  exit /b 1
)
schtasks /run /tn "Foclaboard TURN" >nul
timeout /t 3 /nobreak >nul
echo Test du relais...
start "" /wait "%~dp0foclaboard-turn.exe" -test
type "%~dp0turn-test.txt"
echo.
echo Journal : %~dp0turn.log
pause
