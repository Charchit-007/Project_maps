import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class TrafficAnalysisApp extends StatelessWidget {
  final Map<String, dynamic> location;
  const TrafficAnalysisApp({Key? key, required this.location})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(primaryColor: Color(0xFF1E293B), scaffoldBackgroundColor: const Color(0xFF1E293B)),
      home: StreetInputScreen(location: this.location),
    );
  }
}

class StreetInputScreen extends StatefulWidget {
  final Map<String, dynamic> location;
  const StreetInputScreen({Key? key, required this.location}) : super(key: key);
  @override
  _StreetInputScreenState createState() => _StreetInputScreenState();
}

class _StreetInputScreenState extends State<StreetInputScreen> {
  TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? analysisResult;
  bool isLoading = false;
  String errorMessage = "";

  Future<void> fetchAnalysis(String street) async {
    setState(() {
      isLoading = true;
      errorMessage = "";
    });

    try {
      final response = await http.get(
          Uri.parse("http://127.0.0.1:5000/street_analysis?street=$street"));

      if (response.statusCode == 200) {
        setState(() {
          analysisResult = jsonDecode(response.body);
          print(jsonDecode(response.body));
        });
      } else {
        setState(() {
          errorMessage =
              jsonDecode(response.body)['error'] ?? "Something went wrong!";
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to connect to server.";
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    String streetName =
        widget.location['address']['road'] ?? ""; // ✅ Extract street name
    _controller = TextEditingController(text: streetName); // ✅ Pre-fill input
    fetchAnalysis(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Traffic Analysis")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // TextField(
            //   controller: _controller,
            //   decoration: InputDecoration(
            //     labelText: "Enter Street Name",
            //     border: OutlineInputBorder(),
            //   ),
            // ),
            SizedBox(height: 10),
            // ElevatedButton(
            //   onPressed: () {
            //     if (_controller.text.isNotEmpty) {
            //       fetchAnalysis(_controller.text);
            //     }
            //   },
            //   child: Text("Get Analysis"),
            // ),
            SizedBox(height: 20),
            if (isLoading) CircularProgressIndicator(),
            if (errorMessage.isNotEmpty)
              Text(errorMessage, style: TextStyle(color: Colors.red)),
            if (analysisResult != null)
              AnalysisResultWidget(data: analysisResult!),
          ],
        ),
      ),
    );
  }
}

class AnalysisResultWidget extends StatelessWidget {
  final Map<String, dynamic> data;

  AnalysisResultWidget({required this.data});

  Widget _buildSectionTitle(String title, Icon icon) {
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(children: [
          Icon(icon.icon),
          SizedBox(width: 8), // Add spacing between icon and text
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ]));
  }

