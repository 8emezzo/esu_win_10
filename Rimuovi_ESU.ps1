param (
    [Parameter()]
    [switch]
    $Conferma
)

[bool]$cmdps = $MyInvocation.InvocationName -EQ "&"

function CONOUT($strObj)
{
    Out-Host -Input $strObj
}

function ExitScript($ExitCode = 0)
{
    if (!$psISE -And $cmdps) {
        Read-Host "`r`nPremi Invio per uscire" | Out-Null
    }
    Exit $ExitCode
}

if (-Not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    CONOUT "==== ERRORE ====`r`n"
    CONOUT "PowerShell non e' in esecuzione come amministratore."
    ExitScript 1
}

$SysPath = "$env:SystemRoot\System32"
if (Test-Path "$env:SystemRoot\Sysnative\reg.exe") {
    $SysPath = "$env:SystemRoot\Sysnative"
}

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnrollmentScript = Join-Path $ScriptPath "Consumer_ESU_Enrollment.ps1"

$Stati = @{
    0 = "Non Definito";
    1 = "Non Idoneo";
    2 = "Idoneo";
    3 = "Dispositivo Iscritto";
    4 = "Ri-iscrizione Richiesta";
    5 = "Iscritto con Account Microsoft";
}

CONOUT "`n=========================================="
CONOUT "      RIMOZIONE ESU WINDOWS 10"
CONOUT "==========================================`n"

# Verifica prerequisiti
if (!(Test-Path "$SysPath\ConsumerESUMgr.dll")) {
    CONOUT "[X] ConsumerESUMgr.dll non rilevata."
    CONOUT "    Sistema non configurato per ESU."
    ExitScript 1
}

# Fase 1: Controllo stato attuale
CONOUT "FASE 1: Controllo stato ESU attuale..."
CONOUT "------------------------------------------"

& $SysPath\cmd.exe '/c' $SysPath\ClipESUConsumer.exe -evaluateEligibility 2>$null | Out-Null

$esuKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows\ConsumerESU"
$esuStatus = $null
$esuResult = $null

if (Test-Path $esuKey) {
    $esuStatus = (Get-ItemProperty $esuKey "ESUEligibility" -ErrorAction SilentlyContinue).ESUEligibility
    $esuResult = (Get-ItemProperty $esuKey "ESUEligibilityResult" -ErrorAction SilentlyContinue).ESUEligibilityResult
}

$licenzaKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform\Licenses\Professional\ConsumerESU"
$licenzaPresente = Test-Path $licenzaKey

if ($null -ne $esuStatus) {
    $statoDesc = if ($Stati.ContainsKey($esuStatus)) { $Stati[$esuStatus] } else { "Sconosciuto ($esuStatus)" }
    CONOUT "Stato attuale: $statoDesc"
    
    if ($esuStatus -eq 1 -or $esuStatus -eq 2) {
        CONOUT "`n[!] ESU non e' attualmente attivo su questo PC"
        if (!$licenzaPresente) {
            CONOUT "    Non c'e' nulla da rimuovere."
            ExitScript 0
        }
    } elseif ($esuStatus -eq 3 -or $esuStatus -eq 5) {
        CONOUT "`n[!] ESU e' attualmente ATTIVO su questo PC"
        CONOUT "    Gli aggiornamenti estesi sono attivi fino al 13 ottobre 2026"
    }
} else {
    CONOUT "Stato ESU: Non determinato"
}

if ($licenzaPresente) {
    CONOUT "Licenza ESU: PRESENTE nel sistema"
} else {
    CONOUT "Licenza ESU: Non presente"
}

# Conferma rimozione
if (!$Conferma) {
    CONOUT "`n=========================================="
    CONOUT "          ATTENZIONE!"
    CONOUT "=========================================="
    CONOUT ""
    CONOUT "Stai per rimuovere ESU da questo PC."
    CONOUT "Dopo la rimozione:"
    CONOUT "- Non riceverai piu' aggiornamenti di sicurezza estesi"
    CONOUT "- Il supporto terminera' il 14 ottobre 2025"
    CONOUT ""
    CONOUT "Per confermare la rimozione, esegui:"
    CONOUT "  .\Rimuovi_ESU.ps1 -Conferma"
    CONOUT ""
    CONOUT "oppure rispondi alla domanda seguente:"
    CONOUT ""
    
    $risposta = Read-Host "Vuoi davvero rimuovere ESU? (si/no)"
    if ($risposta -ne "si" -and $risposta -ne "s") {
        CONOUT "`nRimozione annullata."
        ExitScript 0
    }
}

