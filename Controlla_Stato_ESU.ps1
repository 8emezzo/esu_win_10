param (
    [Parameter()]
    [switch]
    $Dettagli,
    [Parameter()]
    [switch]
    $Report,
    [Parameter()]
    [switch]
    $NoColori
)

[bool]$cmdps = $MyInvocation.InvocationName -EQ "&"

function CONOUT($strObj, $Color = "White")
{
    if ($NoColori) {
        Out-Host -Input $strObj
    } else {
        Write-Host $strObj -ForegroundColor $Color
    }
}

function ExitScript($ExitCode = 0)
{
    if (!$psISE -And $cmdps) {
        Read-Host "`r`nPremi Invio per uscire" | Out-Null
    }
    Exit $ExitCode
}

if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    CONOUT "==== ERRORE ====`r`n" "Red"
    CONOUT "PowerShell non e' in esecuzione come amministratore." "Yellow"
    ExitScript 1
}

$SysPath = "$env:SystemRoot\System32"
if (Test-Path "$env:SystemRoot\Sysnative\reg.exe") {
    $SysPath = "$env:SystemRoot\Sysnative"
}

$Stati = @{
    0 = "Non Definito";
    1 = "Non Idoneo";
    2 = "Idoneo";
    3 = "Dispositivo Iscritto";
    4 = "Ri-iscrizione Richiesta";
    5 = "Iscritto con Account Microsoft";
}

$Risultati = @{
    0 = "SUCCESSO";
    1 = "ERRORE";
    2 = "Sospeso";
    3 = "Sistema Non Supportato";
    4 = "Non Idoneo";
    5 = "Edizione Non Supportata";
    6 = "Feature ESU Non Attiva";
    7 = "Connessione Internet Richiesta";
    8 = "Account Microsoft Richiesto";
    9 = "In Attesa";
    10 = "Iscrizione Richiesta";
    11 = "Non Definito";
}

$reportContent = @()
$reportContent += "====== REPORT STATO ESU WINDOWS 10 ======"
$reportContent += "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$reportContent += ""

Clear-Host
CONOUT "`n====================================" "Cyan"
CONOUT "    CONTROLLO STATO ESU" "Cyan"
CONOUT "====================================" "Cyan"
CONOUT ""

# 1. Informazioni Sistema
CONOUT "[1/8] INFORMAZIONI SISTEMA" "Yellow"
CONOUT "------------------------------------------" "Gray"

$buildInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$winVer = $buildInfo.DisplayVersion
$buildNum = $buildInfo.CurrentBuildNumber
$ubr = $buildInfo.UBR
$productName = $buildInfo.ProductName

CONOUT "Sistema:  $productName"
CONOUT "Versione: $winVer"
CONOUT "Build:    $buildNum.$ubr"

$reportContent += "SISTEMA:"
$reportContent += "- $productName"
$reportContent += "- Versione: $winVer"
$reportContent += "- Build: $buildNum.$ubr"

if ($buildNum -eq "19045") {
    if ($ubr -ge 6036) {
        CONOUT "`n[OK] Build compatibile con ESU" "Green"
    } else {
        CONOUT "`n[!] Build troppo vecchia per ESU" "Yellow"
        CONOUT "    Richiesta minima: 19045.6036" "Yellow"
        CONOUT "    Installare KB5061087 o successivo" "Yellow"
    }
} else {
    CONOUT "`n[X] Versione Windows non compatibile" "Red"
    CONOUT "    Richiesto Windows 10 22H2" "Red"
}
CONOUT ""

# 2. Componenti ESU
CONOUT "[2/8] COMPONENTI ESU" "Yellow"
CONOUT "------------------------------------------" "Gray"

$componentiOK = $true

