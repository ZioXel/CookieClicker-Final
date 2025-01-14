# Cookie Clicker Final - Dokumentacja

## Opis projektu
Cookie Clicker Final to gra typu "cookie clicker" zaprojektowana w ramach pracy inżynierskiej. Jest to aplikacja napisana w Flutterze, korzystająca z backendu stworzonego w Pythonie przy użyciu frameworka Flask. Projekt prezentuje strukturę architektoniczną MVVM (Flutter) i MVC (backend), demonstrując efektywne wykorzystanie nowoczesnych technologii w tworzeniu aplikacji interaktywnych.

---

## Wykorzystane technologie

### Frontend
- **Flutter**
  - Używany do budowy interfejsu użytkownika.
  - Zarządzanie stanem przy użyciu `Provider` (MVVM).
  - Routing z wykorzystaniem `Navigator`.

### Backend
- **Python (Flask)**
  - Framework MVC obsługujący żądania REST API.
  - Implementacja logiki serwera gry.
  - Obsługa bazy danych za pomocą SQLAlchemy.

---

## Architektura
Projekt został podzielony na warstwy:

1. **Flutter (MVVM)**
   - **Model**: Reprezentuje dane (np. licznik ciasteczek, stany gry).
   - **ViewModel**: Logika biznesowa, reagowanie na interakcje użytkownika.
   - **View**: Interfejs użytkownika, widgety Flutter.

2. **Backend Flask (MVC)**
   - **Model**: Dane przechowywane w bazie (np. użytkownicy, liczba kliknięć).
   - **Kontroler**: Endpointy REST API, np. `/api/click`, `/api/leaderboard`.
   - **Widok**: Odpowiedzi JSON (REST API).

---

## Funkcjonalności
1. **Core Gameplay**:
   - Licznik kliknięć (klikanie zwiększa liczbę ciasteczek).
   - Sklep z ulepszeniami (np. automatyczne kliknięcia, zwiększanie wartości kliknięcia).

2. **Backend**:
   - REST API obsługujące żądania klienta (GET/POST).
   - Obsługa leaderboardów.

3. **Baza danych**:
   - Przechowywanie danych użytkowników, progresu i ulepszeń.

4. **Routing**:
   - Frontend: `Navigator` w Flutterze.
   - Backend: Routing w Flask, np. `@app.route('/api/click')`.

---

## Problemy i rozwiązania
1. **Zarządzanie stanem aplikacji**:
   - Rozwiązanie: Wykorzystanie `Provider` w Flutterze do zarządzania stanem.

2. **Łączenie frontendu z backendem**:
   - Rozwiązanie: Użycie biblioteki `http` w Flutterze do komunikacji REST API.

3. **Optymalizacja bazy danych**:
   - Rozwiązanie: Implementacja odpowiednich indeksów i optymalnych zapytań SQL w SQLAlchemy.

---

## Instrukcja uruchomienia
1. **Backend** (Python/Flask):
   - Zainstaluj wymagane biblioteki: `pip install -r requirements.txt`
   - Uruchom serwer: `python app.py`

2. **Frontend** (Flutter):
   - Zainstaluj wymagane zależności: `flutter pub get`
   - Uruchom aplikację: `flutter run`

---

## Podsumowanie
Projekt Cookie Clicker Final pokazuje, jak połączyć technologie frontendowe i backendowe w aplikacji interaktywnej z wykorzystaniem wzorców MVVM i MVC. Dokumentacja zawiera opis wykorzystanego frameworka, architektury oraz rozwiązań problemów występujących podczas realizacji.

