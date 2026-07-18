# JAP Xperience — Reward-Based Stacking Mini Game

A Flutter mini-game embedded in the payment success flow of the JAP Xperience travel app. Players stack suitcases against a 60-second timer to earn real travel rewards — coffee coupons, lounge access, or travel vouchers — with all reward logic decided entirely by a configurable ASP.NET Core backend.

## Overview

After a successful payment, the user is offered a quick, playful mini-game instead of a plain confirmation screen. The final score is sent to the backend, which decides the reward and returns it to the app for display — the frontend never knows the thresholds or reward rules.

```
Payment Successful
        ↓
Launch Mini Game
        ↓
60 Second Gameplay (stack suitcases, score increases per success)
        ↓
Send Final Score to Backend
        ↓
Backend Determines Reward (thresholds, name, message)
        ↓
claimReward() / expireReward()
        ↓
Display Result Screen
        ↓
Navigate Back to Payment Success Screen
```

## Features

- 60-second countdown timer
- Score-based dynamic difficulty (horizontal speed scales with score)
- Tap-to-drop stacking with overlap-based collision detection
- Natural landing bounce animation on success
- Directional tumble animation on failure
- Automatic camera scroll as the stack grows
- Confetti celebration, scaled to reward tier
- Score-based reward system, fully configurable on the backend
- Claim / expire reward lifecycle

## Tech Stack

**Frontend**
- Flutter
- Dart

**Backend**
- ASP.NET Core Web API
- C#

## Project Structure

```
frontend/
  lib/
    screens/
      game_screen.dart              # Core gameplay: timer, stacking, animations
      payment_success_screen.dart   # Entry point after payment
    services/
      reward_api_service.dart       # HTTP client for the Reward API
    models/
      game_object.dart              # Suitcase/game object model, app colors
    widgets/
      progress_bar.dart

backend/
  Controllers/
    RewardController.cs             # POST /api/Reward/reward, /claim, /expire
  Services/
    RewardService.cs                # Reward thresholds, allocation logic
  Models/
    Reward.cs                       # Reward response shape
    ScoreRequest.cs                 # Score request shape
  Program.cs
```

> Adjust the folder names above to match your actual repo layout if it differs.

## Reward Thresholds

Reward logic lives entirely in `RewardService.cs` on the backend and can be changed there without any frontend release.

| Score Range | Reward               |
|-------------|----------------------|
| 0 – 90      | No Reward            |
| 100 – 190   | Free Coffee Coupon   |
| 200 – 290   | Airport Lounge Access|
| 300+        | ₹500 Travel Voucher  |

## API Reference

Base URL (local/emulator): `http://10.0.2.2:5055/api/Reward`

| Method | Endpoint          | Body                  | Description                                  |
|--------|-------------------|------------------------|-----------------------------------------------|
| POST   | `/reward`         | `{ "score": 250 }`     | Computes and returns the reward for a score  |
| POST   | `/claim`          | —                       | Marks the current reward as claimed          |
| POST   | `/expire`         | —                       | Marks the current reward as expired          |

**Sample response**

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

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [.NET SDK](https://dotnet.microsoft.com/download) (8.0 or later recommended)
- Android emulator / iOS simulator or physical device

### Backend Setup

```bash
cd backend
dotnet restore
dotnet run
```

By default the API listens on `http://localhost:5055`. If you change the port, update `baseUrl` in `reward_api_service.dart` to match.

### Frontend Setup

```bash
cd frontend
flutter pub get
flutter run
```

> `reward_api_service.dart` uses `10.0.2.2` as the backend host, which points to your machine's `localhost` from the Android emulator. If you're running on a physical device or iOS simulator, update `baseUrl` to your machine's actual IP address or a deployed API URL.

## Notes

- The frontend is intentionally kept unaware of reward thresholds, names, and messages — it only sends the final score and displays whatever the backend returns. This keeps reward rules configurable without app updates.
- `RewardService` currently holds reward state in memory (no database), so it's best suited for a single active session at a time. See Future Scope below for persistence plans.

## Future Scope

- Dynamic, admin-editable reward configuration
- Database-backed reward history per user
- Additional mini-games across other app moments
- Analytics and engagement tracking
- Seasonal reward campaigns

## License

Add your license here (e.g. MIT, proprietary/internal use only).
