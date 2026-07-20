# JAP Xperience — Reward-Based Stacking Mini Game

A Flutter mini-game built into the payment success flow of the JAP Xperience travel app. Instead of showing a plain "Payment Successful" screen, the app gives the user a short, skill-based stacking challenge that can unlock a real travel reward — turning a routine post-payment moment into something the user actually wants to engage with.

---

## Table of Contents

- [Project Description](#project-description)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Gameplay Flow](#gameplay-flow)
- [Reward Workflow](#reward-workflow)
- [Stacking Logic](#stacking-logic)
- [API Endpoints](#api-endpoints)
- [Screenshots](#screenshots)
- [How to Run the Project](#how-to-run-the-project)
- [Future Improvements](#future-improvements)
- [Conclusion](#conclusion)

---

## Project Description

**What it is**

JAP Xperience's stacking game is a 60-second mini-game shown right after a payment is completed. The player stacks moving suitcases on top of each other, one at a time, by tapping at the right moment. How well they stack determines their score, and their score determines whether — and what — travel reward they unlock.

**Why it was built**

A payment confirmation screen is usually a dead end — the user sees "Success" and moves on. This project turns that moment into a small, rewarding interaction instead: the user isn't just told the payment worked, they get a chance to earn something extra from it. It also gave a clean opportunity to build a real, working example of a Flutter frontend talking to a separately-owned .NET backend, rather than keeping all logic on one side.

**What the gameplay is**

A suitcase moves left and right across the top of the screen. The player taps to drop it. If it lands with enough overlap on the stack (or the podium, for the first suitcase), it joins the stack and the score goes up. If it doesn't land with enough overlap, it tumbles off and the game ends. The podium itself also drifts slowly from side to side throughout the game, carrying the whole stack with it, which adds a second layer of timing to think about besides just the drop itself. The round ends either when the 60-second timer runs out or when a suitcase fails to land.

**How the reward system works**

At the end of the round, the app sends the final score to the backend. The backend — not the app — decides whether that score qualifies for a reward and which one. The Flutter app has no built-in knowledge of score thresholds or reward names; it simply displays whatever the backend responds with.

**How the frontend and backend communicate**

The Flutter app and the .NET backend communicate over a simple HTTP/JSON API. The frontend sends the score once the game ends, waits for a reward response, shows it to the user, and then makes one more call to tell the backend whether the reward was claimed or expired. All reward decision-making stays on the backend; the frontend is only ever a reporter and a display layer.

---

## Features

- **Dynamic stacking gameplay** — tap-to-drop suitcase stacking with overlap-based success/failure detection
- **Moving podium mechanics** — the podium continuously drifts left and right within safe screen boundaries, and the entire stack moves with it
- **Score-based rewards** — final score determines whether a reward is unlocked
- **Backend-driven reward allocation** — all reward thresholds and reward names are decided by the .NET backend, never the app
- **Increasing game difficulty** — suitcase movement speed gradually increases as the score climbs
- **Timer-based gameplay** — every round is a fixed 60-second session
- **Confetti animations** — celebration intensity scales with the reward tier earned
- **Camera movement** — the view scrolls upward as the stack grows taller, keeping the active suitcase visible
- **Reward claiming and expiry workflow** — reward state is explicitly claimed or expired after the round ends
- **Flutter and .NET integration** — a working example of a mobile frontend and a Web API backend as two independently owned pieces

---

## Tech Stack

**Frontend**
- Flutter
- Dart

**Backend**
- .NET Core Web API
- C#

**Others**
- HTTP API integration (JSON over REST)
- Git & GitHub

---

## Project Structure

The Flutter project lives at the repository root; the backend lives inside `/backend`.

```
.
├── lib/
│   ├── screens/
│   │   ├── game_screen.dart              # Core gameplay: timer, stacking, podium movement, animations
│   │   └── payment_success_screen.dart   # Entry point shown right after a successful payment
│   ├── services/
│   │   └── reward_api_service.dart       # HTTP client that talks to the Reward API
│   ├── models/
│   │   └── game_object.dart              # Suitcase/game object data and shared game constants
│   └── widgets/
│       └── progress_bar.dart             # Reusable UI widget
│
└── backend/
    ├── Controllers/
    │   └── RewardController.cs           # API endpoints: reward, claim, expire
    ├── Services/
    │   └── RewardService.cs              # Reward thresholds and allocation logic
    ├── Models/
    │   ├── Reward.cs                     # Shape of the reward response sent to the app
    │   └── ScoreRequest.cs               # Shape of the score request sent by the app
    ├── Program.cs                        # API startup/configuration
    └── StackingGameBackend.csproj
```

| File / Folder | Purpose |
|---|---|
| `game_screen.dart` | The entire mini-game: timer, suitcase movement, podium movement, collision/overlap checks, score updates, animations |
| `payment_success_screen.dart` | Shown after payment; launches the game and displays the result once it's returned |
| `reward_api_service.dart` | Sends the score to the backend and calls the claim/expire endpoints |
| `game_object.dart` | Defines each suitcase (size, image asset) and shared visual constants |
| `RewardController.cs` | Exposes the `/reward`, `/claim`, and `/expire` HTTP endpoints |
| `RewardService.cs` | Contains the actual reward threshold rules and decides what reward, if any, a score earns |
| `Reward.cs` / `ScoreRequest.cs` | Define the JSON shape of what's sent and received between the app and the API |

---

## Gameplay Flow

```
Payment Successful
        ↓
Start Game
        ↓
Stack Objects (tap to drop, podium and stack drift continuously)
        ↓
Score Calculation
        ↓
Game Ends (timer runs out OR a suitcase fails to land)
        ↓
Send Score to Backend
        ↓
Reward Allocation (decided entirely by the backend)
        ↓
Display Reward
        ↓
Claim / Expire Reward
        ↓
Navigate Back to Payment Success Screen
```

---

## Reward Workflow

Reward handling is split cleanly between the two sides of the project:

- **`getReward(score)`** — Called once the round ends. Sends the final score to the backend and receives back whether a reward was earned, and if so, its name and message.
- **`claimReward()`** — Called after the result screen is shown, if the backend indicated a reward was won. Marks that reward as claimed on the backend.
- **`expireReward()`** — Called instead of `claimReward()` if no reward was earned (or the backend indicates none applies), marking the reward attempt as expired.

**Important design point:** the frontend never decides reward thresholds. It doesn't know what score maps to what reward — that logic lives entirely inside `RewardService.cs` on the backend. Flutter's only job is to send the score, and then faithfully display and act on whatever response it gets back. This means reward rules can be changed on the backend at any time without touching or re-releasing the app.

---

## Stacking Logic

At a high level, without exposing internal implementation details:

- **Overlap calculation** — when a suitcase is dropped, its horizontal position is compared against the item below it (or the podium, for the first drop). If enough of the suitcase overlaps the surface beneath it, the stack succeeds; otherwise the suitcase tumbles off and the round ends.
- **Score updates** — every successful stack adds to the score. The round is scored purely on how many suitcases are stacked correctly.
- **Increasing difficulty** — as the score rises, the suitcases move faster across the screen, making later drops require sharper timing.
- **Podium movement** — the podium drifts continuously between two boundaries at a much slower speed than the suitcases, and stays within safe padding from the screen edges so nothing overhanging the stack goes off-screen.
- **Camera movement** — as the stack grows tall enough to approach the top of the screen, the camera scrolls upward to keep the active suitcase and the top of the stack visible at all times.

---

## API Endpoints

**Base URL**
```
http://10.0.2.2:5055/api/Reward
```

| Method | Endpoint | Description |
|---|---|---|
| POST | `/api/Reward/reward` | Accepts the final score and returns whether a reward was earned, along with its name and message |
| POST | `/api/Reward/claim` | Marks the most recently issued reward as claimed |
| POST | `/api/Reward/expire` | Marks the most recently issued reward as expired |

### POST `/reward`

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

**Current reward thresholds** (defined in `RewardService.cs`):

| Score Range | Reward |
|---|---|
| 0 – 90 | No Reward |
| 100 – 190 | Free Coffee Coupon |
| 200 – 290 | Airport Lounge Access |
| 300+ | ₹500 Travel Voucher |

---

## How to Run the Project

### Backend

```bash
cd backend
dotnet restore
dotnet run
```

The API starts on `http://localhost:5055` by default.

### Frontend

From the repository root:

```bash
flutter pub get
flutter run
```

### How they connect locally

`reward_api_service.dart` points to `http://10.0.2.2:5055`. This address is a special alias that the Android emulator uses to reach `localhost` on your development machine — so as long as the backend is running locally on port 5055, the emulator can reach it without any extra configuration.

If you're testing on a physical device or a different emulator, `10.0.2.2` won't resolve correctly — update the base URL in `reward_api_service.dart` to your machine's actual local network address (e.g. `http://192.168.x.x:5055`) instead.

---

## Future Improvements

- Externally configurable reward thresholds, instead of hardcoded constants in `RewardService.cs`
- Deploying the backend to a hosted environment instead of running it locally
- Additional reward types beyond the current fixed set
- A leaderboard to track and compare high scores
- Multiplayer or challenge-based game modes

---

## Conclusion

This project demonstrates a complete, working slice of a real product feature: a mobile game built in Flutter, backed by a separately maintained .NET Core API, communicating over a simple and predictable HTTP contract. The split of responsibility is intentional — the app owns the experience, the backend owns the business rules — which keeps each side simple to reason about and change independently. It's a small project in scope, but it reflects a structure that would hold up in a larger, production-style application.
