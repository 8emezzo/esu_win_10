@echo off
set "_PSf=%~dp0Controlla_Stato_ESU.ps1"
setlocal EnableDelayedExpansion
set "_PSf=!_PSf:'=''!"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command ^& "'!_PSf!' %*"