# Fase 2: Rimozione tramite script ufficiale
CONOUT "`n`nFASE 2: Rimozione licenza ESU..."
CONOUT "------------------------------------------"

if (Test-Path $EnrollmentScript) {
    CONOUT "Utilizzo script ufficiale per la rimozione..."
    
    # Esegui lo script con parametro -Remove
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $EnrollmentScript -Remove
    
    Start-Sleep -Seconds 2
} else {
    CONOUT "[!] Script Consumer_ESU_Enrollment.ps1 non trovato."
    CONOUT "    Procedo con rimozione manuale..."
}

# Fase 3: Rimozione manuale chiavi registro
CONOUT "`n`nFASE 3: Pulizia registro di sistema..."
CONOUT "------------------------------------------"

# Rimuovi chiavi utente ESU
if (Test-Path $esuKey) {
    try {
        Remove-Item -Path $esuKey -Recurse -Force -ErrorAction Stop
        CONOUT "[OK] Rimosse chiavi registro utente ESU"
    } catch {
        CONOUT "[!] Impossibile rimuovere chiavi utente: $_"
    }
} else {
    CONOUT "[OK] Chiavi utente ESU gia' assenti"
}

# Rimuovi feature override se presente
$featureKey = "HKLM:\SYSTEM\CurrentControlSet\Policies\Microsoft\FeatureManagement\Overrides"
if (Test-Path $featureKey) {
    $featureValue = Get-ItemProperty $featureKey -Name "4011992206" -ErrorAction SilentlyContinue
    if ($featureValue."4011992206") {
        try {
            Remove-ItemProperty -Path $featureKey -Name "4011992206" -Force -ErrorAction Stop
            CONOUT "[OK] Rimosso override feature ESU"
        } catch {
            CONOUT "[!] Impossibile rimuovere override feature: $_"
        }
    }
}

# Disabilita task scheduler ESU se presente
CONOUT "`nDisabilitazione task scheduler ESU..."
$taskPath = "\Microsoft\Windows\Clip\"
$taskName = "ClipESUConsumer"

try {
    $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
    if ($task) {
        if ($task.State -ne "Disabled") {
            Disable-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction Stop | Out-Null
            CONOUT "[OK] Task scheduler ESU disabilitato"
        } else {
            CONOUT "[OK] Task scheduler ESU gia' disabilitato"
        }
    } else {
        CONOUT "[OK] Task scheduler ESU non presente"
    }
} catch {
    CONOUT "[!] Impossibile disabilitare task scheduler: $_"
}

# Fase 4: Verifica finale
CONOUT "`n`nFASE 4: Verifica rimozione..."
CONOUT "------------------------------------------"

Start-Sleep -Seconds 2

# Ricontrolla stato
& $SysPath\cmd.exe '/c' $SysPath\ClipESUConsumer.exe -evaluateEligibility 2>$null | Out-Null

$esuStatus = $null
if (Test-Path $esuKey) {
    $esuStatus = (Get-ItemProperty $esuKey "ESUEligibility" -ErrorAction SilentlyContinue).ESUEligibility
}

$licenzaPresente = Test-Path $licenzaKey

$rimozioneCompleta = $true

if ($licenzaPresente) {
    CONOUT "[!] Licenza ESU ancora presente nel sistema"
    $rimozioneCompleta = $false
} else {
    CONOUT "[OK] Licenza ESU rimossa"
}

if ($null -ne $esuStatus -and ($esuStatus -eq 3 -or $esuStatus -eq 5)) {
    CONOUT "[!] ESU sembra ancora attivo"
    $rimozioneCompleta = $false
} else {
    CONOUT "[OK] Stato ESU non attivo"
}

CONOUT "`n=========================================="
if ($rimozioneCompleta) {
    CONOUT "    RIMOZIONE COMPLETATA CON SUCCESSO"
    CONOUT "=========================================="
    CONOUT ""
    CONOUT "ESU e' stato rimosso dal sistema."
    CONOUT "Il PC non ricevera' piu' aggiornamenti estesi."
    CONOUT ""
    CONOUT "Supporto Windows 10 termina: 14 ottobre 2025"
} else {
    CONOUT "      RIMOZIONE PARZIALE"
    CONOUT "=========================================="
    CONOUT ""
    CONOUT "Alcuni componenti ESU potrebbero essere ancora presenti."
    CONOUT "Potrebbe essere necessario:"
    CONOUT "- Riavviare il sistema"
    CONOUT "- Eseguire nuovamente questo script dopo il riavvio"
}
CONOUT "=========================================="

ExitScript 0