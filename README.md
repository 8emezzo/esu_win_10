# Windows 10 ESU - Estensione Aggiornamenti di Sicurezza

Script per attivare gli aggiornamenti di sicurezza estesi (ESU) di Windows 10 fino al **13 ottobre 2026**, anche con account locale.

## Requisiti

- Windows 10 con aggiornamento **KB5061087** (build 19045.6036) o successivo
- Privilegi di amministratore

## Come Usare

### 1. Attivazione Automatica (Consigliato)

Fai doppio clic su **`Attiva_ESU_Automatico_run.cmd`** come amministratore.

Lo script farà tutto automaticamente in due passaggi.

### 2. Controllo Stato

Per verificare se ESU è attivo:

Fai doppio clic su **`Controlla_Stato_ESU_run.cmd`** come amministratore.

### 3. Rimozione (se necessario)

Per disattivare ESU:

Fai doppio clic su **`Rimuovi_ESU_run.cmd`** come amministratore.

## Cosa Fanno gli Script

- **Attiva_ESU_Automatico**: Attiva gli aggiornamenti estesi in modo completamente automatico
- **Controlla_Stato_ESU**: Mostra lo stato dettagliato di ESU sul tuo PC
- **Consumer_ESU_Enrollment**: Script principale (usato internamente dagli altri)
- **Rimuovi_ESU**: Rimuove l'attivazione ESU se non più necessaria

## Note Importanti

- Gli script devono essere eseguiti **come amministratore**
- L'attivazione richiede **due esecuzioni** (lo script lo fa automaticamente)
- Non è necessario un account Microsoft
- Gli aggiornamenti saranno disponibili fino al **13 ottobre 2026**

## Verifica Funzionamento

Dopo l'attivazione, in Windows Update (Impostazioni → Aggiornamento e sicurezza) dovresti vedere:

> "Il PC è registrato per ottenere gli Aggiornamenti della sicurezza estesi"

## Problemi Comuni

**"ConsumerESUMgr.dll non rilevata"**
- Installa prima l'aggiornamento KB5061087 o successivo

**"PowerShell non è in esecuzione come amministratore"**
- Clicca con il tasto destro sul file .cmd e scegli "Esegui come amministratore"

**ESU già attivo**
- Il PC è già iscritto, non serve fare altro

## Sicurezza

Gli script utilizzano solo API ufficiali di Windows e non modificano file di sistema.