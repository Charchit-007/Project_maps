// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:osm_route_suggestion/main.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? trafficData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTrafficData();
  }

  // Fetch traffic data with timeout and log request time
  Future<void> fetchTrafficData() async {
    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:5000/traffic-analysis'))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        setState(() {
          trafficData = json.decode(response.body);
          isLoading = false;
        });
        print(
            'Traffic data loaded successfully: ${trafficData?.keys.toList()}');
      } else {
        throw Exception('Failed to load traffic data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111826),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar with Navigation
            _buildAppBar(),

            // Main Content
            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF8B5CF6),
                      ),
                    )
                  : _buildDashboardContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                child: SizedBox(
                    height: 50,
                    child: Image.asset(
                      'assets/app_logo.png',
                      fit: BoxFit.cover,
                    )),
              ),
              const SizedBox(width: 16),
              const Text(
                "RoutEx",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          // Add Map button here
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapsPage(),
                ),
              );
            },
            icon: const Icon(Icons.map, color: Colors.white),
            label: const Text("Map"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (trafficData == null) {
      return const Center(
        child: Text(
          "No data available",
          style: TextStyle(color: Colors.white60),
        ),
      );
    }

    // Check if we're on a mobile device
    final screenWidth = MediaQuery.of(context).size.width;
    bool isMobile = screenWidth < 800;

    // Log screen information for debugging
    print('Screen width: $screenWidth, isMobile: $isMobile');

    if (isMobile) {
      // Mobile layout (ladder form)
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBoroughSummary(isMobile: true),
            const SizedBox(height: 24),
            _buildSection(
              title: "Borough-wise Traffic Analysis",
              child: _buildSyncfusionChart(
                  trafficData!['Borough-wise Congestion'], ChartType.column,
                  isMobile: true),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: "Peak Traffic Hours",
              child: _buildSyncfusionChart(
                  trafficData!['Hourly Traffic Volume'], ChartType.line,
                  isMobile: true),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: "Traffic by 3-Hour Intervals",
              child: _buildBoroughIntervalCharts(),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: "Most Common Causes of Accidents",
              child: _buildAnalysisCard(
                  trafficData!['Most Common Causes of Accidents']),
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: "Accidents by Vehicle Type",
              child:
                  _buildAnalysisCard(trafficData!['Accidents by Vehicle Type']),
            ),
            const SizedBox(height: 24),
            _buildDangerousStreetsSection(),
            const SizedBox(height: 24),
            _buildCTACard(), // Moved the banner to the bottom for mobile
          ],
        ),
      );
    } else {
      // Desktop layout with two-column approach - adjusted flex ratio
      return Container(
        color: const Color(0xFF111826), // Ensure background color is visible
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Content Area (60% instead of 70%)
            Expanded(
              flex: 6, // Changed from 7 to 6
              child: Container(
                color: const Color(0xFF111826),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBoroughSummary(),
                      const SizedBox(height: 24),
                      _buildSection(
                        title: "Borough-wise Traffic Analysis",
                        child: _buildSyncfusionChart(
                            trafficData!['Borough-wise Congestion'],
                            ChartType.column),
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        title: "Peak Traffic Hours",
                        child: _buildSyncfusionChart(
                            trafficData!['Hourly Traffic Volume'],
                            ChartType.line),
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        title: "Traffic by 3-Hour Intervals",
                        child: _buildBoroughIntervalCharts(),
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        title: "Most Common Causes of Accidents",
                        child: _buildAnalysisCard(
                            trafficData!['Most Common Causes of Accidents']),
                      ),
                      const SizedBox(height: 24),
                      _buildSection(
                        title: "Accidents by Vehicle Type",
                        child: _buildAnalysisCard(
                            trafficData!['Accidents by Vehicle Type']),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Right Sidebar (40% instead of 30%)
            Expanded(
              flex: 4, // Changed from 3 to 4
              child: Container(
                color: const Color(0xFF111826), // Debug color
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.only(top: 24, right: 24, bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildCTACard(),
                            const SizedBox(height: 16),
                            _buildDangerousStreetsSection(),
                          ],
                        ),
                      ),
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

  Widget _buildCTACard() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "State of New York",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Routex",
                  style: TextStyle(
                    color: Color(0xFF8B5CF6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 250,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/img1.jpg',
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MapsPage(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 20,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("Street Analysis"),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  // Icons

  Widget _buildBoroughSummary({bool isMobile = false}) {
    // Extract borough data
    final boroughData =
        trafficData!['Borough-wise Congestion'] as Map<String, dynamic>;

    if (boroughData.isEmpty) {
      return const SizedBox.shrink();
    }

    // Get top 3 boroughs
    final sortedBoroughs = boroughData.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
    final topBoroughs = sortedBoroughs.take(3).toList();

    // Fixed layout for both mobile and desktop - display all in one row
    return Container(
      width: double.infinity,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: topBoroughs.asMap().entries.map((entry) {
          final index = entry.key;
          final borough = entry.value.key;
          final volume = entry.value.value;

          IconData icon;
          Color color;
          String label;

          if (index == 0) {
            icon = Icons.warning_rounded;
            color = const Color(0xFFEF4444);
            label = "Highest Traffic";
          } else if (index == 1) {
            icon = Icons.warning_rounded;
            color = const Color(0xFFF59E0B);
            label = "Heavy Traffic";
          } else {
            icon = Icons.warning_rounded;
            color = const Color(0xFF10B981);
            label = "Moderate Traffic";
          }

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _buildMetricCard(
                title: borough,
                value: volume,
                subtext: label,
                icon: icon,
                color: color,
                isMobile: isMobile,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int value,
    String? change,
    bool isPositive = false,
    required String subtext,
    required IconData icon,
    required Color color,
    bool isMobile = false,
  }) {
    // Removed fixed width to allow cards to expand based on parent constraints
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color.fromARGB(231, 255, 255, 255),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if(!isMobile)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatNumberShort(value as int),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtext,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          if (change != null)
            Row(
              children: [
                Icon(
                  isPositive
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  color: isPositive
                      ? const Color(0xFF10B981)
                      : const Color(0xFFEF4444),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(
                    color: isPositive
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        child,
      ],
    );
  }

  // SyncFusion chart implementation with updated chart types and tooltip customization
  Widget _buildSyncfusionChart(Map<String, dynamic>? data, ChartType chartType,
      {bool isMobile = false}) {
    if (data == null || data.isEmpty) {
      return _buildEmptyCard("No chart data available");
    }

    // Convert data to ChartData format
    List<ChartData> chartData = [];
    data.forEach((key, value) {
      // For mobile, abbreviate borough names if needed
      String displayKey = key;
      if (isMobile && key.length > 7) {
        // Abbreviate names for small screens
        if (key == "Manhattan")
          displayKey = "Man";
        else if (key == "Brooklyn")
          displayKey = "Bklyn";
        else if (key == "Queens")
          displayKey = "Qns";
        else if (key == "Bronx")
          displayKey = "Bx";
        else if (key == "Staten Island")
          displayKey = "SI";
        else
          // ignore: prefer_interpolation_to_compose_strings
          displayKey = key.substring(0, 6) + "..."; // Fallback abbreviation
      }
      chartData.add(ChartData(key, displayKey, (value as num).toDouble()));
    });

    // Calculate maximum bars that can fit well
    double maxBarWidth =
        0.4; // Adjust column width (smaller value = thinner bars)

    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SfCartesianChart(
        primaryXAxis: CategoryAxis(
          labelStyle: const TextStyle(color: Colors.white60),
          majorGridLines: const MajorGridLines(width: 0),
          maximumLabels: isMobile ? 4 : 6, // Limit labels on mobile
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(color: Colors.white60),
          majorGridLines: const MajorGridLines(
            width: 1,
            color: Colors.grey,
            dashArray: <double>[5, 5],
          ),
          numberFormat: NumberFormat.compact(), // Uses shortform like 20M, 30M
        ),
        tooltipBehavior: TooltipBehavior(
          enable: true,
          // Remove "Series: " text from tooltip
          format: 'point.x: point.y',
          // Custom tooltip builder if needed
          builder: (dynamic data, dynamic point, dynamic series, int pointIndex,
              int seriesIndex) {
            ChartData chartPoint = data;
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF2D3748),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${chartPoint.original}: ${chartPoint.y.toInt()}',
                style: const TextStyle(color: Colors.white),
              ),
            );
          },
        ),
        series: <CartesianSeries>[
          if (chartType == ChartType.column)
            ColumnSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (ChartData data, _) => data.x,
              yValueMapper: (ChartData data, _) => data.y,
              name: '', // Empty name to remove "Series: " from tooltip
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(4),
              width: maxBarWidth, // Make columns thinner
              spacing: 0.2, // Space between columns
            )
          else if (chartType == ChartType.bar)
            BarSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (ChartData data, _) => data.x,
              yValueMapper: (ChartData data, _) => data.y,
              name: '', // Empty name to remove "Series: " from tooltip
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(4),
              width: maxBarWidth, // Make bars thinner
            )
          else if (chartType == ChartType.line)
            LineSeries<ChartData, String>(
              dataSource: chartData,
              xValueMapper: (ChartData data, _) => data.x,
              yValueMapper: (ChartData data, _) => data.y,
              name: '', // Empty name to remove "Series: " from tooltip
              color: const Color(0xFF8B5CF6),
              width: 3,
              markerSettings: const MarkerSettings(
                isVisible: true,
                shape: DataMarkerType.circle,
                color: Color(0xFF8B5CF6),
                borderColor: Colors.white,
                borderWidth: 2,
              ),
            ),
        ],
        plotAreaBorderWidth: 0,
        backgroundColor: Colors.transparent,
      ),
    );
  }

  Widget _buildBoroughIntervalCharts() {
    final intervalGraphsData =
        trafficData!['Traffic by 3-Hour Intervals'] as Map<String, dynamic>;

    if (intervalGraphsData.isEmpty) {
      return _buildEmptyCard("No interval data available");
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: DefaultTabController(
        length: intervalGraphsData.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TabBar(
              isScrollable: true,
              tabs: intervalGraphsData.keys
                  .map((borough) => Tab(text: borough))
                  .toList(),
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.blue,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400, 
              child: TabBarView(
                children: intervalGraphsData.entries.map((entry) {
                  final borough = entry.key; // boro
                  final hourData = (entry.value as Map<String, dynamic>)
                      .entries // value are the list(json) of top 5 streets for a boro
                      .map((e) => BarData(
                          e.key,
                          int.parse(e.value
                              .toString()))) // e is each street inside the value(upar wala), storing the street and its count inside a BarData custom object
                      .toList();

                  // converts each street entry into a BarData object.

                  // return Padding(
                  //   padding: const EdgeInsets.all(16),
                  //   child: SfCartesianChart(
                  //     primaryXAxis:
                  //         CategoryAxis(), // meaning it will display names of streets instead of numerical values.
                  //     title: ChartTitle(text: '$borough'),
                  //     series: <CartesianSeries<BarData, String>>[
                  //       BarSeries<BarData, String>(
                  //         dataSource: streetsData,
                  //         xValueMapper: (BarData data, _) => data
                  //             .street, // custom object se fetching street name and its count
                  //         yValueMapper: (BarData data, _) => data.count,
                  //         color: const Color(0xFF8B5CF6,
                  //       )
                  //   )],
                  //   ),
                  // );
                  return Padding(
                      padding: const EdgeInsets.all(16),
                      child: SfCartesianChart(
                        title: ChartTitle(text: '$borough'),
                        primaryXAxis: const CategoryAxis(
                          labelStyle: TextStyle(color: Colors.white60),
                          majorGridLines: MajorGridLines(width: 0),   // grid lines in the bg
                        ),
                        primaryYAxis: NumericAxis(
                          labelStyle: const TextStyle(color: Colors.white60),
                          majorGridLines: const MajorGridLines(
                            width: 1,
                            color: Colors.grey,
                            dashArray: <double>[5, 5],    // for the grid line, 5px hyphen and fir 5 px ka space in btwn
                          ),
                          numberFormat: NumberFormat
                              .compact(), // Uses shortform like 20M, 30M
                        ),
                        tooltipBehavior: TooltipBehavior(
                          enable: true, //enables tooltips when hovering
                          format: 'point.x: point.y',
                          builder: (dynamic data, dynamic point, dynamic series,
                              int pointIndex, int seriesIndex) {
                            BarData chartPoint = data;
                            return Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D3748),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${chartPoint.street}: ${chartPoint.count.toInt()}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            );
                          },
                        ),
                        // chart ka type
                        series: <CartesianSeries<BarData, String>>[
                          AreaSeries<BarData, String>(
                            dataSource: hourData,
                            xValueMapper: (BarData data, _) => data.street,
                            yValueMapper: (BarData data, _) => data.count,
                            color: Colors.blue
                                .withOpacity(0.3), // Light fill color
                            borderColor: Colors.blue,
                            borderWidth: 2,
                          )
                        ],
                      ));
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return _buildEmptyCard("No analysis data available");
    }

    List<Map<String, dynamic>> items = [];
    data.forEach((key, value) {
      items.add({
        'name': key,
        'value': value,
      });
    });

    // Sort by value for better visualization
    items.sort((a, b) => (b['value'] as num).compareTo(a['value'] as num));

    // Take top 5 items for cleaner display
    final displayItems = items.take(5).toList();

    // Calculate max value for percentage calculation
    final maxValue = displayItems.first['value'] as num;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...displayItems.map((item) => _buildAnalysisItem(
                item['name'],
                item['value'].toString(),
                (item['value'] as num) / maxValue,
                displayItems.indexOf(item),
              )),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(
      String name, String value, double percentage, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: const Color(0xFF2D3748),
              valueColor: AlwaysStoppedAnimation<Color>(
                index == 0
                    ? const Color(0xFF8B5CF6)
                    : index < 3
                        ? const Color(0xFF60A5FA)
                        : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildDangerousStreetsSection() {
  //   final dangerousStreetsData =
  //       trafficData!['Top 5 Dangerous Streets Graphs'] as Map<String, dynamic>;

  //   if (dangerousStreetsData.isEmpty) {
  //     return const SizedBox.shrink();
  //   }

  //   // Check if mobile view
  //   bool isMobile = MediaQuery.of(context).size.width < 800;

  //   return Container(
  //     decoration: isMobile ? BoxDecoration(
  //       color: const Color(0xFF1E293B),
  //       borderRadius: BorderRadius.circular(16),
  //     ) : null,
  //     padding: isMobile ? const EdgeInsets.all(16) : EdgeInsets.zero,
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         const Padding(
  //           padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //           child: Text(
  //             "Top Dangerous Streets",
  //             style: TextStyle(
  //               color: Colors.white,
  //               fontSize: 18,
  //               fontWeight: FontWeight.bold,
  //             ),
  //           ),
  //         ),
  //         DefaultTabController(
  //           length: dangerousStreetsData.length,
  //           child: Column(
  //             children: [
  //               TabBar(
  //                 isScrollable: true,
  //                 tabAlignment: TabAlignment.start,
  //                 dividerColor: Colors.transparent,
  //                 labelColor: const Color(0xFF8B5CF6),
  //                 unselectedLabelColor: Colors.white60,
  //                 indicatorColor: const Color(0xFF8B5CF6),
  //                 tabs: dangerousStreetsData.keys
  //                     .map((borough) => Tab(text: borough))
  //                     .toList(),
  //               ),
  //               SizedBox(
  //                 height: 400,
  //                 child: TabBarView(
  //                   children: dangerousStreetsData.entries.map((entry) {
  //                     final base64Image = entry.value;

  //                     return Padding(
  //                       padding: const EdgeInsets.all(16),
  //                       child: ClipRRect(
  //                         borderRadius: BorderRadius.circular(8),
  //                         child: Image.memory(
  //                           base64Decode(base64Image),
  //                           fit: BoxFit.contain,
  //                         ),
  //                       ),
  //                     );
  //                   }).toList(),
  //                 ),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildDangerousStreetsSection() {
  //   final dangerousStreetsData =
  //       trafficData!['Top 5 Dangerous Streets'] as Map<String, dynamic>;
  //   // ! ensures traffic data is non-null.

  //   if (dangerousStreetsData.isEmpty) {
  //     return const SizedBox.shrink();
  //   }

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const Padding(
  //         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //         child: Text(
  //           "Top Dangerous Streets",
  //           style: TextStyle(
  //             color: Colors.white,
  //             fontSize: 18,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //       ),
  //       DefaultTabController(
  //         length: dangerousStreetsData.length,
  //         child: Column(
  //           children: [
  //             TabBar(
  //               isScrollable: true,
  //               tabAlignment: TabAlignment.start,
  //               dividerColor: Colors.transparent,
  //               labelColor: const Color(0xFF8B5CF6),
  //               unselectedLabelColor: Colors.white60,
  //               indicatorColor: const Color(0xFF8B5CF6),
  //               tabs: dangerousStreetsData.keys
  //                   .map((borough) => Tab(text: borough))
  //                   .toList(), // as TabBar requires a list of widgets.
  //             ),
  //             SizedBox(
  //               height: 400, // Adjust height to prevent overflow
  //               child: TabBarView(
  //                 children: dangerousStreetsData.entries.map((entry) {
  //                   // forms a loop , entry is each item (boro)
  //                   final borough = entry.key; // boro
  //                   final streetsData = (entry.value as Map<String, dynamic>)
  //                       .entries // value are the list(json) of top 5 streets for a boro
  //                       .map((e) => BarData(
  //                           e.key,
  //                           int.parse(e.value
  //                               .toString()))) // e is each street inside the value(upar wala), storing the street and its count inside a BarData custom object
  //                       .toList();
  //                   // converts each street entry into a BarData object.

  //                   return Padding(
  //                     padding: const EdgeInsets.all(16),
  //                     child: SfCartesianChart(
  //                       primaryXAxis:
  //                           CategoryAxis(), // meaning it will display names of streets instead of numerical values.
  //                       title: ChartTitle(
  //                           text: 'Top 5 Dangerous Streets in $borough'),
  //                       series: <CartesianSeries<BarData, String>>[
  //                         BarSeries<BarData, String>(
  //                           dataSource: streetsData,
  //                           xValueMapper: (BarData data, _) => data
  //                               .street, // custom object se fetching street name and its count
  //                           yValueMapper: (BarData data, _) => data.count,
  //                           color: Colors.red,
  //                         )
  //                       ],
  //                     ),
  //                   );
  //                 }).toList(),
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildDangerousStreetsSection() {
  final dangerousStreetsData =
      trafficData!['Top 5 Dangerous Streets'] as Map<String, dynamic>;

  if (dangerousStreetsData.isEmpty) {
    return const SizedBox.shrink();
  }

  // Check if we're on a mobile device
  final screenWidth = MediaQuery.of(context).size.width;
  bool isMobile = screenWidth < 800;
  
  // State variable to track which street's data is selected
  Map<String, int?> selectedStreetData = {};

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          "Top Dangerous Streets",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      DefaultTabController(
        length: dangerousStreetsData.length,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              dividerColor: Colors.transparent,
              labelColor: const Color(0xFF8B5CF6),
              unselectedLabelColor: Colors.white60,
              indicatorColor: const Color(0xFF8B5CF6),
              tabs: dangerousStreetsData.keys
                  .map((borough) => Tab(text: borough))
                  .toList(),
            ),
            SizedBox(
              height: 400,
              child: TabBarView(
                children: dangerousStreetsData.entries.map((entry) {
                  final borough = entry.key;
                  
                  // Process street names for mobile view - add line breaks
                  List<BarData> streetsData = [];
                  (entry.value as Map<String, dynamic>).entries.forEach((e) {
                    String streetName = e.key;
                    
                    // For mobile view, add a line break in the middle of street names
                    if (isMobile && streetName.length > 10) {
                      // Find a space near the middle to break the text
                      int middle = streetName.length ~/ 2;
                      int breakPoint = streetName.indexOf(' ', middle - 5);
                      if (breakPoint == -1) breakPoint = streetName.lastIndexOf(' ', middle);
                      
                      // If a space is found, replace it with a newline
                      if (breakPoint != -1) {
                        streetName = streetName.substring(0, breakPoint) + 
                                    '\n' + 
                                    streetName.substring(breakPoint + 1);
                      }
                    }
                    
                    streetsData.add(BarData(
                      streetName,
                      int.parse(e.value.toString())
                    ));
                  });

                  return StatefulBuilder(
                    builder: (context, setState) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: SfCartesianChart(
                          primaryXAxis: CategoryAxis(
                            labelStyle: const TextStyle(color: Colors.white60),
                            majorGridLines: const MajorGridLines(width: 0),
                            labelIntersectAction: AxisLabelIntersectAction.none,
                            maximumLabels: 5,
                            labelPosition: ChartDataLabelPosition.outside,
                            plotOffset: isMobile ? 15 : 0,
                            labelAlignment: LabelAlignment.center,
                          ),
                          primaryYAxis: NumericAxis(
                            labelStyle: const TextStyle(color: Colors.white60),
                            majorGridLines: const MajorGridLines(
                              width: 1,
                              color: Colors.grey,
                              dashArray: <double>[5, 5],
                            ),
                          ),
                          margin: isMobile 
                              ? const EdgeInsets.fromLTRB(10, 10, 10, 30) 
                              : const EdgeInsets.all(10),
                          title: ChartTitle(
                            text: 'Top 5 Dangerous Streets in $borough',
                            textStyle: const TextStyle(color: Colors.white),
                          ),
                          onChartTouchInteractionUp: (ChartTouchInteractionArgs args) {
                            // Clear the selected data
                            if (selectedStreetData.isNotEmpty) {
                              setState(() {
                                selectedStreetData.clear();
                              });
                            }
                          },
                          series: <CartesianSeries<BarData, String>>[
                            BarSeries<BarData, String>(
                              dataSource: streetsData,
                              xValueMapper: (BarData data, _) => data.street,
                              yValueMapper: (BarData data, _) => data.count,
                              color: Colors.red,
                              width: isMobile ? 0.6 : 0.4,
                              // Use custom data labels based on selection
                              dataLabelSettings: DataLabelSettings(
                                isVisible: true,
                                builder: (dynamic data, dynamic point, dynamic series, 
                                        int pointIndex, int seriesIndex) {
                                  final BarData barData = data as BarData;
                                  // Only show data label if this street is selected
                                  if (selectedStreetData.containsKey(barData.street)) {
                                    return Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        barData.count.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  } else {
                                    return Container(); // Empty container when not selected
                                  }
                                },
                              ),
                              // Handle tap event on bar
                              onPointTap: (ChartPointDetails details) {
                                final pointIndex = details.pointIndex!;
                                final clickedStreet = streetsData[pointIndex].street;
                                final clickedCount = streetsData[pointIndex].count;
                                
                                setState(() {
                                  // If already selected, clear selection; otherwise, set selection
                                  if (selectedStreetData.containsKey(clickedStreet)) {
                                    selectedStreetData.clear();
                                  } else {
                                    selectedStreetData.clear();
                                    selectedStreetData[clickedStreet] = clickedCount;
                                  }
                                });
                              },
                            )
                          ],
                          tooltipBehavior: TooltipBehavior(
                            enable: true,
                            format: 'Count: point.y',
                            header: '',
                            canShowMarker: false,
                          ),
                        ),
                      );
                    }
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

  Widget _buildEmptyCard(String message) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white60),
        ),
      ),
    );
  }
}

// Enhanced helper class for SyncFusion chart data
class ChartData {
  ChartData(this.original, this.x, this.y);
  final String original; // Original unabbreviated value
  final String x; // Display value (might be abbreviated)
  final double y;
}

// Enum for chart types
enum ChartType { bar, column, line }

String formatNumberShort(int number) {
  if (number >= 1e9) {
    return '${(number / 1e9).toStringAsFixed(1)}B';
  } else if (number >= 1e6) {
    return '${(number / 1e6).toStringAsFixed(1)}M';
  } else if (number >= 1e3) {
    return '${(number / 1e3).toStringAsFixed(1)}K';
  } else {
    return number.toString();
  }
}

class BarData {
  final String street;
  final int count;
  BarData(this.street, this.count);
}
