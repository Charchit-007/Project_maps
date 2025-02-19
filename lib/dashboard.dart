import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    // final startTime = DateTime.now();

    try {
      final response = await http
          .get(Uri.parse('http://127.0.0.1:5000/traffic-analysis'))
          .timeout(const Duration(seconds: 60));

      // final endTime = DateTime.now();
      // print('Request Time: ${endTime.difference(startTime).inMilliseconds} ms');

      if (response.statusCode == 200) {   // agar response succesfullhai, status 200 return hota hai
        setState(() {
          trafficData = json.decode(response.body);
          // jsonify encodes karke bhejta hai, and yaha we decode the response
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load traffic data');
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
      body: Column(
        children: [
          // App Bar with Navigation
          _buildAppBar(),
          
          // Main Content
          Expanded(
            child: isLoading      // if data nhi aya, isloading true hoga; once data or even error aya, 'finally' wale code se isLoading false ho jayega
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                    ),
                  )
                : _buildDashboardContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,     // higher - increases depth effect
            offset: Offset(0, 9),    // x, y axis with respect to the parent(container)
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 24,
                ),
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
          Row(
            children: [
              // replace with tab bar to navigate between Map and dashboard
              // _navButton("Overview", isSelected: true),
              // _navButton("Insights"),
              // _navButton("Reports"),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: const Color(0xFF2A3547), width: 1),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0xFF8B5CF6),
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
                SizedBox(width: 8),
                Text(
                  "Admin",
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(width: 8),
                Icon(Icons.keyboard_arrow_down, color: Colors.white60, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _navButton(String title, {bool isSelected = false}) {
  //   return Container(
  //     margin: const EdgeInsets.symmetric(horizontal: 8),
  //     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  //     decoration: BoxDecoration(
  //       color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
  //       borderRadius: BorderRadius.circular(8),
  //     ),
  //     child: Text(
  //       title,
  //       style: TextStyle(
  //         color: isSelected ? Colors.white : Colors.white70,
  //         fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
  //       ),
  //     ),
  //   );
  // }

  Widget _buildDashboardContent() {
    if (trafficData == null) {
      return const Center(
        child: Text(
          "No data available",
          style: TextStyle(color: Colors.white60),
        ),
      );
    }
    // if data not empty ->
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main Content Area (70%)
        Expanded(
          // diff between expanded and flexible is
          // flexible lets child take how much ever space they need
          // expanded forces child to take all avail width
          flex: 5,    // how much space it should take, with resp to its siblings
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBoroughSummary(),
                const SizedBox(height: 24),
                _buildSection(
                  title: "Borough-wise Traffic Analysis",
                  child: _buildBarChartCard(trafficData!['Borough-wise Congestion']),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: "Peak Traffic Hours",
                  child: _buildBarChartCard(trafficData!['Hourly Traffic Volume']),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: "Traffic by 3-Hour Intervals",
                  child: _buildBoroughIntervalCharts(),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: "Most Common Causes of Accidents",
                  child: _buildAnalysisCard(trafficData!['Most Common Causes of Accidents']),
                ),
                const SizedBox(height: 24),
                _buildSection(
                  title: "Accidents by Vehicle Type",
                  child: _buildAnalysisCard(trafficData!['Accidents by Vehicle Type']),
                ),
              ],
            ),
          ),
        ),
        
        // Right Sidebar (30%)
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.only(top: 24, right: 24, bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Danger Zones",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          "Live",
                          style: TextStyle(
                            color: Color(0xFF8B5CF6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Dangerous Streets",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/streetAnalysis');
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
                const SizedBox(height: 16),
                _buildDangerousStreetsSection(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoroughSummary() {
    // Extract borough data
    final boroughData = trafficData!['boro_wise_congestion'] as Map<String, dynamic>;    // !(null assertion operator) says that the traffic data is surely NOT NULL, which avoids compile error
    // ! use only when youa re sure data is not null
    
    if (boroughData.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Get top 3 boroughs
    final sortedBoroughs = boroughData.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));
      // .entries converts into iterable entry with key and values --> .list converts to list
      // as sort is avail only for list
      // sort works in place
    final topBoroughs = sortedBoroughs.take(3).toList();
    
    return Row(
      children: topBoroughs.asMap().entries.map((entry) {
        // this runs a loop for each item in the top boroughs list
        final index = entry.key;
        final borough = entry.value.key;
        final volume = entry.value.value;
        
        IconData icon;
        Color color;
        String label;
        
        if (index == 0) {       // top congested
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
        
        return _buildMetricCard(
          title: borough,
          value: volume.toString(),
          subtext: label,
          icon: icon,
          color: color,
        );
      }).toList(),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    String? change,
    bool isPositive = false,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
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
              value,
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
                    color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    change,
                    style: TextStyle(
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
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

  Widget _buildBarChartCard(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return _buildEmptyCard("No chart data available");
    }

    List<BarChartGroupData> barGroups = [];
    List<String> titles = [];

    // Find the maximum value for scaling
    double maxValue = 0;
    data.forEach((key, value) {
      if ((value as num).toDouble() > maxValue) {
        maxValue = (value as num).toDouble();
      }
    });

    int index = 0;
    data.forEach((key, value) {
      titles.add(key);
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: (value as num).toDouble(),
              color: const Color(0xFF8B5CF6),
              width: 16,
              borderRadius: BorderRadius.circular(2),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxValue * 1.1, // Add 10% padding at the top
                color: const Color(0xFF2D3748),
              ),
            )
          ],
        ),
      );
      index++;
    });

    return Container(
      height: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Current Analysis",
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF111826),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Text(
                      "Today",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups: barGroups,
                maxY: maxValue * 1.1, // Add 10% padding at the top
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFF2D3748),
                    strokeWidth: 1,
                    dashArray: [5, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value >= titles.length || value < 0) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            titles[value.toInt()],
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toInt()}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoroughIntervalCharts() {
    final intervalGraphsData = trafficData!['Traffic by 3-Hour Intervals Graphs'] as Map<String, dynamic>;
    
    if (intervalGraphsData.isEmpty) {
      return _buildEmptyCard("No interval data available");
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: intervalGraphsData.entries.map((entry) {
          final borough = entry.key;
          final base64Image = entry.value;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF8B5CF6),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      borough,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(base64Image),
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const Divider(color: Color(0xFF2D3748), height: 32),
            ],
          );
        }).toList(),
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

  Widget _buildAnalysisItem(String name, String value, double percentage, int index) {
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
                    overflow: TextOverflow.ellipsis,
                  ),
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

  Widget _buildDangerousStreetsSection() {
    final dangerousStreetsData = trafficData!['Top 5 Dangerous Streets Graphs'] as Map<String, dynamic>;
    
    if (dangerousStreetsData.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Expanded(
      child: Column(
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
          Expanded(
            child: DefaultTabController(
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
                    tabs: dangerousStreetsData.keys.map((borough) => 
                      Tab(text: borough)
                    ).toList(),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: dangerousStreetsData.entries.map((entry) {
                        final borough = entry.key;
                        final base64Image = entry.value;
                        
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(base64Image),
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
