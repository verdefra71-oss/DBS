# Dynamique Ballet Studio

App Flutter per la gestione della scuola di danza **Dynamique Ballet Studio**.

## Funzioni
- Inserimento e modifica iscritti
- Discipline: Danza classica, Danza moderna, Hip Hop, Contemporaneo, Salsa New York, Salsa cubana, Bachata, Hells, Aerial Hoop
- Quota di partecipazione
- Acconti multipli
- Costo saggio
- Costo vestiti
- Calcolo automatico di totale, versato e saldo
- Salvataggio locale
- Grafica grigio e rosso con logo della scuola

## GitHub Actions
Il progetto contiene `.github/workflows/build.yml`.

Dopo aver caricato il progetto su GitHub, aprire **Actions** e avviare **Build Dynamique Ballet Studio**. Il workflow genera automaticamente:
- APK Android (`dynamique-ballet-studio-apk`)
- Build Windows (`dynamique-ballet-studio-windows`)

Il workflow crea anche i file di piattaforma Flutter mancanti, quindi il repository può partire da questo progetto senza dover aggiungere manualmente le cartelle `android` e `windows`.
