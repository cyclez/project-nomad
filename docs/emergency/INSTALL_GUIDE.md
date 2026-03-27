# Guida Installazione — Emergency Nomad

Questa guida spiega come installare il runtime di emergenza su un
telefono Android usando un computer e un cavo USB.

Non consigliamo a nessuno di installare questo software.
È sperimentale, pensato per telefoni dedicati ("dev-burner"),
non per il telefono personale. Leggere DECLARATION.md prima di procedere.

---

## Cosa serve

Prima di tutto, metti insieme queste cose:

1. **Un computer** (Mac, Linux, o Windows con WSL)
2. **Un telefono Android** dedicato — non il tuo telefono personale
3. **Un cavo USB** che trasferisce dati
   - ATTENZIONE: molti cavi economici sono solo per la carica.
     Se il cavo era nella scatola di un caricatore a muro,
     probabilmente NON trasferisce dati.
   - Un cavo buono è quello della scatola del telefono stesso.
4. **Il file .zip del bundle** scaricato sul computer
   - Scaricalo PRIMA dell'emergenza, quando hai ancora internet.
     In emergenza non avrai rete.

---

## Parte 1 — Preparare il telefono (fare PRIMA dell'emergenza)

Questa è la parte più complicata. Falla con calma, una sola volta.
Dopo non serve rifarla mai più.

### 1.1 Attivare le Opzioni Sviluppatore

Queste opzioni sono nascoste. Per trovarle devi fare un trucco
(non è uno scherzo, funziona davvero):

**Samsung:**
Impostazioni → Informazioni sul telefono → Informazioni software
→ tocca "Numero build" 7 volte di fila velocemente.

**Xiaomi / Redmi:**
Impostazioni → Info sistema → tocca "Versione MIUI" 7 volte di fila.

**Pixel / Android stock:**
Impostazioni → Sistema → Informazioni sul telefono
→ tocca "Numero build" 7 volte.

**Huawei:**
Impostazioni → Sistema → Informazioni telefono
→ tocca "Numero build" 7 volte.

**Tutti gli altri:**
Cerca "Numero build" nella barra di ricerca delle Impostazioni.
Toccalo 7 volte.

Dopo 7 tocchi vedrai un messaggio tipo
"Ora sei uno sviluppatore" o "Modalità sviluppatore attivata".

### 1.2 Attivare Debug USB

Ora che le Opzioni Sviluppatore sono visibili:

Impostazioni → Sistema → Opzioni sviluppatore → Debug USB → attiva.

Il telefono mostra un avviso. È normale. Conferma.

**Solo Xiaomi / Redmi — passo extra obbligatorio:**
Nelle stesse Opzioni sviluppatore, cerca anche
"Debug USB (Impostazioni di sicurezza)" e attivalo.
Xiaomi chiede di accedere col tuo account Mi e di avere una SIM inserita.
Fallo adesso mentre hai rete. In emergenza non potrai.

### 1.3 Autorizzare il computer

Collega il cavo USB tra il computer e il telefono.
Sul telefono apparirà un popup:

> "Consentire il debug USB da questo computer?"

Spunta **"Consenti sempre da questo computer"** e tocca OK.

IMPORTANTE: questo passaggio va fatto ADESSO, mentre lo schermo funziona.
Se lo schermo si rompe dopo, il computer sarà già autorizzato.

### 1.4 Verificare che funziona

Sul computer, apri il Terminale:

- **Mac:** cerca "Terminale" con Spotlight (Cmd + Spazio, scrivi Terminale)
- **Linux:** Ctrl + Alt + T
- **Windows:** apri "Ubuntu" dal menu Start (serve WSL installato)

Scrivi questo e premi Invio:

```
adb devices
```

Devi vedere qualcosa come:

```
List of devices attached
ABC123XYZ    device
```

Se vedi `ABC123XYZ    device` → tutto ok. Il telefono è pronto.

Se vedi solo `List of devices attached` senza niente sotto →
il telefono non è collegato, o il cavo è solo per la carica,
o il Debug USB non è attivo.

Se vedi `unauthorized` → sul telefono non hai toccato "Consenti".
Guarda lo schermo del telefono.

### 1.5 Installare gli strumenti sul computer (una sola volta)

Il computer ha bisogno di due programmi: `adb` e `node`.

**Mac (con Homebrew):**
```
brew install android-platform-tools node
```

**Mac (senza Homebrew):**
Installa prima Homebrew aprendo il Terminale e incollando:
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
Poi esegui il comando sopra.

**Linux (Ubuntu/Debian):**
```
sudo apt install adb nodejs
```

**Windows (WSL Ubuntu):**
```
sudo apt install adb nodejs
```
Nota: su Windows l'ADB dentro WSL potrebbe non vedere il telefono.
In quel caso installa ADB nativo per Windows da
https://developer.android.com/tools/releases/platform-tools
e usalo dal Prompt dei comandi, non da WSL.

### 1.6 Fatto

Il telefono è pronto. Mettilo nel cassetto.
Il giorno dell'emergenza avrai bisogno solo del cavo e del computer.

---

