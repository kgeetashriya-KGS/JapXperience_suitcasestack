# JAP Xperience — Suitcase Stacking Game

A mini-game built as part of the JAP Xperience rewards platform. Players stack falling suitcases on a moving podium within a time limit to earn rewards, with all reward logic determined by the backend.

---

## Table of Contents

- [Tech Stack](#tech-stack)
- [Game Flow](#game-flow)
- [Features](#features)
- [Backend Details](#backend-details)
- [API Endpoints](#api-endpoints)
- [Project Structure](#project-structure)

---

## Tech Stack

| Layer     | Technology              |
|-----------|--------------------------|
| Frontend  | Flutter                 |
| Backend   | .NET Core Web API       |
| Integration | HTTP API (REST)       |
| Version Control | Git & GitHub        |

---

## Game Flow

1. Player is shown the **Payment Successful Screen**.
2. Player taps **Play**.
3. The **Game Screen** opens.
4. The floating suitcase starts moving horizontally.
5. The podium moves independently of the suitcase.
6. The 30-second timer **does not start immediately** — it remains idle until the player interacts.
7. The timer starts **only after the player's first tap**.
8. The player stacks moving suitcases within the 30-second window.
9. Score increases for each successful stack.
10. Difficulty increases progressively as the game continues.
11. The camera moves upward as the tower grows taller.
12. The game ends normally when either:
    - the timer reaches zero, or
    - a stacking attempt fails (tumble).
13. The player's final score is sent to the backend.
14. The backend allocates a reward based on score thresholds.
15. The reward is automatically claimed or expired depending on the outcome.
16. The app navigates back to the Payment Success Screen after the result is displayed.

---

## Features

- Continuously moving floating suitcase
- Independently moving podium
- Timer starts only after the player's first tap (not on screen load)
- 30-second gameplay timer
- Progressive difficulty scaling as the score increases
- Precise collision and overlap detection for stacking
- Dynamic camera movement as the stack grows taller
- Bounce animation on successful stacks
- Tumble animation on failed stacks
- Backend-driven reward allocation
- Automatic reward claiming and expiry based on game outcome
- Clean frontend-backend API integration
- Modular, maintainable code structure

---

## Backend Details

The backend is a **.NET Core Web API** responsible for all reward-related decision-making. The Flutter frontend never determines reward eligibility or thresholds — it only sends the final score and renders whatever the backend returns.

### RewardController

Exposes the HTTP endpoints consumed by the Flutter app. Responsible for receiving the player's score, forwarding it to `RewardService`, and returning the reward claim/expire results to the client.

### RewardService

Contains the core business logic for reward allocation. Evaluates the player's score against defined thresholds, decides which reward (if any) is granted, and manages the claim/expire lifecycle of that reward.

### Reward Model

Represents a reward entity, including details such as the reward name and its current status (e.g. pending, claimed, expired).

### ScoreRequest Model

Represents the payload sent from Flutter to the backend, containing the player's final score for a completed game session.

### Design Principle

- Reward logic is handled **entirely** by the backend.
- Flutter **never** decides reward thresholds or reward names.
- Flutter only sends the player's score and displays whatever the backend responds with.
- This separation keeps reward rules centralized, secure, and independently updatable without requiring frontend changes.

---

## API Endpoints

### `POST /api/Reward/reward`

Sends the player's final score to the backend and receives reward information in return.

**Request Body**
    {
      "score": 120
    }

**Response Body**
    {
      "success": true,
      "rewardName": "Airport Lounge Access"
    }

### `POST /api/Reward/claim`

Marks the previously issued reward as claimed.

### `POST /api/Reward/expire`

Marks the previously issued reward as expired.

---

## Project Structure

### Flutter Frontend

    lib/
    ├── main.dart
    ├── models/
    │   └── game_object.dart
    ├── screens/
    │   ├── payment_success_screen.dart
    │   └── game_screen.dart
    ├── services/
    │   └── reward_api_service.dart
    └── theme/
        └── app_colors.dart

### .NET Backend

    JAPXperience.Api/
    ├── Controllers/
    │   └── RewardController.cs
    ├── Services/
    │   └── RewardService.cs
    ├── Models/
    │   ├── Reward.cs
    │   └── ScoreRequest.cs
    ├── Program.cs
    └── appsettings.json

---

## Summary

The Suitcase Stacking Game combines a Flutter-based interactive gameplay experience with a .NET Core backend that fully owns reward logic. The frontend focuses purely on gameplay, animation, and presentation, while all scoring thresholds and reward decisions remain centralized on the server — keeping the system secure, maintainable, and easy to extend.
