import 'dart:convert';
import 'package:http/http.dart' as http;

class RewardApiService {
  static const String baseUrl = "http://10.0.2.2:5055/api/Reward";

  Future<Map<String, dynamic>> getReward(int score) async {
  final response = await http.post(
    Uri.parse("$baseUrl/reward"),
    headers: {
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "score": score,
    }),
  );

  return jsonDecode(response.body);
}

  Future<Map<String, dynamic>> claimReward() async {
    final response = await http.post(Uri.parse("$baseUrl/claim"));

    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> expireReward() async {
    final response = await http.post(Uri.parse("$baseUrl/expire"));

    return jsonDecode(response.body);
  }
}