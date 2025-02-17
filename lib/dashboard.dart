import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';

import 'package:osm_route_suggestion/main.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? trafficData;

  @override
  void initState() {
    super.initState();
    fetchTrafficData();
  }

  // Fetch traffic data with timeout and log request time
  Future<void> fetchTrafficData() async {
    final startTime = DateTime.now(); // Record start time

    try {
      final response = await http
          .get(Uri.parse('http://localhost:5000/traffic-analysis'))
          .timeout(Duration(seconds: 30)); // Set timeout to 30 seconds

      final endTime = DateTime.now(); // Record end time
      print(
          'Request Time: ${endTime.difference(startTime).inMilliseconds} ms'); // Log request time

      if (response.statusCode == 200) {
        setState(() {
          trafficData = json.decode(response.body);
        });
      } else {
        throw Exception('Failed to load traffic data');
      }
    } catch (e) {
      print('Error fetching data: $e');
      // Optionally show an error message in the UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.call_merge_sharp),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OpenStreetMapRouteApp(),
              ),
            );
          }),
      body: Column(
        children: [ 
          // Title Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: Colors.blueAccent,
            child: const Text(
              "Dashboard",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Left Panel: Scrollable Data Analysis with Graphs
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    margin: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          spreadRadius: 2,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: trafficData == null
                        ? const Center(
                            child:
                                CircularProgressIndicator()) // Show loading spinner
                        : SingleChildScrollView(
                            child: Column(
                              children: [
                                SizedBox(
                                  height:
                                      40, // Increased height for more space
                                ),
                                // Borough-wise Traffic Chart
                                // _buildChartTitle(
                                //     "Borough-wise Traffic Analysis"),
                                Text("Borough-wise Volume Analysis", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 23),),
                                SizedBox(
                                  height:
                                      450, // Increased height for more space
                                  child: _buildBarChart(
                                      trafficData!['Borough-wise Congestion']),
                                ),
                                const Divider(thickness: 17,color: Colors.black, ),
                                SizedBox(
                                  height:
                                      70, // Increased height for more space
                                ),

                                // Hourly Traffic Volume Chart
                                Text("Peak Traffic Hours", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 23),),
                                SizedBox(
                                  height:
                                      450, // Increased height for more space
                                  child: _buildBarChart(
                                      trafficData!['Hourly Traffic Volume']),
                                ),
                                const Divider(),

                                // Normal Data Analysis for other sections
                                _buildAnalysisSection(
                                  "Traffic by 3-Hour Intervals",
                                  trafficData!['Traffic by 3-Hour Intervals'],
                                ),
                                _buildAnalysisSection(
                                  "Top 10 Dangerous Streets",
                                  trafficData!['Top 10 Dangerous Streets'],
                                ),
                                _buildAnalysisSection(
                                  "Most Common Causes of Accidents",
                                  trafficData![
                                      'Most Common Causes of Accidents'],
                                ),
                                _buildAnalysisSection(
                                  "Accidents by Vehicle Type",
                                  trafficData!['Accidents by Vehicle Type'],
                                ),
                              ],
                            ),
                          ),
                  ),
                ),

                // Right Panel: Map
                Expanded(
                    flex: 2,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            // Provide a fixed size or use a color to ensure the FittedBox has dimensions
                            height: double.infinity,
                            width: double.infinity,
                            color: Colors.grey.shade200, // Fallback color
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: Image.asset(
                                'assets/img1.jpg',
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(Icons.image_not_supported,
                                      size: 100, color: Colors.grey);
                                },
                              ),
                            ),
                          ),
                        ),

                        // ... rest of your Stack children
                      ],
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Chart Title Helper
  Widget _buildChartTitle(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8.0),
      color: Colors.blueAccent,
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  // Bar Chart Helper
  Widget _buildBarChart(Map<String, dynamic> data) {
    final List<BarChartGroupData> barGroups = [];

    data.forEach((key, value) {
      barGroups.add(
        BarChartGroupData(
          x: int.tryParse(key) ??
              barGroups.length, // Convert string keys to integer indices
          barRods: [BarChartRodData(toY: value.toDouble())],
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: barGroups,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50, // Reduced reservedSize for Y-axis titles
                getTitlesWidget: (value, _) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                      fontSize: 10), // Smaller text size to fit more values
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (value, _) =>
                    Text(data.keys.toList()[value.toInt()]),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  // Data Analysis Section (Normal Analysis for Text-Based Data)
  Widget _buildAnalysisSection(String title, dynamic data) {
    if (data == null) return Container(); // Skip if no data

    List<Widget> items = [];
    if (data is Map) {
      items = data.entries
          .map((entry) => ListTile(title: Text('${entry.key}: ${entry.value}')))
          .toList();
    } else if (data is List) {
      items = data
          .map<Widget>((item) => ListTile(title: Text(item.toString())))
          .toList();
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Card(
        elevation: 5,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ...items,
            ],
          ),
        ),
      ),
    );
  }
}
