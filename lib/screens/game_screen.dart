import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_object.dart';
import 'package:confetti/confetti.dart';
import '../services/reward_api_service.dart';
/// Internal phase of the currently active (in-play) object.
enum _Phase { moving, falling, tumbling }

/// The stacking mini-game screen.
///
/// Flow: the current object moves left/right -> player taps -> it drops
/// straight down -> if it overlaps the item below by enough, it joins the
/// stack; otherwise it tumbles off and the game ends.
///
/// Only one object is ever "active" (moving/falling/tumbling) at a time.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  // ---------------- Tunable layout / gameplay constants ----------------
  double _pxPerSecond = 110; // constant horizontal speed
  static const double _movingTop = 24; // Y position of the moving object
  static const double _platformWidth = 180;
  static const double _platformHeight = 22;
  static const double _platformBottomMargin = 70;
  static const double _overlapThreshold = 0.6; // 60% overlap to succeed (stricter)
  /// Screen Y that the top of the stack is pinned to once the camera
  /// begins scrolling. Must stay comfortably above `_movingTop` plus the
  /// active item's height, or the newest stacked item can render above
  /// (and visually overlap) the moving/falling object.
  static const double _cameraTopMargin = 190;
  static const double _platformEdgePadding = 40;

  // ---------------- Game state ----------------
  final List<StackedItem> stackedItems = [];
  int currentIndex = 0;
  /// Flutter sends only the final score to the backend and stores what
  /// comes back — it never computes thresholds or reward names itself.
  final RewardApiService _rewardApi = RewardApiService();
  bool _rewardSuccess = false;
  String _rewardName = "";
  int _confettiParticleCount = 0;
  int score = 0;
  GameStatus status = GameStatus.playing;
  _Phase _phase = _Phase.moving;
  

  // ---------------- Layout, populated by LayoutBuilder ----------------
  double _gameWidth = 0;
  double _gameHeight = 0;
  bool _started = false;
  bool _isClaimAnimating = false;
  double _cameraOffset = 0; // render-only vertical shift, world coords untouched

  

  bool _showInstruction = true;

  // ---------------- Countdown timer ----------------
  static const int _gameDurationSeconds = 60;
  Timer? _countdownTimer;
  int _secondsLeft = _gameDurationSeconds;

  // ---------------- Horizontal ping-pong movement ----------------
  late final AnimationController _hController;
  Animation<double> _moveAnimation = const AlwaysStoppedAnimation<double>(0);

  // ---------------- Podium movement ----------------
  // Independent of _hController (the floating object). Drives only the
  // podium + already-stacked items. Roughly 30–40% of the floating
  // object's base speed (110 px/sec) so it stays fair.
  static const double _platformPxPerSecond = 40;
  late final AnimationController _platformController;
  Animation<double> _platformOffsetAnimation =
      const AlwaysStoppedAnimation<double>(0);
  bool _platformStarted = false;

  // ---------------- Vertical drop (success path) ----------------
  late final AnimationController _fallController;
  late Animation<double> _fallAnimation;
  double? _currentLeft;
  double? _landingTargetTop;

  // ---------------- Tumble-off animation (fail path) ----------------
  late final AnimationController _failController;
  late final ConfettiController _confettiController;

  // ---------------- Landing bounce (success path) ----------------
  late final AnimationController _landBounceController;
  int? _bounceItemIndex; // index into stackedItems currently mid-bounce

  // ---------------- Tumble direction (fail path) ----------------
  double _tumbleDirection = 1.0; // 1.0 = falls right, -1.0 = falls left

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
  if (mounted) {
    setState(() {
      _showInstruction = false;
    });
  }
});
    _hController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fallController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
   _failController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _landBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _confettiController = ConfettiController(
  duration: const Duration(seconds: 3),
);
_platformController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1000), // placeholder; set for real in _startPlatformMovement
);
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _hController.dispose();
    _fallController.dispose();
    _failController.dispose();
    _landBounceController.dispose();
    _confettiController.dispose();
    _platformController.dispose();
    super.dispose();
  }

  /// Starts (or restarts) the 60-second countdown. Purely a UI/state timer —
  /// does not touch _pxPerSecond, collision thresholds, or camera math.
  void _startCountdown() {
    _countdownTimer?.cancel();
    _secondsLeft = _gameDurationSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
        _onTimeUp();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  /// Called when the countdown reaches zero while the player is still
  /// playing. Ends the game with the "TIME'S UP" result, which reuses
  /// GameStatus.success and the isWin: true branch of the result screen.
  Future<void> _onTimeUp() async {
    if (status != GameStatus.playing) return;
    _hController.stop();

    await _finishGame(won: true);
  }
  /// mm:ss display for the timer pill.
  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _platformLeft => (_gameWidth - _platformWidth) / 2;

  double get _platformTop =>
      _gameHeight - _platformBottomMargin - _platformHeight;

  /// How far the podium's center can drift each direction while staying
/// fully on-screen — mirrors how _platformLeft is centered.
double get _platformMaxOffset => math.max(
      0.0,
      (_gameWidth - _platformWidth) / 2 - _platformEdgePadding,
    );

/// Starts the podium's continuous left<->right movement. Called once,
/// after layout is known. Uses repeat(reverse: true) so it never stops
/// for the rest of gameplay — satisfies "podium should always move."
/// Completely separate from _hController / _startMoving(), so the
/// floating object's speed, duration, and difficulty scaling are
/// untouched.
void _startPlatformMovement() {
  final maxOffset = _platformMaxOffset;
  if (maxOffset <= 0) return;

  final distance = maxOffset * 2;
  final durationMs =
      ((distance / _platformPxPerSecond) * 1000).clamp(500, 20000).round();

  _platformController.duration = Duration(milliseconds: durationMs);
  _platformOffsetAnimation = Tween<double>(begin: -maxOffset, end: maxOffset)
      .animate(_platformController);

  _platformController
    ..value = 0.5 // 0.5 == offset 0, so the podium starts exactly where it always used to sit
    ..repeat(reverse: true);
}
  
  /// Starts the left<->right movement for the object at [currentIndex].
  void _startMoving() {
    final data = kGameObjects[currentIndex];
    final maxLeft = math.max(0.0, _gameWidth - data.width);
    // Increase speed every 100 points, up to a maximum.
_pxPerSecond = 110 + (score ~/ 100) * 10;

if (_pxPerSecond > 220) {
  _pxPerSecond = 220;
}
    final durationMs =
        ((maxLeft / _pxPerSecond) * 1000).clamp(500, 4000).round();

    _hController.duration = Duration(milliseconds: durationMs);
    _moveAnimation = Tween<double>(begin: 0, end: maxLeft).animate(_hController);
    _currentLeft = null;

    _hController
      ..value = 0
      ..repeat(reverse: true);
  }

  /// Player tapped: stop horizontal movement and start the vertical drop.
  void _onTap() {
  if (status != GameStatus.playing || _phase != _Phase.moving) return;

  if (_showInstruction) {
    setState(() {
      _showInstruction = false;
    });
  }

  final data = kGameObjects[currentIndex];
    _currentLeft = _moveAnimation.value;
    _hController.stop();

    final targetTop = stackedItems.isEmpty
        ? _platformTop - data.height
        : stackedItems.last.top - data.height+ data.stackOffset;
    _landingTargetTop = targetTop;

   _fallAnimation = Tween<double>(
      begin: _movingTop - _cameraOffset,
      end: targetTop,
    ).animate(
      CurvedAnimation(parent: _fallController, curve: Curves.easeIn),
    );

    setState(() => _phase = _Phase.falling);

    _fallController.forward(from: 0).then((_) => _onFallComplete());
  }

  /// Called once the straight vertical drop finishes. Decides success or
  /// failure based on overlap with the stack (or platform).
  void _onFallComplete() {
    final data = kGameObjects[currentIndex];
    final left = _currentLeft!;
    final right = left + data.width;

    // Read the podium's current offset ONCE so the comparison below and
// the position we store for this item (further down) use the exact
// same moving-stack snapshot.
final double platformOffsetX = _platformOffsetAnimation.value;

final double prevLeft =
    stackedItems.isEmpty ? _platformLeft : stackedItems.last.left;
final double prevRight = stackedItems.isEmpty
    ? _platformLeft + _platformWidth
    : stackedItems.last.right;

// Same base positions as before — just shifted to where the podium
// (and everything stacked on it) actually is right now.
final double currentPrevLeft = prevLeft + platformOffsetX;
final double currentPrevRight = prevRight + platformOffsetX;

// ---- Everything below this line is the ORIGINAL, unmodified formula ----
final overlap =
    math.min(right, currentPrevRight) - math.max(left, currentPrevLeft);
final double supportWidth = currentPrevRight - currentPrevLeft; // identical value to prevRight-prevLeft — offset cancels out
final double referenceWidth = math.min(data.width, supportWidth);
final success = overlap >= referenceWidth * _overlapThreshold;
    if (success) {
      setState(() {
        stackedItems.add(
          StackedItem(
            data: data,
            left: left - platformOffsetX,
            top: _landingTargetTop! + 2,
          ),
        );

        score += 10;

        currentIndex = (currentIndex + 1) % kGameObjects.length;

        _phase = _Phase.moving;

        // Pushes the camera down once the new item's top crosses the
        // pinned row defined by _cameraTopMargin.
        final double newItemTop = _landingTargetTop! + 6;
        final double desiredCameraOffset =
            math.max(0.0, _cameraTopMargin - newItemTop);
        if (desiredCameraOffset > _cameraOffset) {
          _cameraOffset = desiredCameraOffset;
        }

        // Triggers the squash/rise/settle bounce on the item that just
        // landed. Purely visual — the stored `top` above is untouched,
        // so collision math for the next item is unaffected.
        _bounceItemIndex = stackedItems.length - 1;
      });

      // The bounce animation runs independently and does not block the
      // next suitcase from starting immediately.
      _landBounceController.forward(from: 0).then((_) {
        if (!mounted) return;
        setState(() => _bounceItemIndex = null);
      });

      _startMoving();
    } else {
      // Determines which side gave way, using the overlap values already
      // computed above, so the tumble animation falls toward the
      // unsupported side.
      final double leftOverhang = currentPrevLeft - left;
      final double rightOverhang = right - currentPrevRight;
      _tumbleDirection = rightOverhang >= leftOverhang ? 1.0 : -1.0;

      setState(() => _phase = _Phase.tumbling);

      _failController.forward(from: 0).then((_) {
        _countdownTimer?.cancel();
        _finishGame(won: false);
      });
    }
  }

 /// Sends the final score to the backend, stores whatever reward it
  /// returns, and reveals the result screen. After the existing delay,
  /// claims or expires the reward and returns to the payment screen.
  Future<void> _finishGame({required bool won}) async {
    bool success = false;
    String rewardName = "";

    try {
      final data = await _rewardApi.getReward(score);
      success = (data["success"] ?? false) as bool;
      rewardName = (data["rewardName"] ?? "") as String;
    } catch (e) {
      debugPrint("Failed to fetch reward: $e");
      // Falls back to "no reward" rather than freezing the result screen.
    }

    if (!mounted) return;

    setState(() {
      status = won ? GameStatus.success : GameStatus.gameOver;
      _rewardSuccess = success;
      _rewardName = rewardName;
      _confettiParticleCount = _confettiCountForReward(rewardName);
    });

   Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;

      // Claims or expires based on the backend's `success` flag,
      // independent of whether this was a TIME UP or GAME OVER ending.
      try {
        if (success) {
          await _rewardApi.claimReward();
        } else {
          await _rewardApi.expireReward();
        }
      } catch (e) {
        debugPrint("Failed to claim/expire reward: $e");
      }

      if (!mounted) return;

      Navigator.of(context).pop({
        "reward": _rewardName,
      });
    });
  }

  /// Maps a reward name to how much confetti to show. Confetti intensity
  /// is a purely visual, Flutter-side decision; the score/threshold logic
  /// that produces the reward name lives entirely on the backend.
  int _confettiCountForReward(String rewardName) {
    switch (rewardName) {
      case 'Free Coffee Coupon':
        return 25;
      case 'Airport Lounge Access':
        return 60;
      case '₹500 Travel Voucher':
        return 120;
      default:
        return 0;
    }
  }
  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (status == GameStatus.gameOver) {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: _buildResultOverlay(isWin: false),
    ),
  );
}