if (Test-Path "$SysPath\ConsumerESUMgr.dll") {
    CONOUT "[OK] ConsumerESUMgr.dll presente" "Green"
    
    # Verifica versione DLL
    try {
        $dllInfo = Get-Item "$SysPath\ConsumerESUMgr.dll" -ErrorAction SilentlyContinue
        if ($dllInfo) {
            $dllVersion = $dllInfo.VersionInfo.FileVersion
            CONOUT "     Versione: $dllVersion" "Gray"
            $reportContent += "- ConsumerESUMgr.dll: PRESENTE (v$dllVersion)"
        }
    } catch {
        $reportContent += "- ConsumerESUMgr.dll: PRESENTE"
    }
} else {
    CONOUT "[X] ConsumerESUMgr.dll NON rilevata" "Red"
    CONOUT "    Installare KB5061087 o successivo" "Yellow"
    $componentiOK = $false
    $reportContent += "- ConsumerESUMgr.dll: MANCANTE"
}

if (Test-Path "$SysPath\ClipESUConsumer.exe") {
    CONOUT "[OK] ClipESUConsumer.exe presente" "Green"
    $reportContent += "- ClipESUConsumer.exe: PRESENTE"
} else {
    CONOUT "[X] ClipESUConsumer.exe NON trovato" "Red"
    $componentiOK = $false
    $reportContent += "- ClipESUConsumer.exe: MANCANTE"
}
CONOUT ""

# 3. Feature ESU
CONOUT "[3/8] STATO FEATURE ESU" "Yellow"
CONOUT "------------------------------------------" "Gray"

$featureOverride = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides" -Name "4011992206" -ErrorAction SilentlyContinue
if ($featureOverride."4011992206" -eq 2) {
    CONOUT "[OK] Feature ESU ABILITATA" "Green"
    $reportContent += "- Feature ESU: ABILITATA"
} else {
    CONOUT "[X] Feature ESU NON abilitata" "Red"
    CONOUT "    Lo script di attivazione la abilitera'" "Yellow"
    $reportContent += "- Feature ESU: NON ABILITATA"
}
CONOUT ""

# 4. Valutazione stato ESU
CONOUT "[4/8] STATO REGISTRAZIONE ESU" "Yellow"
CONOUT "------------------------------------------" "Gray"

if ($componentiOK) {
    CONOUT "Valutazione stato in corso..." "Gray"
    & $SysPath\cmd.exe '/c' $SysPath\ClipESUConsumer.exe -evaluateEligibility 2>$null | Out-Null
}

$esuKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows\ConsumerESU"
$esuStatus = $null
$esuResult = $null
$esuActive = "NO"

if (Test-Path $esuKey) {
    $esuStatus = (Get-ItemProperty $esuKey "ESUEligibility" -ErrorAction SilentlyContinue).ESUEligibility
    $esuResult = (Get-ItemProperty $esuKey "ESUEligibilityResult" -ErrorAction SilentlyContinue).ESUEligibilityResult
}

if ($null -ne $esuStatus) {
    $statoDesc = if ($Stati.ContainsKey($esuStatus)) { $Stati[$esuStatus] } else { "Sconosciuto ($esuStatus)" }
    CONOUT "Stato: $statoDesc"
    $reportContent += "- Stato ESU: $statoDesc"
    
    if ($esuStatus -eq 3) {
        CONOUT "`n[OK] PC REGISTRATO CON SUCCESSO" "Green"
        CONOUT "     Aggiornamenti attivi fino al 13/10/2026" "Green"
        $esuActive = "YES"
    } elseif ($esuStatus -eq 5) {
        CONOUT "`n[OK] PC REGISTRATO CON ACCOUNT MICROSOFT" "Green"
        CONOUT "     Aggiornamenti attivi fino al 13/10/2026" "Green"
        $esuActive = "YES"
    } elseif ($esuStatus -eq 4) {
        CONOUT "`n[!] RICHIESTA NUOVA REGISTRAZIONE" "Yellow"
        CONOUT "    Eseguire script di attivazione" "Yellow"
        $esuActive = "PARTIAL"
    } elseif ($esuStatus -eq 2) {
        CONOUT "`n[!] PC IDONEO MA NON REGISTRATO" "Yellow"
        CONOUT "    Eseguire script di attivazione" "Yellow"
        $esuActive = "PARTIAL"
    } elseif ($esuStatus -eq 1) {
        CONOUT "`n[X] PC NON IDONEO PER ESU" "Red"
        $esuActive = "NO"
    } else {
        CONOUT "`n[?] STATO NON DEFINITO" "Gray"
        $esuActive = "UNKNOWN"
    }
} else {
    CONOUT "Stato: Non disponibile" "Red"
    CONOUT "`n[X] Nessuna registrazione ESU trovata" "Red"
    $reportContent += "- Stato ESU: NON REGISTRATO"
}

