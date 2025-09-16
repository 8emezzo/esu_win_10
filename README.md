# Windows 10 ESU - Estensione Aggiornamenti di Sicurezza

Script per attivare gli aggiornamenti di sicurezza estesi (ESU) di Windows 10 fino al **13 ottobre 2026**, anche con account locale.




## Requisiti
- Controllare che non ci sia il file "Consumer_ESU_Enrollment.ps1" aggiornato qua (https://github.com/abbodi1406/ConsumerESU)
- Windows 10 con aggiornamento **KB5061087** (build 19045.6036) o successivo
- Privilegi di amministratore

## Come Usare

### 1. Controllo Stato

Per verificare se ESU è già attivo sul tuo PC e se Windows è aggiornato:

Esegui **`Controlla_Stato_ESU_run.cmd`** come amministratore.

Questo script controlla:
- Se Windows 10 ha la versione minima richiesta (build 19045.6036)
- Se ESU è già attivo
- Lo stato completo del sistema

Se ESU risulta già attivo, non serve fare altro!

### 2. Attivazione ESU

Per attivare gli aggiornamenti estesi:

1. Esegui **`Consumer_ESU_Enrollment_run.cmd`** come amministratore
2. Attendi il completamento
3. **Ripeti** l'operazione una seconda volta (necessario per completare l'attivazione)

### 3. Rimozione (se necessario)

Per disattivare ESU:

Esegui **`Rimuovi_ESU_run.cmd`** come amministratore.

## Cosa Fanno gli Script

- **Controlla_Stato_ESU**: Mostra lo stato dettagliato di ESU sul tuo PC e verifica i requisiti
- **Consumer_ESU_Enrollment**: Script principale per attivare ESU
- **Rimuovi_ESU**: Rimuove l'attivazione ESU se non più necessaria

## Note Importanti

- Gli script devono essere eseguiti **come amministratore**
- L'attivazione richiede **due esecuzioni** (lo script lo fa automaticamente)
- Non è necessario un account Microsoft
- Gli aggiornamenti saranno disponibili fino al **13 ottobre 2026**

## Verifica Funzionamento

Dopo l'attivazione, puoi verificare in due modi:

**1. Windows Update:**
- Vai in **Impostazioni → Aggiornamento e sicurezza → Windows Update**
- Nella colonna di destra dovresti vedere:
> "Il PC è registrato per ottenere gli Aggiornamenti della sicurezza estesi"

**2. Script di controllo:**
- Esegui **`Controlla_Stato_ESU_run.cmd`** come amministratore
- Dovrebbe mostrare "Dispositivo Iscritto" o "Iscritto con Account Microsoft"

## Problemi Comuni

**"ConsumerESUMgr.dll non rilevata"**
- Installa prima l'aggiornamento KB5061087 o successivo

**"PowerShell non è in esecuzione come amministratore"**
- Clicca con il tasto destro sul file .cmd e scegli "Esegui come amministratore"

**ESU già attivo**
- Il PC è già iscritto, non serve fare altro

## Sicurezza


Gli script utilizzano solo API ufficiali di Windows e non modificano file di sistema.