## Parte 2 — Installare il giorno dell'emergenza

Non hai rete. Hai il computer, il cavo, il telefono preparato, e il
file .zip scaricato giorni o settimane fa.

### Su Mac — metodo semplice

1. Metti il file `.zip` nella stessa cartella di `Emergency Install.command`
2. Fai doppio click su `Emergency Install.command`
3. Si apre una finestra. Leggi cosa dice. Scrivi `y` e premi Invio.
4. Aspetta che finisca.
5. Stacca il cavo.
6. Sul telefono si è aperto il browser. Sei operativo.

### Su tutti i sistemi — metodo terminale

1. Apri il Terminale.
2. Scrivi (o incolla) questo:

```
cd percorso/dove/hai/il/progetto
./bootstrap/usb-push.sh percorso/del/file/bundle.zip
```

Esempio reale:

```
cd ~/Scaricati/emergency-nomad
./bootstrap/usb-push.sh ~/Scaricati/emergency-bootstrap-core-2026.03.26.zip
```

3. Lo script ti mostra una dichiarazione di cosa farà. Leggi.
4. Scrivi `y` e premi Invio.
5. Aspetta. Vedrai i file che vengono copiati.
6. Alla fine dice "done". Stacca il cavo.
7. Sul telefono si è aperto il browser. Lo script mostra un indirizzo
   tipo `http://127.0.0.1:1234/s/a8f3b2e1c4d5` — salvalo come
   segnalibro. L'ultima parte è un codice di sicurezza unico.

---

## Parte 3 — Uso dopo l'installazione

### Schermo funzionante

- Apri Chrome (o qualsiasi browser) sul telefono
- Vai all'indirizzo che lo script ti ha mostrato alla fine dell'installazione.
  Ha questa forma: `http://127.0.0.1:1234/s/xxxxxx`
  dove `xxxxxx` è un codice unico generato durante l'installazione.
- Non serve internet. Tutto è locale.

Consiglio: salva questo indirizzo come segnalibro o aggiungilo
alla schermata home. Se lo perdi, lo puoi ritrovare collegando
il cavo e lanciando `--restart` — lo script lo mostra di nuovo.

### Schermo rotto

Se il telefono ha lo schermo rotto ma è acceso:

1. Collega il cavo USB al computer.
2. Sul computer:
```
./bootstrap/usb-push.sh --restart --headless
```
3. Si apre il browser sul computer con la stessa interfaccia.
4. Tieni il cavo collegato.

---

## Parte 4 — Se il telefono si riavvia

Il telefono si è spento (batteria scarica, riavvio, ecc.).
I dati e i file NON si perdono. Serve solo rilanciare il programma.

1. Collega il cavo USB.
2. Sul computer:
```
./bootstrap/usb-push.sh --restart
```
3. Aspetta 5 secondi. Stacca il cavo.
4. Il telefono funziona di nuovo.

---

## Problemi comuni

### "adb: command not found"

Adb non è installato. Vedi la sezione 1.5.

### "error: no ADB device connected"

- Il cavo è solo per la carica? Prova un altro cavo.
- Il Debug USB è attivo? Controlla nelle Opzioni sviluppatore.
- Il telefono è acceso?

### "error: multiple devices connected"

Hai più di un telefono collegato. Stacca gli altri, oppure
specifica quale usare:

```
adb devices
```
Nota il codice del telefono giusto (es. `ABC123XYZ`), poi:
```
./bootstrap/usb-push.sh -s ABC123XYZ bundle.zip
```

### "unauthorized"

Il telefono non ha mai autorizzato questo computer.
Guarda lo schermo del telefono — c'è un popup che aspetta.
Se lo schermo è rotto e non hai autorizzato prima, non c'è modo
di procedere senza uno schermo funzionante.

### "error: device API XX < minimum 21"

Il telefono è troppo vecchio (prima di Android 5.0, prima del 2014).
Non è supportato.

### Lo script dice "done" ma il browser non si apre

Il daemon potrebbe non essere ancora disponibile (il binario potrebbe
non essere ancora stato compilato nel bundle). Prova ad aprire
manualmente Chrome e vai a `127.0.0.1:1234`.

### Xiaomi chiede l'account Mi per il Debug USB

È un requisito Xiaomi. Devi farlo PRIMA dell'emergenza, con rete attiva.
Vedi sezione 1.2.

### Windows: ADB non vede il telefono dentro WSL

Usa ADB nativo per Windows. Scaricalo da:
https://developer.android.com/tools/releases/platform-tools

Apri il Prompt dei comandi (non WSL) e usa quello.

---

## Riepilogo rapido

| Quando | Cosa fai |
|--------|----------|
| Adesso (con calma) | Prepara il telefono (sezioni 1.1-1.6). Scarica il bundle .zip. |
| Emergenza | Attacca cavo. Doppio click (Mac) o un comando (terminale). Stacca cavo. |
| Uso quotidiano | Apri browser → usa il segnalibro salvato |
| Telefono si riavvia | Attacca cavo. `--restart`. Stacca cavo. |
| Schermo rotto | Attacca cavo. `--restart --headless`. Usa il browser del computer. |
