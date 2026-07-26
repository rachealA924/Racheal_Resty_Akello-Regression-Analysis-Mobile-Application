import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const AgriPointsApp());
}

class AgriPointsApp extends StatelessWidget {
  const AgriPointsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgriPoints Yield Predictor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7F3),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          isDense: true,
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  static const String baseUrl =
      "https://racheal-resty-akello-regression-analysis.onrender.com";

  final _formKey = GlobalKey<FormState>();

  final TextEditingController regionController = TextEditingController();
  final TextEditingController soilTypeController = TextEditingController();
  final TextEditingController cropController = TextEditingController();
  final TextEditingController weatherController = TextEditingController();
  final TextEditingController rainfallController = TextEditingController();
  final TextEditingController temperatureController = TextEditingController();
  final TextEditingController daysToHarvestController = TextEditingController();
  final TextEditingController fertilizerController = TextEditingController();
  final TextEditingController irrigationController = TextEditingController();

  bool _isLoading = false;
  String? _resultText;
  bool _isError = false;

  @override
  void dispose() {
    regionController.dispose();
    soilTypeController.dispose();
    cropController.dispose();
    weatherController.dispose();
    rainfallController.dispose();
    temperatureController.dispose();
    daysToHarvestController.dispose();
    fertilizerController.dispose();
    irrigationController.dispose();
    super.dispose();
  }

  bool? _parseBool(String raw) {
    final v = raw.trim().toLowerCase();
    if (v == "true" || v == "yes" || v == "1") return true;
    if (v == "false" || v == "no" || v == "0") return false;
    return null;
  }

  Future<void> _predict() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _isError = true;
        _resultText = "Please fill in all fields before predicting.";
      });
      return;
    }

    final fertilizerBool = _parseBool(fertilizerController.text);
    final irrigationBool = _parseBool(irrigationController.text);

    if (fertilizerBool == null || irrigationBool == null) {
      setState(() {
        _isError = true;
        _resultText =
            "Fertilizer Used and Irrigation Used must be 'true' or 'false'.";
      });
      return;
    }

    final rainfall = double.tryParse(rainfallController.text);
    final temperature = double.tryParse(temperatureController.text);
    final daysToHarvest = int.tryParse(daysToHarvestController.text);

    if (rainfall == null || temperature == null || daysToHarvest == null) {
      setState(() {
        _isError = true;
        _resultText =
            "Rainfall, Temperature, and Days to Harvest must be numbers.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _resultText = null;
      _isError = false;
    });

    final payload = {
      "Region": regionController.text.trim(),
      "Soil_Type": soilTypeController.text.trim(),
      "Crop": cropController.text.trim(),
      "Weather_Condition": weatherController.text.trim(),
      "Rainfall_mm": rainfall,
      "Temperature_Celsius": temperature,
      "Days_to_Harvest": daysToHarvest,
      "Fertilizer_Used": fertilizerBool,
      "Irrigation_Used": irrigationBool,
    };

    try {
      final response = await http
          .post(
            Uri.parse("$baseUrl/predict"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final yieldValue = data["predicted_yield_tons_per_hectare"];
        setState(() {
          _isError = false;
          _resultText = "Predicted Yield: $yieldValue tons/hectare";
        });
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        final details = data["detail"];
        String message = "One or more values are out of the allowed range.";
        if (details is List && details.isNotEmpty) {
          final firstError = details.first;
          final field = (firstError["loc"] as List).last;
          final msg = firstError["msg"];
          message = "$field: $msg";
        }
        setState(() {
          _isError = true;
          _resultText = message;
        });
      } else {
        setState(() {
          _isError = true;
          _resultText = "Error (${response.statusCode}): ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _isError = true;
        _resultText = "Could not reach the prediction service: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return "$label is required";
          }
          return null;
        },
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              backgroundColor: Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              pinned: true,
              expandedHeight: 96,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.only(left: 20, bottom: 14),
                title: Text(
                  "AgriPoints",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                background: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF2E7D32)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          "Enter farming activity details to predict crop "
                          "yield and earn reward points.",
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                      ),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionLabel(
                                "FARM LOCATION", Icons.location_on_outlined),
                            _buildTextField(
                              controller: regionController,
                              label: "Region",
                              hint: "East, North, South, or West",
                            ),
                            _buildTextField(
                              controller: soilTypeController,
                              label: "Soil Type",
                              hint: "Chalky, Clay, Loam, Peaty, Sandy, or Silt",
                            ),
                          ],
                        ),
                      ),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionLabel(
                                "CROP & CONDITIONS", Icons.eco_outlined),
                            _buildTextField(
                              controller: cropController,
                              label: "Crop",
                              hint:
                                  "Barley, Cotton, Maize, Rice, Soybean, or Wheat",
                            ),
                            _buildTextField(
                              controller: weatherController,
                              label: "Weather Condition",
                              hint: "Cloudy, Rainy, or Sunny",
                            ),
                            _buildTextField(
                              controller: rainfallController,
                              label: "Rainfall (mm)",
                              hint: "Range: 100 - 1000",
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            _buildTextField(
                              controller: temperatureController,
                              label: "Temperature (Celsius)",
                              hint: "Range: 15 - 40",
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                            ),
                            _buildTextField(
                              controller: daysToHarvestController,
                              label: "Days to Harvest",
                              hint: "Range: 60 - 149",
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ),
                      _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _sectionLabel("FARMING PRACTICES",
                                Icons.agriculture_outlined),
                            _buildTextField(
                              controller: fertilizerController,
                              label: "Fertilizer Used",
                              hint: "true or false",
                            ),
                            _buildTextField(
                              controller: irrigationController,
                              label: "Irrigation Used",
                              hint: "true or false",
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _predict,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  "Predict",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_resultText != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _isError
                                ? const Color(0xFFFDECEA)
                                : const Color(0xFFE8F5E9),
                            border: Border.all(
                              color: _isError
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF2E7D32),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                _isError
                                    ? Icons.error_outline
                                    : Icons.check_circle_outline,
                                color: _isError
                                    ? const Color(0xFFD32F2F)
                                    : const Color(0xFF2E7D32),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _resultText!,
                                  style: TextStyle(
                                    color: _isError
                                        ? const Color(0xFFB71C1C)
                                        : const Color(0xFF1B5E20),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
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
