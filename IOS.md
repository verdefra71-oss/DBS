# Supporto iOS - Dynamique Ballet Studio

Il progetto è predisposto per la compilazione iOS su macOS/GitHub Actions.

Il workflow **Build iOS - Dynamique Ballet Studio**:
1. genera la cartella `ios/` con Flutter;
2. installa le dipendenze;
3. costruisce `Runner.app` in Release;
4. crea anche un file `dynamique-ballet-studio-unsigned.ipa`.

### Importante per iPhone

L'IPA senza firma è utile per verificare la build, ma **non può essere installato e avviato normalmente su un iPhone**. Per l'installazione reale serve la firma Apple (Development, Ad Hoc o TestFlight).

Il progetto non contiene certificati o profili personali Apple.