// The countdown-survived ending reuses GameStatus.success and the
// isWin: true branch of _buildResultOverlay.
if (status == GameStatus.success) {
  return Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: _buildResultOverlay(isWin: true),
    ),
  );
}


    return Scaffold(
      backgroundColor: const Color(0xFFF4FEFE),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFEFFFFD), // soft teal-white
                Color(0xFFE3F7FB), // cyan
                Color(0xFFEAF3FF), // light blue
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Decorative floating shapes, purely visual, ignores touches.
              _buildBackgroundDecorations(),

              
  Column(
    children: [
      _buildTopBar(),
      Expanded(child: _buildGameArea()),
    ],
  ),
   Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                emissionFrequency: 0.03,
                numberOfParticles: 30,
                gravity: 0.2,
              ),
            ),
           AnimatedAlign(
  duration: const Duration(milliseconds: 450),
  curve: Curves.easeOutCubic,
  alignment: _showInstruction
      ? const Alignment(0, -0.15)
      : const Alignment(0, -1.2),
  child: AnimatedOpacity(
    duration: const Duration(milliseconds: 450),
    opacity: _showInstruction ? 1 : 0,
    child: IgnorePointer(
      child: Material(
        elevation: 10,
        color: Colors.transparent,
        child: Container(
  constraints: const BoxConstraints(
    maxWidth: 340,
  ),
  padding: const EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 14,
  ),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.92),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: const Color(0xFF18C5C5),
      width: 1.2,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 20,
        offset: const Offset(0, 8),
      ),
    ],
  ),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.touch_app_rounded,
            color: Color(0xFF18C5C5),
            size: 24,
          ),
          SizedBox(width: 8),
          Text(
            "Tap to Stack",
            style: TextStyle(
              color: Color(0xFF1F2937),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),

      SizedBox(height: 8),

      Text(
        "Tap at the right moment to stack each travel item.",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          height: 1.35,
        ),
      ),
    ],
  ),
)
      ),
    ),
  ),
),
          ],
        ),
      ),
    ),
  );
}

  /// Decorative background blobs and sparkles. Purely visual, wrapped in
  /// IgnorePointer so it never intercepts gameplay taps. Brand palette:
  /// #11C5C6 (teal), #6FE7E7 (light teal), #BFF6F6 (pale teal), white.
  Widget _buildBackgroundDecorations() {
    const teal = Color(0xFF11C5C6);
    const lightTeal = Color(0xFF6FE7E7);
    const paleTeal = Color(0xFFBFF6F6);

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ---- One large, soft-edged ("blurred") turquoise blob sitting
          // behind the lower half of the screen ----
          Positioned.fill(
            child: Align(
              alignment: _showInstruction
    ? const Alignment(0, 0.0)
    : const Alignment(0, -1.2),
              child: _bgBlob(size: 380, color: teal, opacity: 0.12),
            ),
          ),

          // ---- Supporting blobs of varying sizes, colors & opacity ----
          // Some intentionally hang off the edges of the screen.
          Positioned(
            top: -70,
            right: -50,
            child: _bgBlob(size: 210, color: teal, opacity: 0.10),
          ),
          Positioned(
            top: 30,
            left: -50,
            child: _bgBlob(size: 150, color: lightTeal, opacity: 0.11),
          ),
          Positioned(
            top: 210,
            right: -60,
            child: _bgBlob(size: 170, color: paleTeal, opacity: 0.13),
          ),
          Positioned(
            bottom: -70,
            left: -80,
            child: _bgBlob(size: 230, color: lightTeal, opacity: 0.10),
          ),
          Positioned(
            top: 320,
            left: 10,
            child: _bgBlob(size: 90, color: Colors.white, opacity: 0.10),
          ),
          Positioned(
            top: 120,
            right: 55,
            child: _bgBlob(size: 60, color: teal, opacity: 0.08),
          ),
          Positioned(
            bottom: 150,
            right: 20,
            child: _bgBlob(size: 100, color: paleTeal, opacity: 0.09),
          ),
          Positioned(
            top: 420,
            left: 100,
            child: _bgBlob(size: 55, color: lightTeal, opacity: 0.07),
          ),
          Positioned(
            bottom: 30,
            left: 130,
            child: _bgBlob(size: 75, color: Colors.white, opacity: 0.08),
          ),

          // ---- A few small semi-transparent white sparkles ----
          Positioned(
            top: 95,
            right: 100,
            child: _bgSparkle(size: 7),
          ),
          Positioned(
            top: 270,
            left: 45,
            child: _bgSparkle(size: 5),
          ),
          Positioned(
            bottom: 210,
            right: 95,
            child: _bgSparkle(size: 6),
          ),
          Positioned(
            bottom: 330,
            left: 210,
            child: _bgSparkle(size: 4),
          ),
        ],
      ),
    );
  }

  /// Soft, edge-faded circle used as a decorative background blob.
  /// The radial gradient fading to transparent gives a gentle "blurred"
  /// look without needing any image filters or custom painters.
  Widget _bgBlob({
    required double size,
    required Color color,
    required double opacity,
  }) {
    return Opacity(
      opacity: 1, // opacity already baked into the gradient stops below
      child: ClipOval(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)],
            ),
          ),
        ),
      ),
    );
  }

  /// Tiny semi-transparent white dot used as a sparkle accent.
  Widget _bgSparkle({required double size}) {
    return Opacity(
      opacity: 0.7,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: SizedBox(width: size, height: size),
      ),
    );
  }
  
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryTeal.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatColumn(
              label: 'SCORE',
              value: '$score',
              icon: Icons.stars_rounded,
            ),
            Container(
              width: 1,
              height: 38,
              color: AppColors.primaryTeal.withValues(alpha: 0.18),
            ),
            _buildStatColumn(
              label: 'TIME',
              value: _formatTime(_secondsLeft),
              icon: Icons.timer_rounded,
              valueColor: _secondsLeft <= 10 ? Colors.redAccent : null,
            ),
          ],
        ),
      ),
    );
  }

  /// A single "LABEL / big value" column used for both the score and the
  /// timer, so they read as one balanced, premium stat card.
  Widget _buildStatColumn({
    required String label,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primaryTealDark),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppColors.textDark,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildGameArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        _gameWidth = constraints.maxWidth;
        _gameHeight = constraints.maxHeight;

        if (!_started) {
          _started = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _startMoving());
        }

        if (!_platformStarted) {
  _platformStarted = true;
  WidgetsBinding.instance.addPostFrameCallback((_) => _startPlatformMovement());
}

       return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: _cameraOffset),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, cameraOffset, _) => AnimatedBuilder(
              animation: _platformController,
              builder: (context, __) {
                final double platformOffsetX = _platformOffsetAnimation.value;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: _platformLeft + platformOffsetX,
                      top: _platformTop + cameraOffset,
                      child: Container(
                        width: _platformWidth,
                        height: _platformHeight,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primaryTeal,
                              AppColors.primaryTealDark,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryTealDark.withValues(alpha: 0.45),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),

                    for (int i = 0; i < stackedItems.length; i++)
                      Positioned(
                        left: stackedItems[i].left + platformOffsetX,
                        top: stackedItems[i].top + cameraOffset,
                        child: i == _bounceItemIndex
                            ? AnimatedBuilder(
                                animation: _landBounceController,
                                builder: (context, child) {
                                  final t = _landBounceController.value;
                                  return Transform.translate(
                                    offset: Offset(0, _landingBounceDy(t)),
                                    child: Transform.scale(
                                      scaleY: _landingBounceScaleY(t),
                                      alignment: Alignment.bottomCenter,
                                      child: child,
                                    ),
                                  );
                                },
                                child: _objectImage(stackedItems[i].data),
                              )
                            : _objectImage(stackedItems[i].data),
                      ),

                    _buildActiveObject(cameraOffset),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
  Widget _buildActiveObject(double cameraOffset) {
    if (status != GameStatus.playing) return const SizedBox.shrink();
    final data = kGameObjects[currentIndex];

    if (_phase == _Phase.moving) {
      return AnimatedBuilder(
        animation: _hController,
        builder: (context, child) => Positioned(
          left: _moveAnimation.value,
          top: _movingTop,
          child: child!,
        ),
        child: _objectImage(data),
      );
    }

    if (_phase == _Phase.falling) {
      return AnimatedBuilder(
        animation: _fallController,
        builder: (context, child) => Positioned(
          left: _currentLeft ?? 0,
          top: _fallAnimation.value + cameraOffset,
          child: child!,
        ),
        child: _objectImage(data),
      );
    }

    // _phase == _Phase.tumbling: a brief wobble/loss of balance, then a
    // rotating slide off the stack in the direction the suitcase actually
    // overhung.
    return AnimatedBuilder(
      animation: _failController,
      builder: (context, child) {
        final t = _failController.value;

        double angle;
        double dx;
        double dy;
        double opacity;

        if (t < 0.22) {
          // Loses grip and tilts toward the unsupported side, still
          // resting against the stack — this is the visible "why".
          final localT = Curves.easeOut.transform(t / 0.22);
          angle = _tumbleDirection * 0.35 * localT;
          dx = _tumbleDirection * 6 * localT;
          dy = 3 * localT;
          opacity = 1.0;
        } else {
          // Slides off and tumbles, accelerating like gravity.
          final localT = (t - 0.22) / 0.78;
          final fall = Curves.easeIn.transform(localT);
          angle = _tumbleDirection * (0.35 + fall * 1.3);
          dx = _tumbleDirection * (6 + fall * 90);
          dy = 3 + fall * 320;
          final fadeT = ((localT - 0.55) / 0.45).clamp(0.0, 1.0);
          opacity = (1 - Curves.easeIn.transform(fadeT)).clamp(0.0, 1.0);
        }

        return Positioned(
          left: (_currentLeft ?? 0) + dx,
          top: (_landingTargetTop ?? 0) + dy + cameraOffset,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(angle: angle, child: child),
          ),
        );
      },
      child: _objectImage(data),
    );
  }

  // ---------------- Landing bounce curve ----------------
  // Visual-only compress -> slight overshoot -> settle. Never touches the
  // stored `top` used for collision/stacking math.
  double _landingBounceScaleY(double t) {
    if (t < 0.35) {
      final localT = Curves.easeOut.transform(t / 0.35);
      return 1.0 - 0.10 * localT; // compress on impact
    } else if (t < 0.7) {
      final localT = Curves.easeOut.transform((t - 0.35) / 0.35);
      return 0.90 + 0.14 * localT; // rise back past normal, briefly
    } else {
      final localT = Curves.easeOut.transform((t - 0.7) / 0.3);
      return 1.04 - 0.04 * localT; // settle
    }
  }

  double _landingBounceDy(double t) {
    if (t < 0.35) {
      final localT = Curves.easeOut.transform(t / 0.35);
      return 2.0 * localT; // sinks a couple of pixels
    } else if (t < 0.7) {
      final localT = Curves.easeOut.transform((t - 0.35) / 0.35);
      return 2.0 - 4.0 * localT; // rises a few pixels past rest
    } else {
      final localT = Curves.easeOut.transform((t - 0.7) / 0.3);
      return -2.0 + 2.0 * localT; // settles back to the resting spot
    }
  }

 /// `BoxFit.fill` (rather than `BoxFit.contain`) stretches each asset to
  /// exactly fill its width/height — the same values used for collision —
  /// so suitcases render edge-to-edge with no letterboxed padding.
  Widget _objectImage(GameObjectData data) {
    return Image.asset(
    data.assetPath,
    width: data.width,
    height: data.height,
    fit: BoxFit.fill,
  );
}

  Widget _buildResultOverlay({required bool isWin}) {
   return Container(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Stack(
  children: [
       if (_confettiParticleCount > 0)
  FutureBuilder(
    future: Future.delayed(Duration.zero, () {
      _confettiController.play();
    }),
    builder: (_, _) => Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        shouldLoop: false,
        emissionFrequency: 0.03,
        numberOfParticles: _confettiParticleCount,
        gravity: 0.2,
      ),
    ),
  ),

    Center(
  child: IgnorePointer(
    ignoring: _isClaimAnimating,
    child: AnimatedScale(
      scale: _isClaimAnimating ? 0.9 : 1.0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      
  child: AnimatedOpacity(
  duration: const Duration(milliseconds: 250),
  opacity: _isClaimAnimating ? 0.0 : 1.0,
  child: Container(
        constraints: const BoxConstraints(
          maxWidth: 310,
        ),
            padding: const EdgeInsets.fromLTRB(32, 42, 32, 32),
           decoration: BoxDecoration(
  gradient: const LinearGradient(
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF4FEFE),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
  borderRadius: BorderRadius.circular(30),
  border: Border.all(
    color: AppColors.primaryTeal.withValues(alpha: 0.18),
    width: 1.5,
  ),
  boxShadow: [
    BoxShadow(
      color: AppColors.primaryTeal.withValues(alpha: 0.12),
      blurRadius: 28,
      offset: const Offset(0, 14),
    ),
  ],
),
           child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gradient icon badge with small celebration sparkles.
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: isWin
                              ? [
                                  AppColors.primaryTeal,
                                  AppColors.primaryTealDark,
                                ]
                              : [
                                  AppColors.textGrey.withValues(alpha: 0.6),
                                  AppColors.textGrey,
                                ],
                        ),
                       boxShadow: [
  BoxShadow(
    color: (isWin
            ? AppColors.primaryTeal
            : Colors.orange)
        .withValues(alpha: 0.35),
    blurRadius: 24,
    spreadRadius: 2,
    offset: const Offset(0, 10),
  ),
],
                      ),
                      child: Icon(
                        isWin
                            ? Icons.emoji_events_rounded
                            : Icons.replay_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                    if (isWin) ...const [
                      Positioned(
                        top: -6,
                        left: 2,
                        child: _Sparkle(size: 16),
                      ),
                      Positioned(
                        bottom: -2,
                        right: -2,
                        child: _Sparkle(size: 12),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  isWin ? "TIME'S UP!" : 'GAME OVER',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'YOUR SCORE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textGrey,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$score',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryTealDark,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
                if (_rewardSuccess) ...[
                  const Text(
                    'YOU UNLOCKED',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _rewardName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryTealDark,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'No Reward This Time!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                const Text(
                  'Returning to Payment Screen...',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textGrey,
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
  ),
    ),
  ],
),
      ),
    );
}
  }

/// Small reusable sparkle decoration used on the result card.
class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;

  const _Sparkle({required this.size}) : color = AppColors.primaryTeal;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.auto_awesome,
      size: size,
      color: color.withValues(alpha: 0.55),
    );
  }
}