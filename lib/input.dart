import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class TrafficAnalysisApp extends StatelessWidget {
  final Map<String, dynamic> location;
  const TrafficAnalysisApp({Key? key, required this.location}): super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreetInputScreen(location: this.location),
    );
  }
}

class StreetInputScreen extends StatefulWidget {
  final Map<String, dynamic> location;
  const StreetInputScreen({Key? key, required this.location}): super(key: key);
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
    String streetName = widget.location['address']['road'] ?? ""; // ✅ Extract street name
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

  Widget _buildSectionTitle(String title) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16.0),
    child: Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    ),
  );
}

Widget _buildVolumeAnalysis() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Most and least congested hours
      Row(
        children: [
          Expanded(
            child: _buildInfoCard(
              "Most Congested Hour",
              "${data['most_congested_hour']['idxmax']}:00",
              "Avg Volume: ${data['most_congested_hour']['max']}",
              Icons.arrow_upward,
              Colors.red,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildInfoCard(
              "Least Congested Hour",
              "${data['least_congested_hour']['idxmin']}:00",
              "Avg Volume: ${data['least_congested_hour']['min']}",
              Icons.arrow_downward,
              Colors.green,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      
      // Hourly volume chart
      _buildImage(data['hour_plot']),
    ],
  );
}

Widget _buildSafetyAnalysis() {
  if (data['safety_metrics'] == null) return const SizedBox.shrink();
  
  final safetyMetrics = data['safety_metrics'];
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Safety metrics in cards
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
      _buildImage(data['accidents']),
    ],
  );
}

Widget _buildTrendAnalysis() {
  if (data['trend_analysis'] == null) return const SizedBox.shrink();
  
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
      Row(
        children: [
          Expanded(
            child: _buildInfoCard(
              "Volume Growth",
              formatGrowth(volumeGrowth),
              "Year over Year",
              volumeGrowth != null && volumeGrowth > 0 ? Icons.trending_up : Icons.trending_down,
              volumeGrowth != null && volumeGrowth > 0 ? Colors.red : Colors.green,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildInfoCard(
              "Accident Growth",
              formatGrowth(accidentGrowth),
              "Year over Year",
              accidentGrowth != null && accidentGrowth > 0 ? Icons.trending_up : Icons.trending_down,
              accidentGrowth != null && accidentGrowth > 0 ? Colors.red : Colors.green,
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

Widget _buildRiskAnalysis() {
  if (data['risk_analysis'] == null) return const SizedBox.shrink();
  
  final riskAnalysis = data['risk_analysis'];
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Risk metrics
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

Widget _buildInfoCard(String title, String value, String subtitle, IconData icon, Color color) {
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

//   @override
//   Widget build(BuildContext context) {
//     return Expanded(
//         child: Column(children: [
//       Text(
//         "${data['street_name']}",
//         style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
//       ), //data['most_congested_hour']['street'][0] didnt work for some reason, idk why
//       Flexible(
//           child: SingleChildScrollView(
//         child: Center(child:Column(
//           children: [
//             SizedBox(
//               height: 8,
//             ),
//             Wrap(children: [
//               Row(children:[
//                 _Stats(
//                 title: "Most Congested Hour",
//                 value: data['most_congested_hour']['idxmax'],
//                 volume: data['most_congested_hour']['max'],
//               ),
//               SizedBox(width: 50,),
//               _Stats(
//                   title: "Least Congested Hour",
//                   value: data['least_congested_hour']['idxmin'],
//                   volume: data['least_congested_hour']['min']),
//               // Text("${data['boro_volume']['Boro']} has an average volume of : ${data['boro_volume']['Vol']}")
//               ]),
//               SizedBox(
//                 height: 400,
//                 width: 600,
//                 child: Image.memory(base64Decode(data["hour_plot"])),
//               ),
//               SizedBox(width: 50,),
//               SizedBox(
//                 height: 400,
//                 width: 600,
//                 child: Image.memory(base64Decode(data["accidents"])),
//               ),
//               SizedBox(width: 50,),
//               SizedBox(
//                 height: 400,
//                 width: 600,
//                 child: Image.memory(base64Decode(data["vehicle_types"])),
//               ),
//             ]),
//             // Text(
//             //     "Most Congested Hour: ${data['most_congested_hour']['idxmax']} (Volume: ${data['most_congested_hour']['max']})",
//             //     style: const TextStyle(
//             //       fontSize: 20,
//             //     )), // fetching max and all from a dictionary
//             // Text(
//             //     "Least Congested Hour: ${data['least_congested_hour']['idxmin']} (Volume: ${data['least_congested_hour']['min']})",
//             //     style: const TextStyle(
//             //       fontSize: 20,
//             //     )),
//             SizedBox(height: 10),
//             // Text("Traffic Volume per Hour:"),
//             // for (var entry in data['hourly_volume'])
//             //   Text("Hour ${entry['HH']}: ${entry['Vol']}"),
//             // SizedBox(height: 10),
//             // Text("Yearly Trend (Mean & Std Dev):"),
//             // for (var entry in data['yearly_trend'])
//             //   Text("Year ${entry['Yr']}: Mean=${entry['mean']}, Std=${entry['std']}"),
//           ],
//         ),)
//       ))
//     ]));
//   }
// }

@override
Widget build(BuildContext context) {
  return Expanded(
    child: Column(
      children: [
        Text(
          "${data['street_name']}",
          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Traffic Volume Analysis
                  _buildSectionTitle("Traffic Volume Analysis"),
                  _buildVolumeAnalysis(),
                  
                  // Safety and Accident Analysis
                  _buildSectionTitle("Safety Analysis"),
                  _buildSafetyAnalysis(),
                  
                  // Vehicles Involved in Accidents
                  _buildSectionTitle("Vehicles Involved in Accidents"),
                  _buildImage(data['vehicle_types']),
                  
                  // Trend Analysis
                  // _buildSectionTitle("Trend Analysis"),
                  // _buildTrendAnalysis(),
                  
                  // Risk Analysis
                  _buildSectionTitle("Risk Assessment"),
                  _buildRiskAnalysis(),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}}

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

