if ($null -ne $esuResult) {
    $risultatoDesc = if ($Risultati.ContainsKey($esuResult)) { $Risultati[$esuResult] } else { "Sconosciuto ($esuResult)" }
    CONOUT "Risultato: $risultatoDesc" "Gray"
    $reportContent += "- Risultato: $risultatoDesc"
}
CONOUT ""

# 5. Licenza ESU
CONOUT "[5/8] LICENZA ESU" "Yellow"
CONOUT "------------------------------------------" "Gray"

$licenzaKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform\Licenses\Professional\ConsumerESU"
if (Test-Path $licenzaKey) {
    CONOUT "[OK] Licenza ESU presente nel registro" "Green"
    $reportContent += "- Licenza registro: PRESENTE"
} else {
    CONOUT "[X] Licenza ESU non presente nel registro" "Red"
    $reportContent += "- Licenza registro: NON PRESENTE"
}

# Verifica pacchetto AppX
try {
    $appxPackage = Get-AppxPackage -Name "*ConsumerExtendedSecurityUpdates*" -AllUsers -ErrorAction SilentlyContinue
    if ($appxPackage) {
        CONOUT "[OK] Pacchetto ESU installato" "Green"
        CONOUT "     Package: $($appxPackage.PackageFullName)" "Gray"
        $reportContent += "- Pacchetto AppX: INSTALLATO"
    } else {
        CONOUT "[X] Pacchetto ESU non trovato" "Red"
        $reportContent += "- Pacchetto AppX: NON TROVATO"
    }
} catch {
    CONOUT "[!] Impossibile verificare pacchetto AppX" "Yellow"
}
CONOUT ""

# 6. Task Scheduler
CONOUT "[6/8] TASK SCHEDULER ESU" "Yellow"
CONOUT "------------------------------------------" "Gray"

try {
    $task = Get-ScheduledTask -TaskPath "\Microsoft\Windows\Clip\" -TaskName "ClipESUConsumer" -ErrorAction SilentlyContinue
    if ($task) {
        CONOUT "[OK] Task ClipESUConsumer presente" "Green"
        CONOUT "     Stato: $($task.State)" "Gray"
        $reportContent += "- Task Scheduler: PRESENTE ($($task.State))"
        
        if ($task.State -eq "Disabled") {
            CONOUT "     [!] Task disabilitato" "Yellow"
        }
    } else {
        CONOUT "[X] Task ClipESUConsumer non trovato" "Red"
        $reportContent += "- Task Scheduler: NON TROVATO"
    }
} catch {
    CONOUT "[!] Impossibile verificare task scheduler" "Yellow"
}
CONOUT ""

# 7. Windows Update
CONOUT "[7/8] STATO WINDOWS UPDATE" "Yellow"
CONOUT "------------------------------------------" "Gray"