  Widget _buildVolumeAnalysis(bool isMobile) {
    // ------ Volume analysis displ
    if (data['volume_metrics'] == null)
      return const SizedBox(
        child: Text(
          "No data found.",
          style: TextStyle(color: Colors.red),
        ),
      );

    return ConstrainedBox(
        constraints: BoxConstraints(minHeight: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,

          children: [
            // Most and least congested hours
            if (isMobile)
              Column(
                children: [
                  _buildInfoCard(
                    "Most Congested Hour",
                    "${data['volume_metrics']['most_congested_hour']['idxmax']['0']}:00",
                    "Avg Volume: ${data['volume_metrics']['most_congested_hour']['max']['0']}",
                    Icons.arrow_upward,
                    Colors.red,
                  ),
                  SizedBox(height: 16),
                  _buildInfoCard(
                    "Least Congested Hour",
                    "${data['volume_metrics']['least_congested_hour']['idxmin']['0']}:00",
                    "Avg Volume: ${data['volume_metrics']['least_congested_hour']['min']['0']}",
                    Icons.arrow_downward,
                    Colors.green,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      "Most Congested Hour",
                      "${data['volume_metrics']['most_congested_hour']['idxmax']['0']}:00",
                      "Avg Volume: ${data['volume_metrics']['most_congested_hour']['max']['0']}",
                      Icons.arrow_upward,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInfoCard(
                      "Least Congested Hour",
                      "${data['volume_metrics']['least_congested_hour']['idxmin']['0']}:00",
                      "Avg Volume: ${data['volume_metrics']['least_congested_hour']['min']['0']}",
                      Icons.arrow_downward,
                      Colors.green,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Hourly volume chart
            _buildImage(data['volume_metrics']['hour_plot']),
          ],
        ));
  }

  Widget _buildCorrelationAnalysis() {
    if (data['correlation'] == null) {
      return const SizedBox(
        child: Text(
          "No correlation data found.",
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    final correlation = data['correlation'];
    final corrValue = correlation['corr'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Volume-Accident Correlation Analysis",
          ),
        ),

        // Correlation Card
        Card(
          elevation: 2,
          margin: const EdgeInsets.all(16.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      "Correlation Coefficient",
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    corrValue.toStringAsFixed(3),
                    style: TextStyle(
                      color: _getCorrelationColor(corrValue),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _getCorrelationDescription(corrValue),
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Scatter Plot
        if (correlation['corr_scatter'] != null) ...[
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              "Volume vs Accident Distribution",
            ),
          ),
          Card(
            elevation: 2,
            margin: const EdgeInsets.all(16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildImage(correlation['corr_scatter']),
                  const SizedBox(height: 8),
                  Text(
                    "The trend line (red) shows the relationship between traffic volume and accident frequency",
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getCorrelationColor(double correlation) {
    final absCorr = correlation.abs();
    if (absCorr >= 0.7) {
      return Colors.red;
    } else if (absCorr >= 0.4) {
      return Colors.orange;
    } else if (absCorr >= 0.2) {
      return Colors.yellow[700]!;
    } else {
      return Colors.green;
    }
  }

  String _getCorrelationDescription(double correlation) {
    final absCorr = correlation.abs();
    if (absCorr >= 0.7) {
      return "Strong ${correlation > 0 ? 'positive' : 'negative'} correlation";
    } else if (absCorr >= 0.4) {
      return "Moderate ${correlation > 0 ? 'positive' : 'negative'} correlation";
    } else if (absCorr >= 0.2) {
      return "Weak ${correlation > 0 ? 'positive' : 'negative'} correlation";
    } else {
      return "Very weak or no correlation";
    }
  }

  Widget _buildSafetyAnalysis(bool isMobile) {
    if (data['safety_metrics'] == null)
      return const SizedBox(
        child: Text(
          "No data found.",
          style: TextStyle(color: Colors.red),
        ),
      );
    final safetyMetrics = data['safety_metrics'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Safety metrics in cards
        if (isMobile)
          Column(
            children: [
              _buildInfoCard(
                "Total Accidents",
                "${safetyMetrics['total_accidents']}",
                "",
                Icons.car_crash,
                Colors.amber,
              ),
              SizedBox(height: 16),
              _buildInfoCard(
                "Total Injuries",
                "${safetyMetrics['total_injuries']}",
                "Severity Ratio: ${safetyMetrics['severity_ratio']}",
                Icons.local_hospital,
                Colors.orange,
              ),
              SizedBox(height: 16),
              _buildInfoCard(
                "Total Fatalities",
                "${safetyMetrics['total_fatalities']}",
                "",
                Icons.dangerous,
                Colors.red,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  "Total Accidents",
                  "${safetyMetrics['total_accidents']}",
                  "",
                  Icons.car_crash,
                  Colors.amber,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  "Total Injuries",
                  "${safetyMetrics['total_injuries']}",
                  "Severity Ratio: ${safetyMetrics['severity_ratio']}",
                  Icons.local_hospital,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  "Total Fatalities",
                  "${safetyMetrics['total_fatalities']}",
                  "",
                  Icons.dangerous,
                  Colors.red,
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),

        // Accidents by hour chart
        Text(
          "Accidents Distribution by Hour",
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildImage(safetyMetrics['accidents']),

        // Vehicles Involved in Accidents
        _buildSectionTitle(
            "Vehicles Involved in Accidents", Icon(Icons.car_crash_rounded)),
        _buildImage(safetyMetrics['vehicle_types']),
      ],
    );
  }

  Widget _buildTrendAnalysis(bool isMobile) {
    if (data['trend_analysis'] == null)
      return const SizedBox(
        child: Text(
          "No data found.",
          style: TextStyle(color: Colors.red),
        ),
      );

    final trendAnalysis = data['trend_analysis'];
    final volumeGrowth = trendAnalysis['volume_growth'];
    final accidentGrowth = trendAnalysis['accident_growth'];

    String formatGrowth(double? value) {
      if (value == null) return "N/A";
      final percentage = (value * 100).toStringAsFixed(1);
      return value >= 0 ? "+$percentage%" : "$percentage%";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Growth metrics
        if (isMobile)
          Column(
            children: [
              _buildInfoCard(
                "Volume Growth",
                formatGrowth(volumeGrowth),
                "Year over Year",
                volumeGrowth != null && volumeGrowth > 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                volumeGrowth != null && volumeGrowth > 0
                    ? Colors.red
                    : Colors.green,
              ),
              SizedBox(height: 16),
              _buildInfoCard(
                "Accident Growth",
                formatGrowth(accidentGrowth),
                "Year over Year",
                accidentGrowth != null && accidentGrowth > 0
                    ? Icons.trending_up
                    : Icons.trending_down,
                accidentGrowth != null && accidentGrowth > 0
                    ? Colors.red
                    : Colors.green,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  "Volume Growth",
                  formatGrowth(volumeGrowth),
                  "Year over Year",
                  volumeGrowth != null && volumeGrowth > 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  volumeGrowth != null && volumeGrowth > 0
                      ? Colors.red
                      : Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  "Accident Growth",
                  formatGrowth(accidentGrowth),
                  "Year over Year",
                  accidentGrowth != null && accidentGrowth > 0
                      ? Icons.trending_up
                      : Icons.trending_down,
                  accidentGrowth != null && accidentGrowth > 0
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),

        // Trend chart
        _buildImage(trendAnalysis['trend_plot']),
      ],
    );
  }

  Widget _buildRiskAnalysis(bool isMobile) {
    if (data['risk_analysis'] == null)
      return const SizedBox(
        child: Text(
          "No data found.",
          style: TextStyle(color: Colors.red),
        ),
      );

    final riskAnalysis = data['risk_analysis'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Risk metrics
        if (isMobile)
          Column(
            children: [
              _buildInfoCard(
                "Riskiest Hour",
                "${riskAnalysis['riskiest_hour']}:00",
                "Risk Factor: ${riskAnalysis['risk_ratio'].toStringAsFixed(2)}",
                Icons.warning,
                Colors.deepOrange,
              ),
              SizedBox(height: 16),
              _buildInfoCard(
                "Peak Volume Hour",
                "${riskAnalysis['peak_volume_hour']}:00",
                "",
                Icons.timeline,
                Colors.blue,
              ),
              SizedBox(height: 16),
              _buildInfoCard(
                "Peak Accident Hour",
                "${riskAnalysis['peak_accident_hour']}:00",
                "",
                Icons.car_crash,
                Colors.red,
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  "Riskiest Hour",
                  "${riskAnalysis['riskiest_hour']}:00",
                  "Risk Factor: ${riskAnalysis['risk_ratio'].toStringAsFixed(2)}",
                  Icons.warning,
                  Colors.deepOrange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  "Peak Volume Hour",
                  "${riskAnalysis['peak_volume_hour']}:00",
                  "",
                  Icons.timeline,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoCard(
                  "Peak Accident Hour",
                  "${riskAnalysis['peak_accident_hour']}:00",
                  "",
                  Icons.car_crash,
                  Colors.red,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),

        // Risk analysis chart
        if (riskAnalysis['risk_plot'] != null)
          _buildImage(riskAnalysis['risk_plot']),
      ],
    );
  }

  Widget _buildBlockageAnalysis(bool isMobile) {
    if (data['blockages'] == null) {
      return const SizedBox(
        child: Text(
          "No blockage data found.",
          style: TextStyle(color: Colors.red),
        ),
      );
    }

    final blockages = data['blockages'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Blockage metrics
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(
                "Total Blockages",
                "${blockages['total_blockages']}",
                "",
                Icons.block,
                Colors.red,
              ),
              SizedBox(height: 16),
              Text(
                "On-going Blockages",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: Card(
                  elevation: 10,
                  child: ListView.builder(
                    physics: AlwaysScrollableScrollPhysics(),
                    itemCount: blockages['active_blockages'].length,
                    itemBuilder: (context, index) {
                      var blockage = blockages['active_blockages'][index];
                      return ListTile(
                        leading: Icon(Icons.warning, color: Colors.orange),
                        title: Text(blockage["Reason"] ?? "Unknown"),
                        subtitle: Text(
                            "Location: ${blockage['From Street']} → ${blockage['To Street']}\n"
                            "From: ${blockage['From Date']} | To: ${blockage['To Date']}"),
                      );
                    },
                  ),
                ),
              )
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  "Total Blockages",
                  "${blockages['total_blockages']}",
                  "",
                  Icons.block,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "On-going Blockages - ",
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(
                    height: 200,
                    child: Card(
                      elevation: 10,
                      child: ListView.builder(
                        physics: AlwaysScrollableScrollPhysics(),
                        itemCount: blockages['active_blockages'].length,
                        itemBuilder: (context, index) {
                          var blockage = blockages['active_blockages'][index];
                          return ListTile(
                            leading: Icon(Icons.warning, color: Colors.orange),
                            title: Text(blockage["Reason"] ?? "Unknown"),
                            subtitle: Text(
                                "Location: ${blockage['From Street']} → ${blockage['To Street']}\n"
                                "From: ${blockage['From Date']} | To: ${blockage['To Date']}"),
                          );
                        },
                      ),
                    ),
                  )
                ],
              )),
            ],
          ),
        const SizedBox(height: 24),

        // Common reasons section
        Text(
          "Common Reasons for Blockages",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        _buildCommonReasons(blockages['com_reason']),
        const SizedBox(height: 24),

        // Monthly pattern chart
        Text(
          "Monthly Blockage Patterns",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (blockages['monthly_pattern'] != null)
          _buildImage(blockages['monthly_pattern']),
      ],
    );
  }

  Widget _buildCommonReasons(Map<String, dynamic> reasons) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: reasons.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  Text(
                    "${entry.value}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
      String title, String value, String subtitle, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String? base64Image) {
    if (base64Image == null || base64Image.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text("No chart available")),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      height: 300,
      width: double.infinity,
      child: Image.memory(
        base64Decode(base64Image),
        fit: BoxFit.contain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we're on a mobile device based on screen width
    bool isMobile = MediaQuery.of(context).size.width < 768;

    return Expanded(
      child: Column(
        children: [
          Text(
            "${data['street_name']}",
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 8.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Traffic Volume Analysis
                    _buildSectionTitle(
                        "Traffic Volume Analysis", Icon(Icons.traffic)),
                    _buildVolumeAnalysis(isMobile),

                    Divider(
                      thickness: 2,
                      color: Colors.grey[400],
                    ),

                    // Safety and Accident Analysis
                    _buildSectionTitle(
                        "Safety Analysis", Icon(Icons.health_and_safety)),
                    _buildSafetyAnalysis(isMobile),

                    Divider(
                      color: Colors.grey[400],
                    ),

                    // Trend Analysis
                    _buildSectionTitle("Trend Analysis", Icon(Icons.trending_up)),
                    _buildTrendAnalysis(isMobile),

                    Divider(
                      color: Colors.grey[400],
                    ),

                    // Risk Analysis
                    _buildSectionTitle(
                        "Risk Assessment", Icon(Icons.dangerous)),
                    _buildRiskAnalysis(isMobile),

                    Divider(
                      color: Colors.grey[400],
                    ),

                    // Blockage analysis
                    _buildSectionTitle("Road Blockages", Icon(Icons.block)),
                    _buildBlockageAnalysis(isMobile),

                    Divider(
                      thickness: 2,
                      color: Colors.grey[400],
                    ),
                    
                    // Correlation Analysis
                    _buildSectionTitle(
                        "Correlation Analysis", Icon(Icons.grain_sharp)),
                    _buildCorrelationAnalysis(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  final String title;
  late var value;
  late var volume;
  _Stats({
    super.key,
    required this.title,
    required this.value,
    required this.volume,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        // Constrain width here
        width: 300,
        child: Card(
            // CARD implementation
            elevation: 20,
            color: Colors.grey[600],
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(50),
                  )),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("${title}: ${value.values.first}",
                      style: const TextStyle(
                        fontSize: 16,
                      )),
                  Text("Volume: ${volume.values.first}",
                      style: const TextStyle(
                        fontSize: 12,
                      ))
                ],
              ),
            )));
  }
}