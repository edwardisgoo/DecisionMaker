# Decision Maker

**Kill the "where do you want to go?" loop.**

Decision Maker is a real-time multiplayer app that forces groups to make decisions. Everyone proposes an option, everyone votes, and ties get broken — no more endless back-and-forth.

Built with Flutter and Firebase.

---

## How It Works

1. **Create or join a room** — One person creates a room and shares the 6-character code with their group.
2. **Everyone proposes** — Each participant submits one option (e.g. "Thai food", "That new Italian place").
3. **Everyone votes** — Participants swipe through proposals and vote for their favorites. The number of votes per person scales with group size.
4. **Results** — The top proposal wins. If there's a tie, the group votes again on just the tied options — or picks randomly.

---

## Features

- Real-time multiplayer via Firebase Firestore
- Anonymous auth — no sign-up required
- Phase-based flow: Lobby → Proposals → Voting → Results
- Tie-breaking: revote on tied options, or animated random selection
- Scales vote quota by group size (1–4 votes per person)
- Cross-platform: iOS, Android, Web, Windows, Linux, macOS

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart ^3.7.0) |
| Backend | Firebase Cloud Firestore |
| Auth | Firebase Anonymous Auth |
| Reactivity | RxDart |

---

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart 3.7+
- A Firebase project (Firestore + Anonymous Auth enabled)

### Install

```bash
git clone <repo-url>
cd DecisionMaker/app
flutter pub get
```

### Configure Firebase

The `lib/firebase_options.dart` file contains the Firebase configuration. If you're setting up your own Firebase project, replace this file using the [FlutterFire CLI](https://firebase.flutter.dev/docs/cli):

```bash
flutterfire configure
```

Then deploy the Firestore security rules:

```bash
firebase deploy --only firestore:rules
```

### Run

```bash
flutter run                 # connected device or emulator
flutter run -d chrome       # web
flutter run -d macos        # macOS desktop
```

### Build

```bash
flutter build apk           # Android
flutter build ios           # iOS
flutter build web           # Web
flutter build macos         # macOS
```

---

## Project Structure

```
DecisionMaker/
├── app/
│   └── lib/
│       ├── main.dart               # Entry point, Firebase init + auth
│       ├── app.dart                # MaterialApp configuration
│       ├── screens/
│       │   ├── home_screen.dart
│       │   ├── create_room_screen.dart
│       │   ├── join_room_screen.dart
│       │   ├── room_lobby_screen.dart
│       │   ├── proposal_screen.dart
│       │   ├── voting_screen.dart
│       │   └── results_screen.dart
│       └── services/
│           └── firebase_room_service.dart
├── firestore.rules             # Firestore security rules
├── firebase.json               # Firebase project config
└── docs/
    └── vision.md               # Product vision
```

---

## Firestore Data Model

```
/rooms/{roomCode}
  ├── title, hostUid, phase, voteRound, ...
  ├── /participants/{uid}
  ├── /proposals/{uid}
  ├── /votes/{uid}
  └── /tiebreaker/{uid}
```

Phases: `lobby` → `proposal` → `voting` → `results` (→ `objection` for revotes)

---

## Security

- Participants can only read/write their own documents
- Only the host can advance the room phase
- Enforced via Firestore security rules in `firestore.rules`
