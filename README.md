# SAMEPACE

Der digitale Sport-Stundenplan, der Menschen in deiner Nähe zusammenbringt –
nach Zeit, Sportart und Leistungsniveau. Flutter-App (Android, iOS, Web) mit
Supabase als Backend (Auth, Datenbank, Realtime-Chat).

## Screens

1. **Home** – Sportart auswählen und gleich loslegen.
2. **Mein Sportplan** – eigene Sportzeiten in der Wochenübersicht verwalten.
3. **Neue Aktivität** – Zeit, Ort, Distanz, Pace und Umkreis festlegen.
4. **Matches** – passende Personen für eine Sportzeit finden (Zeit- & Pace-Overlap).
5. **Gruppe & Chat** – Treffpunkt festlegen und in Echtzeit chatten.
6. **Profil** – Sportarten & Level, Zuverlässigkeit, Aktivität der letzten 7 Tage.

## Setup

### 1. Supabase-Projekt anlegen

1. Neues Projekt auf [supabase.com](https://supabase.com) erstellen.
2. Im SQL-Editor den Inhalt von `supabase/migrations/0001_init.sql` ausführen
   (legt Tabellen, Trigger und Row-Level-Security-Policies an).
3. Unter *Project Settings → API* die `Project URL` und den `anon` Key kopieren.

### 2. Flutter-App konfigurieren

```bash
cp .env.example .env
```

`.env` mit den Werten aus Schritt 1 befüllen:

```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=xxxxx
```

### 3. Abhängigkeiten installieren & starten

```bash
flutter pub get
flutter run            # Android/iOS-Gerät oder Simulator
flutter run -d chrome  # Web
```

## Architektur

```
lib/
  models/     Datenmodelle (Profile, Activity, UserSport, Group, ChatMessage, ...)
  services/   Supabase-Zugriff (Auth, Profile, Activity, Match, Group, Message)
  screens/    Die 6 Screens + Auth-Screens
  router/     go_router Konfiguration inkl. Auth-Redirect
  theme/      SAMEPACE Farbschema
  widgets/    Geteilte UI-Bausteine (Bottom-Navigation)
supabase/
  migrations/ SQL-Schema inkl. RLS-Policies
```

### Matching-Logik

`MatchService` vergleicht die eigene Aktivität mit den Aktivitäten anderer
Nutzer:innen am selben Wochentag und berechnet einen Score aus der
zeitlichen Überlappung (60%) und der Pace-Überlappung (40%), der als
Prozentwert ("96% passend") angezeigt wird.
