param (
    [Parameter()]
    [switch]
    $SoloControllo,
    [Parameter()]
    [switch]
    $Forza
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
$MarkerFile = Join-Path $env:TEMP "ESU_FirstRun.marker"

$Stati = @{
    0 = "Non Definito";
    1 = "Non Idoneo";
    2 = "Idoneo";
    3 = "Dispositivo Iscritto";
    4 = "Ri-iscrizione Richiesta";
    5 = "Iscritto con Account Microsoft";
}

CONOUT "`n=========================================="
CONOUT "   ATTIVAZIONE AUTOMATICA ESU WINDOWS 10"
CONOUT "==========================================`n"

# Verifica prerequisiti
if (!(Test-Path "$SysPath\ConsumerESUMgr.dll")) {
    CONOUT "[X] ConsumerESUMgr.dll non rilevata."
    CONOUT "    Assicurati di installare l'aggiornamento 2025-07 KB5061087 (19045.6036) o successivo."
    ExitScript 1
}

if (!(Test-Path $EnrollmentScript)) {
    CONOUT "[X] Script Consumer_ESU_Enrollment.ps1 non trovato."
    CONOUT "    Assicurati che sia presente nella stessa cartella di questo script."
    ExitScript 1
}

CONOUT "[OK] Prerequisiti verificati`n"

# Fase 1: Controllo stato attuale
CONOUT "FASE 1: Controllo stato ESU attuale..."
CONOUT "------------------------------------------"

& $SysPath\cmd.exe '/c' $SysPath\ClipESUConsumer.exe -evaluateEligibility 2>$null | Out-Null

$esuKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows\ConsumerESU"
$esuStatus = $null

if (Test-Path $esuKey) {
    $esuStatus = (Get-ItemProperty $esuKey "ESUEligibility" -ErrorAction SilentlyContinue).ESUEligibility
}

if ($null -ne $esuStatus) {
    $statoDesc = if ($Stati.ContainsKey($esuStatus)) { $Stati[$esuStatus] } else { "Sconosciuto ($esuStatus)" }
    CONOUT "Stato attuale: $statoDesc"
    
    if ($esuStatus -eq 3 -and !$Forza) {
        CONOUT "`n[OK] IL PC E' GIA' ISCRITTO AL PROGRAMMA ESU!"
        CONOUT "     Gli aggiornamenti di sicurezza sono gia' attivi fino al 13 ottobre 2026"
        CONOUT "`n     Se vuoi ri-iscrivere comunque, usa il parametro -Forza"
        ExitScript 0
    } elseif ($esuStatus -eq 5 -and !$Forza) {
        CONOUT "`n[OK] IL PC E' GIA' ISCRITTO CON ACCOUNT MICROSOFT!"
        CONOUT "     Gli aggiornamenti di sicurezza sono gia' attivi fino al 13 ottobre 2026"
        CONOUT "`n     Se vuoi ri-iscrivere comunque, usa il parametro -Forza"
        ExitScript 0
    } elseif ($esuStatus -eq 1) {
        CONOUT "`n[X] IL PC NON E' IDONEO PER ESU"
        CONOUT "    Non e' possibile attivare gli aggiornamenti estesi su questo sistema."
        ExitScript 1
    } elseif ($esuStatus -eq 2 -or $esuStatus -eq 4 -or $Forza) {
        if ($esuStatus -eq 2) {
            CONOUT "`n[!] Il PC e' IDONEO ma non ancora iscritto"
        } elseif ($esuStatus -eq 4) {
            CONOUT "`n[!] E' richiesta una RI-ISCRIZIONE"
        } elseif ($Forza) {
            CONOUT "`n[!] Forzatura ri-iscrizione richiesta"
        }
        
        if ($SoloControllo) {
            CONOUT "`nModalita' solo controllo attiva. Esegui senza -SoloControllo per procedere con l'attivazione."
            ExitScript 0
        }
    }
} else {
    CONOUT "Stato ESU non determinato. Tentativo di attivazione in corso..."
}

# Fase 2: Prima esecuzione (attivazione feature)
CONOUT "`n`nFASE 2: Attivazione funzionalita' ESU..."
CONOUT "------------------------------------------"

# Controlla se e' la prima esecuzione
$primaEsecuzione = !(Test-Path $MarkerFile)

if ($primaEsecuzione) {
    CONOUT "Prima esecuzione - Attivazione feature ESU in corso..."
    
    # Esegui lo script di enrollment
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $EnrollmentScript
    
    # Crea il marker file
    New-Item -Path $MarkerFile -ItemType File -Force | Out-Null
    
    CONOUT "`n[!] Feature ESU attivata!"
    CONOUT "    Chiudi questa finestra e riesegui lo script per completare l'iscrizione."
    CONOUT "`n    IMPORTANTE: Dopo aver chiuso questa finestra,"
    CONOUT "    esegui nuovamente Attiva_ESU_Automatico_run.cmd come amministratore"
    
    ExitScript 0
} else {
    # Seconda esecuzione - procedi con l'iscrizione
    CONOUT "Seconda esecuzione - Procedo con l'iscrizione ESU..."
    
    # Rimuovi il marker file
    Remove-Item -Path $MarkerFile -Force -ErrorAction SilentlyContinue
}

# Fase 3: Seconda esecuzione (iscrizione effettiva)
CONOUT "`n`nFASE 3: Iscrizione al programma ESU..."
CONOUT "------------------------------------------"

CONOUT "Tentativo di iscrizione in corso..."
CONOUT "(Verranno provati diversi metodi nell'ordine)"

# Esegui lo script di enrollment
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $EnrollmentScript

# Fase 4: Verifica finale
CONOUT "`n`nFASE 4: Verifica risultato finale..."
CONOUT "------------------------------------------"

Start-Sleep -Seconds 2

& $SysPath\cmd.exe '/c' $SysPath\ClipESUConsumer.exe -evaluateEligibility 2>$null | Out-Null

$esuStatus = $null
if (Test-Path $esuKey) {
    $esuStatus = (Get-ItemProperty $esuKey "ESUEligibility" -ErrorAction SilentlyContinue).ESUEligibility
}

if ($null -ne $esuStatus) {
    $statoDesc = if ($Stati.ContainsKey($esuStatus)) { $Stati[$esuStatus] } else { "Sconosciuto ($esuStatus)" }
    CONOUT "Stato finale: $statoDesc"
    
    if ($esuStatus -eq 3 -or $esuStatus -eq 5) {
        CONOUT "`n=========================================="
        CONOUT "[OK] ATTIVAZIONE COMPLETATA CON SUCCESSO!"
        CONOUT "=========================================="
        CONOUT ""
        CONOUT "Il tuo PC ricevera' gli aggiornamenti di sicurezza"
        CONOUT "fino al 13 ottobre 2026"
        CONOUT ""
        CONOUT "Puoi verificare lo stato in Windows Update"
        CONOUT "=========================================="
    } else {
        CONOUT "`n[!] L'iscrizione potrebbe non essere completa."
        CONOUT "    Stato attuale: $statoDesc"
        CONOUT "    Potrebbe essere necessario un riavvio del sistema."
    }
} else {
    CONOUT "`n[?] Impossibile verificare lo stato finale."
    CONOUT "    Riavvia il sistema e controlla Windows Update."
}

ExitScript 0