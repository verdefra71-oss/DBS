# Supporto iOS - Dynamique Ballet Studio

Il progetto è predisposto per essere compilato su macOS/GitHub Actions per iOS.

## Build automatica

In GitHub: **Actions → Build iOS - Dynamique Ballet Studio → Run workflow**.

Il workflow:
1. installa Flutter 3.35.3;
2. genera automaticamente la cartella `ios/` mantenendo codice e grafica dell'app;
3. esegue `flutter pub get`;
4. crea una build iOS Release senza firma;
5. pubblica `Runner.app` come artifact.

## App Store / TestFlight

Per distribuire l'app su iPhone tramite TestFlight o App Store occorrono un Apple Developer Account, un Bundle Identifier e la firma Apple (certificato/provisioning). Questi dati non vengono inseriti nel progetto per evitare di esporre credenziali.

## Funzioni usate dall'app

L'app utilizza plugin Flutter compatibili con iOS per salvataggio locale, selezione file, condivisione e generazione PDF. Non sono state aggiunte richieste di permessi iOS non necessarie.
