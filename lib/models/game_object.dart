import 'package:flutter/material.dart';
 
/// -----------------------------------------------------------------------
/// Shared design constants for the JAP Xperience mini-game.
/// Keeping colors here (rather than repeating hex values everywhere)
/// keeps the visual language consistent with the main JAP Xperience app.
/// -----------------------------------------------------------------------
class AppColors {
  AppColors._();
 
  static const Color primaryTeal = Color(0xFF11C5C6);
  static const Color primaryTealDark = Color(0xFF0AA3A4);
  static const Color successGreen = Color(0xFF34C759);
  static const Color background = Colors.white;
  static const Color textDark = Color(0xFF1B1B1F);
  static const Color textGrey = Color(0xFF8A8F98);
  static const Color inactiveGrey = Color(0xFFE7E9EC);
}
 
/// Identifies each collectible/travel object used in the stacking game.
/// The order of this enum (and of [kGameObjects] below) defines the
/// order in which objects appear during play.
enum GameObjectType {
  suitcase1,
  suitcase2,
  suitcase3,
  suitcase4,
  suitcase5,
  suitcase6,
}
 
/// Static metadata describing a single game object: its display label,
/// image asset, and the size it should be rendered at.
///
/// NOTE: Update [assetPath] values to match wherever you place the PNG
/// assets in your project. Remember to declare the folder under
/// `flutter -> assets` in pubspec.yaml, e.g.:
///
/// ```yaml
/// flutter:
///   assets:
///     - assets/images/
/// ```
class GameObjectData {
  final GameObjectType type;
  final String label;
  final String assetPath;
  final double width;
  final double height;
  final double stackOffset;
 
  const GameObjectData({
    required this.type,
    required this.label,
    required this.assetPath,
    required this.width,
    required this.height,
    required this.stackOffset,
  });
}
 
/// The ordered list of objects the player must stack, in play order:
/// Bus -> Suitcase -> Camera -> Sunglasses -> Hat.
///
/// ==== SIZE UPDATE ====
/// Width/height changed from 180x95 to 150x70 to give the suitcases a
/// slimmer, less "fat" look. This only affects rendered/box size — the
/// stacking math, collision math, and camera logic all read these same
/// two fields dynamically, so nothing else needed to change.
const List<GameObjectData> kGameObjects = [
  GameObjectData(
    type: GameObjectType.suitcase1,
    label: 'Suitcase',
    assetPath: 'assets/images/suitcase1.png',
    width: 150,
    height: 70,
    stackOffset: 0,
  ),

  GameObjectData(
    type: GameObjectType.suitcase2,
    label: 'Suitcase',
    assetPath: 'assets/images/suitcase2.png',
    width: 150,
    height: 70,
    stackOffset: 0,
  ),

  GameObjectData(
    type: GameObjectType.suitcase3,
    label: 'Suitcase',
    assetPath: 'assets/images/suitcase3.png',
    width: 150,
    height: 70,
    stackOffset: 0,
  ),

  GameObjectData(
    type: GameObjectType.suitcase4,
    label: 'Suitcase',
    assetPath: 'assets/images/suitcase4.png',
    width: 150,
    height: 70,
    stackOffset: 0,
  ),

  GameObjectData(
    type: GameObjectType.suitcase5,
    label: 'Suitcase',
    assetPath: 'assets/images/suitcase5.png',
    width: 150,
    height: 70,
    stackOffset: 0,
  ),

  GameObjectData(
    type: GameObjectType.suitcase6,
    label: 'Suitcase',
    assetPath: 'assets/images/suitcase6.png',
    width: 150,
    height: 70,
    stackOffset: 0,
  ),
];
 
/// Represents an object that has successfully landed and is now part of
/// the stack. Stores its final on-screen position so later objects can
/// check horizontal overlap/stability against it.
class StackedItem {
  final GameObjectData data;
  final double left;
  final double top;
 
  const StackedItem({
    required this.data,
    required this.left,
    required this.top,
  });
 
  double get right => left + data.width;
}
 
/// Overall status of a single game session.
enum GameStatus { playing, gameOver, success }