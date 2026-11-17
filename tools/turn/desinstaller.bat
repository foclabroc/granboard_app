@echo off
rem Arrete et retire le relais TURN de Foclaboard (a lancer en administrateur).
schtasks /end /tn "Foclaboard TURN" >nul 2>&1
schtasks /delete /tn "Foclaboard TURN" /f >nul 2>&1
taskkill /im foclaboard-turn.exe /f >nul 2>&1
netsh advfirewall firewall delete rule name="Foclaboard TURN" >nul 2>&1
echo Relais TURN retire.
pause