try {
    $wuKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Detect"
    if (Test-Path $wuKey) {
        $lastCheck = (Get-ItemProperty $wuKey "LastSuccessTime" -ErrorAction SilentlyContinue).LastSuccessTime
        if ($lastCheck) {
            CONOUT "Ultima verifica: $lastCheck"
            $reportContent += "- Ultima verifica WU: $lastCheck"
        }
    }
    
    # Ultimi aggiornamenti ESU installati
    CONOUT "`nUltimi aggiornamenti installati:" "Gray"
    $updates = Get-HotFix | Where-Object { $_.Description -like "*Security*" -and $_.InstalledOn } | 
               Sort-Object InstalledOn -Descending | Select-Object -First 3
    
    foreach ($update in $updates) {
        $data = $update.InstalledOn.ToString("yyyy-MM-dd")
        CONOUT "  $($update.HotFixID) - $data" "Gray"
    }
} catch {
    CONOUT "[!] Impossibile verificare Windows Update" "Yellow"
}
CONOUT ""

# 8. Riepilogo finale
CONOUT "[8/8] RIEPILOGO FINALE" "Yellow"
CONOUT "==========================================" "Cyan"
CONOUT ""

if ($esuActive -eq "YES") {
    CONOUT "[SUCCESS] ESU COMPLETAMENTE ATTIVO!" "Green"
    CONOUT "" 
    CONOUT "Il PC ricevera' aggiornamenti di sicurezza" "Green"
    CONOUT "fino al 13 OTTOBRE 2026" "Green"
    $reportContent += ""
    $reportContent += "RISULTATO: ESU ATTIVO - Aggiornamenti fino al 13/10/2026"
} elseif ($esuActive -eq "PARTIAL") {
    CONOUT "[ATTENZIONE] ESU PARZIALMENTE CONFIGURATO" "Yellow"
    CONOUT ""
    CONOUT "Eseguire lo script di attivazione per completare" "Yellow"
    $reportContent += ""
    $reportContent += "RISULTATO: ESU PARZIALE - Richiede completamento"
} elseif ($esuActive -eq "NO") {
    CONOUT "[INFO] ESU NON ATTIVO" "Red"
    CONOUT ""
    CONOUT "Aggiornamenti solo fino al 14/10/2025" "Yellow"
    CONOUT "Eseguire script di attivazione per estendere" "Yellow"
    $reportContent += ""
    $reportContent += "RISULTATO: ESU NON ATTIVO - Supporto termina 14/10/2025"
} else {
    CONOUT "[?] STATO ESU NON DETERMINATO" "Gray"
    $reportContent += ""
    $reportContent += "RISULTATO: STATO NON DETERMINATO"
}

CONOUT ""
CONOUT "==========================================" "Cyan"
CONOUT ""

# Salva report se richiesto
if ($Report) {
    $reportFile = "ESU_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $reportContent += ""
    $reportContent += "=========================================="
    $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
    CONOUT "Report salvato in: $reportFile" "Green"
    CONOUT ""
}

# Menu interattivo
if (!$Report) {
    CONOUT "Opzioni disponibili:" "White"
    CONOUT "[1] Esci" "Gray"
    CONOUT "[2] Genera report dettagliato" "Gray"
    CONOUT "[3] Apri Windows Update" "Gray"
    CONOUT "[4] Esegui script di attivazione" "Gray"
    CONOUT ""
    
    $scelta = Read-Host "Scegli opzione (1-4)"
    
    switch ($scelta) {
        "2" {
            $reportFile = "ESU_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
            $reportContent += ""
            $reportContent += "=========================================="
            $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
            CONOUT "`nReport salvato in: $reportFile" "Green"
            Start-Sleep -Seconds 2
        }
        "3" {
            CONOUT "`nApertura Windows Update..." "Gray"
            Start-Process "ms-settings:windowsupdate"
        }
        "4" {
            $activationScript = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) "Attiva_ESU_Automatico.ps1"
            if (Test-Path $activationScript) {
                CONOUT "`nAvvio script di attivazione..." "Gray"
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $activationScript
            } else {
                CONOUT "`nScript di attivazione non trovato!" "Red"
                Start-Sleep -Seconds 2
            }
        }
    }
}

ExitScript 0