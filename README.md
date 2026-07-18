# JAP Xperience — Reward-Based Stacking Mini Game

A Flutter mini-game integrated into the payment success flow of the JAP Xperience travel app. Instead of a plain payment confirmation screen, users are offered a fast-paced 60-second suitcase-stacking challenge that unlocks real travel rewards — turning a routine transaction into a moment of engagement.

## Overview

After a successful payment, the user is dropped into a short, skill-based stacking game. Suitcases move horizontally across the screen and the player taps to drop each one onto the growing stack. Precision determines the score, the score determines the reward, and the reward is decided entirely by the backend — the Flutter app has no knowledge of thresholds or reward rules, only the final outcome it's told to display.

## Gameplay Flow

```
Payment Successful
        ↓
Launch Mini Game
        ↓
60-Second Stacking Gameplay
        ↓
Tap to Drop → Overlap Check → Score +10 (on success)
        ↓
Timer Ends OR Stack Fails
        ↓
Final Score Sent to Backend
        ↓
Backend Determines Reward
        ↓
Reward Displayed to User
        ↓
claimReward() / expireReward()
        ↓
Return to Payment Success Screen
```

## Architecture

The project follows a clean separation between gameplay and business logic:

- **Flutter (frontend)** owns everything the player sees and interacts with — gameplay, UI, animations, score calculation, and the 60-second timer.
- **ASP.NET Core (backend)** owns everything about rewards — thresholds, reward names, messages, and lifecycle state.
- **Flutter never knows reward rules.** It sends a single number, the final score, to the backend and renders whatever reward object comes back. This means reward tiers can change on the backend at any time without a new app release.

```
┌────────────────────┐        POST /reward         ┌─────────────────────┐
│   Flutter Frontend  │ ───────────────────────────▶│  ASP.NET Core API   │
│                      │                              │                      │
│  Gameplay, UI,       │                              │  Reward thresholds,  │
│  Animations, Score    │◀──────────────────────────│  reward logic,        │
│  Calculation          │        Reward Object         │  claim/expire state  │
└────────────────────┘                              └─────────────────────┘
```

## Features

- 60-second timed gameplay session
- Horizontal suitcase movement with tap-to-drop interaction
- Overlap-based collision detection to determine stacking success
- Score increases on every successful stack
- Difficulty scales dynamically — movement speed increases as score grows
- Natural bounce animation on successful landings
- Directional tumble animation on failed drops
- Automatic camera scroll as the stack grows taller
- Confetti celebration scaled to the reward tier earned
- Score-based reward system, fully controlled by the backend
- Reward claim and expire lifecycle handled via dedicated API endpoints

## Tech Stack

**Frontend**
- Flutter
- Dart

**Backend**
- ASP.NET Core Web API
- C#

## Repository Structure

The Flutter project lives at the repository root; the backend lives inside `/backend`.

```
.
├── lib/
│   ├── screens/
│   │   ├── game_screen.dart              # Core gameplay: timer, stacking, animations
│   │   └── payment_success_screen.dart   # Entry point after a successful payment
│   ├── services/
│   │   └── reward_api_service.dart       # HTTP client for the Reward API
│   ├── models/
│   │   └── game_object.dart              # Suitcase/game object model
│   └── widgets/
│       └── progress_bar.dart
│
└── backend/
    ├── Controllers/
    │   └── RewardController.cs           # API endpoints: reward, claim, expire
    ├── Services/
    │   └── RewardService.cs              # Reward thresholds and allocation logic
    ├── Models/
    │   ├── Reward.cs                     # Reward response shape
    │   └── ScoreRequest.cs               # Score request shape
    ├── Program.cs
    └── StackingGameBackend.csproj
```

## Reward System

Reward rules are defined and evaluated entirely inside `RewardService.cs`. The frontend has no concept of these thresholds — it only ever sees the final `Reward` object.

| Score Range | Reward                  |
|-------------|--------------------------|
| 0 – 90      | No Reward                |
| 100 – 190   | Free Coffee Coupon       |
| 200 – 290   | Airport Lounge Access    |
| 300+        | ₹500 Travel Voucher      |

## API Reference

**Base URL**
```
http://10.0.2.2:5055/api/Reward
```

### `POST /reward`

Calculates and returns the reward for a given score.

**Request**
```json
{
  "score": 250
}
```

**Response**
```json
{
  "success": true,
  "score": 250,
  "rewardName": "Airport Lounge Access",
  "message": "Congratulations! You've unlocked Airport Lounge Access.",
  "claimed": false,
  "expired": false
}
```

### `POST /claim`

Marks the current reward as claimed.

### `POST /expire`

Marks the current reward as expired.

## Setup Instructions

### Backend

```bash
cd backend
dotnet restore
dotnet run
```

The API runs on `http://localhost:5055` by default.

### Frontend

Run from the repository root:

```bash
flutter pub get
flutter run
```

`reward_api_service.dart` targets `10.0.2.2`, which resolves to your machine's `localhost` from the Android emulator. If you're running on a physical device or a different emulator, update the base URL in that file to match your backend's reachable address.

## Current Limitations

- Reward state is held in memory on the backend, so it does not persist across server restarts and is not designed for concurrent multi-user sessions.
- Reward thresholds are hardcoded as constants in `RewardService.cs` rather than externally configurable.

## Future Scope

- Externalized, admin-configurable reward thresholds
- Persistent storage for reward history
- Additional mini-games across other app touchpoints
- Analytics on play rate, completion, and reward redemption
- Seasonal or time-limited reward campaigns
