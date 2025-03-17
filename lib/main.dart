//latest

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'input.dart';
import 'dashboard.dart';
import 'dart:async';

void main() {
  runApp(MaterialApp(
    home: const DashboardPage(),
    theme: ThemeData.dark().copyWith(primaryColor: Color(0xFF1E293B), scaffoldBackgroundColor: const Color(0xFF1E293B)),
    debugShowCheckedModeBanner: false,
  ));
  // runApp(const OpenStreetMapRouteApp());
}

class OpenStreetMapRouteApp extends StatelessWidget {
  const OpenStreetMapRouteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const MapsPage(),
    );
  }
}

class AccidentData {
  final LatLng position;
  final int count;
  final int injuries;
  final int deaths;
  final List<Map<String, dynamic>> topFactors;

  AccidentData({
    required this.position,
    required this.count,
    required this.injuries,
    required this.deaths,
    required this.topFactors,
  });

  factory AccidentData.fromJson(Map<String, dynamic> json) {
    return AccidentData(
      position: LatLng(json['lat'], json['lng']),
      count: json['count'],
      injuries: json['injuries'],
      deaths: json['deaths'],
      topFactors: List<Map<String, dynamic>>.from(json['topFactors']),
    );
  }
}

class MapsPage extends StatefulWidget {
  const MapsPage({Key? key}) : super(key: key);

  @override
  State<MapsPage> createState() => _MapsPageState();
}

// final TextEditingController _searchController = TextEditingController();

class _MapsPageState extends State<MapsPage> {
  Timer? _debounceTimer; 
  LatLng? _origin;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  bool _isLoading = false;
  bool _showTraffic = false;
  bool _showTrafficAll = false;
  bool _showHeatmap = false;

  Map<String, dynamic> _routeInfo = {};
  bool _showSidebar = false;
  
  Map<String, dynamic>? _selectedOriginLocation;
  Map<String, dynamic>? _selectedDestinationLocation;
  String _originStreetName = '';
  String _destinationStreetName = '';

  List<dynamic> _originSuggestions = [];
  List<dynamic> _destinationSuggestions = [];
  final TextEditingController _originController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();

  
  List<AccidentData> _accidentData = [];
  List<Marker> _accidentMarkers = [];

  Map<LatLng, Color> _streetTraffic ={}; // store traffic colors

  double? _futureTrafficChange; // Store traffic change

  // Initial center set to Manhattan, New York
  final LatLng _manhattanCenter = const LatLng(40.7831, -73.9712);
  final MapController _mapController = MapController();

  bool _showRouteSearch = false;

  bool _isMobileView(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  Widget _buildMobileLocationPanel() {
  if ((_selectedOriginLocation == null && _selectedDestinationLocation == null) || !_showSidebar) {
    return const SizedBox.shrink();
  }

  return DraggableScrollableSheet(
    initialChildSize: 0.3,
    minChildSize: 0.03,
    maxChildSize: 0.6,
    builder: (context, scrollController) {
      return Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 0, 0, 0),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
               // Route info if available
              if (_routeInfo.isNotEmpty)
                _buildMobileRouteInfo(),
              // Origin details if available
              if (_selectedOriginLocation != null)
                _buildMobileLocationDetails('Origin', _selectedOriginLocation!, _originStreetName),
              
              // Destination details if available and in route search mode
              if (_showRouteSearch && _selectedDestinationLocation != null)
                _buildMobileLocationDetails('Destination', _selectedDestinationLocation!, _destinationStreetName),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildMobileLocationDetails(String title, Map<String, dynamic> location, String streetName) {
  final address = location['address'] as Map<String, dynamic>;
  
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrafficAnalysisApp(location: location),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 142, 255, 141),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              child: const Icon(Icons.analytics_outlined),
            ),
          ],
        ),
        const Divider(color: Colors.grey),
        _buildMobileDetailItem('Name', location['display_name'].toString().split(',').first),
        if (streetName.isNotEmpty)
          _buildMobileDetailItem('Street', streetName),
        if (address['city'] != null)
          _buildMobileDetailItem('City', address['city']),
        if (address['state'] != null)
          _buildMobileDetailItem('State', address['state']),
        _buildMobileDetailItem('Coordinates', '${location['lat']}, ${location['lon']}'),
      ],
    ),
  );
}

Widget _buildMobileDetailItem(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}

Widget _buildMobileRouteInfo() {
  final distance = (_routeInfo['distance'] / 1000).toStringAsFixed(2);
  final duration = (_routeInfo['duration'] / 60).toStringAsFixed(0);

  return Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.black26,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_car),
            Text('$distance km'),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.access_time),
            Text('$duration mins'),
          ],
        ),
      ],
    ),
  );
}

Widget _buildPredictionBox() {
  if (_futureTrafficChange == null) return const SizedBox.shrink();

  return Positioned(
    top: _isMobileView(context) ? 80 : 80, // Adjust position for mobile
    right: 16,
    child: Card(
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.timeline,
              size: 20,
              color: Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              "Traffic in 30 min: ${_futureTrafficChange!.toStringAsFixed(2)}%",
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: const Icon(Icons.close, size: 16),
              onPressed: () {
                setState(() {
                  _futureTrafficChange = null;
                });
              },
            )
          ],
        ),
      ),
    ),
  );
}

  @override
  void initState() {
    super.initState();
    _loadAccidentData();
    _fetchAllTrafficPredictions();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _searchLocation(String query, bool isOrigin) async {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel(); // Cancel the previous timer if still running
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) return;

      try {
        final response = await http.get(Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=5'));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);

          setState(() {
            if (isOrigin) {
              _originSuggestions = data;
            } else {
              _destinationSuggestions = data;
            }
          });
        }
      } catch (e) {
        print("Error fetching location suggestions: $e");
      }
    });
  }

  Future<void> _fetchRouteTraffic() async {
    if (_routePoints.isEmpty) {
      print("No route points found!");
      return;
    }

    try {
      final List<Map<String, double>> routePointsData =
          _routePoints.map((point) {
        return {"latitude": point.latitude, "longitude": point.longitude};
      }).toList();

      final response = await http.post(
        Uri.parse("http://localhost:5000/predict_route"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"route_points": routePointsData}),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print("Received route traffic data: ${data.length} points");

        setState(() {
          _streetTraffic.clear();
          for (var i = 0; i < data.length - 1; i++) {
            Color color;
            switch (data[i]["traffic_color"]) {
              case "red":
                color = Colors.red.withOpacity(0.7);
                break;
              case "yellow":
                color = Colors.yellow.withOpacity(0.7);
                break;
              default:
                color = Colors.green.withOpacity(0.7);
                break;
            }

            print("RoutePoint: ${data[i]}        color: ${color}");

            // Store each segment instead of just individual points
            _streetTraffic[_routePoints[i]] = color;
          }
          _showTraffic = true;
        });
      } else {
        print("Error fetching route traffic: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching route traffic: $e");
    }
  }

  // Future<void> _fetchRouteTraffic() async {
  //   if (_routePoints.isEmpty) {
  //     print("No route points found!");
  //     return;
  //   }

  //   try {
  //     final List<Map<String, double>> routePointsData =
  //         _routePoints.map((point) {
  //       return {"latitude": point.latitude, "longitude": point.longitude};
  //     }).toList();

  //     final response = await http.post(
  //       Uri.parse("http://localhost:5000/predict_route"),
  //       headers: {"Content-Type": "application/json"},
  //       body: jsonEncode({"route_points": routePointsData}),
  //     );

  //     if (response.statusCode == 200) {
  //       final List<dynamic> data = json.decode(response.body);
  //       print("Received route traffic data: ${data.length} points");

  //       setState(() {
  //         _streetTraffic.clear();
  //         for (var i = 0; i < data.length; i++) {
  //           Color color;

  //           switch (data[i]["traffic_color"]) {
  //             case "red":
  //               color = Colors.red.withValues(alpha: 0.7);
  //               break;
  //             case "yellow":
  //               color = Colors.yellow.withValues(alpha: 0.7);
  //               break;
  //             default:
  //               color = Colors.green.withValues(alpha: 0.7);
  //               break;
  //           }

  //           // Store each segment of the route instead of just single points
  //           if (i < _routePoints.length - 1) {
  //             _streetTraffic[_routePoints[i]] = color;
  //           }
  //         }
  //         _showTraffic = true;
  //       });
  //     }
  //   } catch (e) {
  //     print("Error fetching route traffic: $e");
  //   }
  // }

  Future<void> _fetchFutureTrafficChange() async {
    if (_routePoints.isEmpty) return;

    final List<Map<String, double>> routePointsData = _routePoints.map((point) {
      return {"latitude": point.latitude, "longitude": point.longitude};
    }).toList();

    final response = await http.post(
      Uri.parse("http://localhost:5000/predict_future"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"route_points": routePointsData}),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);

      double avgChange = data.fold<double>(0,
              (sum, item) => sum + (item["change_percent"] as num).toDouble()) /
          data.length;

      setState(() {
        _futureTrafficChange = avgChange;
      });
    } else {
      print("Error fetching future traffic change");
    }
  }

  // Future<void> _fetchAllTrafficPredictions() async {
  //   final response =
  //       await http.get(Uri.parse("http://localhost:5000/predict_all"));

  //   if (response.statusCode == 200) {
  //     final List<dynamic> data = json.decode(response.body);
  //     print("Received data: ${data.length} streets");

  //     setState(() {
  //       _streetTraffic.clear();
  //       for (var item in data) {
  //         LatLng streetLocation = LatLng(item["latitude"], item["longitude"]);
  //         Color trafficColor;

  //         switch (item["traffic_color"]) {
  //           case "red":
  //             trafficColor = Colors.red;
  //             break;
  //           case "yellow":
  //             trafficColor = Colors.yellow;
  //             break;
  //           default:
  //             trafficColor = Colors.green;
  //             break;
  //         }

  //         _streetTraffic[streetLocation] = trafficColor;
  //       }
  //       _showTraffic = true;
  //     });
  //   } else {
  //     print("Error fetching traffic predictions");
  //   }
  // }

  Future<void> _fetchAllTrafficPredictions() async {
    try {
      setState(() {
        _isLoading = false; // Show loading indicator
      });

      final response =
          await http.get(Uri.parse("http://localhost:5000/predict_all"));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print("Received traffic data: ${data.length} streets");

        Map<LatLng, Color> newTrafficData = {};
        for (var item in data) {
          final lat = item["latitude"].toDouble();
          final lng = item["longitude"].toDouble();
          final location = LatLng(lat, lng);

          Color trafficColor;
          switch (item["traffic_color"]) {
            case "red":
              trafficColor = Colors.red;
              break;
            case "yellow":
              trafficColor = Colors.yellow;
              break;
            default:
              trafficColor = Colors.green;
              break;
          }

          newTrafficData[location] = trafficColor;
        }

        setState(() {
          _streetTraffic = newTrafficData;
          print("Updated traffic data: ${_streetTraffic.length} points");
        });
      } else {
        print("Error fetching traffic predictions: ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load traffic data")),
        );
      }
    } catch (e) {
      print("Error in _fetchAllTrafficPredictions: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  Future<void> _loadAccidentData() async {
    try {
      // Load your JSON file
      final String jsonString = await DefaultAssetBundle.of(context)
          .loadString('assets/nyc_accident_hotspots.json');

      final Map<String, dynamic> data = json.decode(jsonString);
      final List<dynamic> heatmapData = data['heatmapData'];

      setState(() {
        _accidentData =
            heatmapData.map((item) => AccidentData.fromJson(item)).toList();
      });
    } catch (e) {
      print('Error loading accident data: $e');
    }
  }

  List<WeightedLatLng> _getHeatmapPoints() {
    return _accidentData.map((data) {
      // Create a weighted point based on accident count
      return WeightedLatLng(
        data.position,
        data.count.toDouble(),
      );
    }).toList();
  }

  void _generateAccidentMarkers() {
    if (_routePoints.isEmpty) return;

    _accidentMarkers.clear();

    // Define threshold for high-risk areas (e.g., areas with more than 500 accidents)
    const int highRiskThreshold = 500;

    for (var accidentPoint in _accidentData) {
      // Only show markers for high-risk areas
      if (accidentPoint.count < highRiskThreshold) continue;

      // Check if this accident point is close to our route
      bool isNearRoute = _isPointNearRoute(accidentPoint.position);
      if (!isNearRoute) continue;

      // Add warning marker for this high-risk area
      _accidentMarkers.add(
        Marker(
          point: accidentPoint.position,
          child: GestureDetector(
            onTap: () => _showAccidentDetails(accidentPoint),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 30,
            ),
          ),
        ),
      );
    }
  }

  void _showAccidentDetails(AccidentData data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Accident-Prone Area'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Accidents: ${data.count}'),
            Text('Injuries: ${data.injuries}'),
            Text('Deaths: ${data.deaths}'),
            const SizedBox(height: 8),
            const Text('Top Factors:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...data.topFactors.map((factor) =>
                Text('• ${factor['factor']}: ${factor['count']} incidents')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  bool _isPointNearRoute(LatLng point) {
    // check if point is within 200m of any route point
    const double maxDistanceInKm = 0.2; // 200 meters

    for (var routePoint in _routePoints) {
      final distance = const Distance().as(
        LengthUnit.Kilometer,
        point,
        routePoint,
      );

      if (distance < maxDistanceInKm) {
        return true;
      }
    }

    return false;
  }

  void _showLocationDetails(Map<String, dynamic> location, bool isOrigin) {
    if (isOrigin) {
      setState(() {
        _selectedOriginLocation = location;
        _showSidebar = true;

        final address = location['address'] as Map<String, dynamic>;
        if (address['road'] != null) {
          _originStreetName = address['road'];
        } else {
          _originStreetName = 'Street name not available';
        }
      });
    } else {
      setState(() {
        _selectedDestinationLocation = location;
        _showSidebar = true;

        final address = location['address'] as Map<String, dynamic>;
        if (address['road'] != null) {
          _destinationStreetName = address['road'];
        } else {
          _destinationStreetName = 'Street name not available';
        }
      });
    }
  }

  // void _showOriginLocationDetails(Map<String, dynamic> location) {
  //   setState(() {
  //     _selectedOriginLocation = location;
  //     _showSidebar = true;

  //     final address = location['address'] as Map<String, dynamic>;
  //     if (address['road'] != null) {
  //       _originStreetName = address['road'];
  //     } else {
  //       _originStreetName = 'Street name not available';
  //     }
  //   });
  // }
  // void _showDestinationLocationDetails(Map<String, dynamic> location) {
  //   setState(() {
  //     _selectedDestinationLocation = location;
  //     _showSidebar = true;

  //     final address = location['address'] as Map<String, dynamic>;
  //     if (address['road'] != null) {
  //       _destinationStreetName = address['road'];
  //     } else {
  //       _destinationStreetName = 'Street name not available';
  //     }
  //   });
  // }

  // void _showLocationDetails(Map<String, dynamic> location) {
  //   setState(() {
  //     _selectedLocation = location;
  //     _showSidebar = true;

  //     final address = _selectedLocation!['address'] as Map<String, dynamic>;
  //     if (address['road'] != null) {
  //     } else {
  //     }
  //   });
  // }



  Widget _buildLocationPanel(String title, Map<String, dynamic>? location,
      String streetName, BuildContext context) {
    if (location == null) return const SizedBox.shrink();

    final address = location['address'] as Map<String, dynamic>;

    return Container(
      height: 170,
      width: 250, // Half the width of the original sidebar
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        TrafficAnalysisApp(location: location),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 142, 255, 141),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomRight: Radius.circular(20),
                  ), // Rounded corners
                ),
              ),
              child: Icon(Icons.analytics_outlined),
            ),
          ]),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                _buildDetailItem('Name', location['display_name']),
                if (streetName.isNotEmpty)
                  _buildDetailItem('Street', streetName),
                if (address['city'] != null)
                  _buildDetailItem('City', address['city']),
                if (address['state'] != null)
                  _buildDetailItem('State', address['state']),
                if (address['postcode'] != null)
                  _buildDetailItem('Postal Code', address['postcode']),
                _buildDetailItem(
                    'Coordinates', '${location['lat']}, ${location['lon']}'),
              ],
            ),
          ),
        ],
      ),
    );
  }

bool _isSidebarCollapsed = false;

// Replace _buildSidebar function to add toggle button
Widget _buildSidebar() {
  final bool hasAnyLocation =
      _selectedOriginLocation != null || _selectedDestinationLocation != null;

  if (!_showSidebar || !hasAnyLocation) return const SizedBox.shrink();

  // If sidebar is collapsed, show only the toggle button
  if (_isSidebarCollapsed) {
    return Positioned(
      left: 0,
      top: 80,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF1E293B),
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _isSidebarCollapsed = false;
            });
          },
        ),
      ),
    );
  }

  return ConstrainedBox(
    constraints: BoxConstraints(minHeight: 400),
    child: Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: Card(
        margin: const EdgeInsets.all(8),
        child: IntrinsicHeight(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Location Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        // Add collapse button
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => setState(() => _isSidebarCollapsed = true),
                          tooltip: "Collapse sidebar",
                        ),
                        // IconButton(
                        //   icon: const Icon(Icons.close),
                        //   onPressed: () => setState(() => _showSidebar = false),
                        //   tooltip: "Close sidebar",
                        // ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _buildLocationPanel('Origin', _selectedOriginLocation,
                          _originStreetName, context),
                      const Divider(),
                      SizedBox(
                          child: _showRouteSearch
                              ? _buildLocationPanel(
                                  'Destination',
                                  _selectedDestinationLocation,
                                  _destinationStreetName,
                                  context)
                              : null),
                      const Divider(),
                      SizedBox(
                          child: _showRouteSearch ? _buildRouteInfo() : null),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMapOptionsMenu() {
    return Positioned(
      right: 16,
      top: 16,
      child: Card(
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.layers),
          onSelected: (String value) async {
            if (value == 'traffic') {
              setState(() {
                _showTrafficAll = !_showTrafficAll;
              });
              if (!_showTrafficAll) {
                await _fetchAllTrafficPredictions();
              }
            } else if (value == 'heatmap') {
              setState(() {
                _showHeatmap = !_showHeatmap;
              });
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            CheckedPopupMenuItem<String>(
              value: 'traffic',
              checked: _showTrafficAll,
              child: const Text('Show Traffic'),
            ),
            CheckedPopupMenuItem<String>(
              value: 'heatmap',
              checked: _showHeatmap,
              child: const Text('Show Accident Heatmap'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadRoute() async {
    if (_origin == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter both origin and destination')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String coordinates =
          '${_origin!.longitude},${_origin!.latitude};${_destination!.longitude},${_destination!.latitude}';

      final response = await http.get(Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson&annotations=true'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0];
        final List<dynamic> coordinates = route['geometry']['coordinates'];

        setState(() {
          _routePoints = coordinates
              .map((coord) => LatLng(coord[1].toDouble(), coord[0].toDouble()))
              .toList();

          _routeInfo = {
            'distance': route['distance'],
            'duration': route['duration'],
          };

          _generateAccidentMarkers();
          _fetchRouteTraffic();
        });
      } else {
        throw Exception('Failed to load route: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading route: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getMapUrl() {
    // if (_showTraffic) {
    //   return 'https://tile.thunderforest.com/atlas/{z}/{x}/{y}.png?apikey=4fe4cdb808254e38adb6efd7ed6f807e';
    // }
    return 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  }

  Widget _buildRouteInfo() {
    if (_routeInfo.isEmpty) return const SizedBox.shrink();

    final distance = (_routeInfo['distance'] / 1000).toStringAsFixed(2);
    final duration = (_routeInfo['duration'] / 60).toStringAsFixed(0);

    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_car),
                  Text('$distance km'),
                ],
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time),
                  Text('$duration mins'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
      return Card(
        
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50)
        ),
        child: Column(children: [
          Container(
            height: 40,
            child: TextField(
              style: TextStyle(fontSize: 15),
            controller: _originController,
            onChanged: (value) => _searchLocation(value, true),
            decoration: InputDecoration(
              hintText: "Explore",
              fillColor: Colors.black,
              filled: true,
              contentPadding: EdgeInsets.symmetric(vertical: 4),
              prefixIcon: const Icon(Icons.location_on,size: 18,),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(50)),
            ),
          ),
          ),
          if (_originSuggestions.isNotEmpty) _buildSuggestions(true),
        ]));
  }
  

  Widget _buildSuggestions(bool isOrigin) {
    final suggestions = isOrigin ? _originSuggestions : _destinationSuggestions;
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = suggestions[index];
            final displayName = suggestion['display_name'];
            final lat = double.parse(suggestion['lat']);
            final lon = double.parse(suggestion['lon']);

            return ListTile(
              title: Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                setState(() {
                  if (isOrigin) {
                    _origin = LatLng(lat, lon);
                    _originController.text = displayName;
                    _originSuggestions.clear();
                    _mapController.move(
                        LatLng(lat, lon), _mapController.camera.zoom);

                    // _showOriginLocationDetails(suggestion);
                  } else {
                    _destination = LatLng(lat, lon);
                    _destinationController.text = displayName;
                    _destinationSuggestions.clear();
                    // _showDestinationLocationDetails(suggestion);
                  }
                });
                _showLocationDetails(suggestion, isOrigin);
              },
            );
          },
        ),
      ),
    );
  }
  
   Widget _buildToggleableSearch() {
    if (_showRouteSearch) {
      // Show route search (origin and destination)
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Container(
                        height: 40,
                        child: TextField(
                        style: TextStyle(fontSize: 15),
                        controller: _originController,
                        onChanged: (value) => _searchLocation(value, true),
                        
                        decoration: InputDecoration(
                          
                          hintText: "Enter Origin",
                          prefixIcon: const Icon(Icons.location_on,size: 18,),
                          fillColor: Colors.black,
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                          
                          
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(50)),
                        ),
                      ),
                      ),
                      if (_originSuggestions.isNotEmpty)
                        _buildSuggestions(true),
                    ],
                  ),
                ),
              ),
              // Button to toggle back to normal search
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showRouteSearch = false;
                  });
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Container(
                  height: 40,
                  child: TextField(
                  style: TextStyle(fontSize: 15),
                  controller: _destinationController,
                  onChanged: (value) => _searchLocation(value, false),
                  
                  decoration: InputDecoration(
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    fillColor: Colors.black,
                    hintText: "Enter Destination",
                    prefixIcon: const Icon(Icons.location_pin,size: 18,),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(50)),
                  ),
                ),
                ),
                if (_destinationSuggestions.isNotEmpty)
                  _buildSuggestions(false),
              ],
            ),
          ),
        ],
      );
    } else {
      // Show normal search bar with directions button
      return Row(
        children: [
          Expanded(
            child: _buildSearchBar(),
          ),
          IconButton(
            icon: const Icon(Icons.directions),
            onPressed: () {
              setState(() {
                _showRouteSearch = true;
              });
            },
          ),
        ],
      );
    }
  }

 
  
  
  @override
  Widget build(BuildContext context) {
  final bool isMobile = _isMobileView(context);
  
  return Scaffold(
    //appBar: isMobile ? null : CustomAppBar(),
    body: Stack(
      children: [
        Column(
          children: [
            Padding(padding: EdgeInsets.symmetric(vertical: 5),child: _buildToggleableSearch(),),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _manhattanCenter,
                      initialZoom: 12.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: _getMapUrl(),
                        subdomains: const ['a', 'b', 'c'],
                      ),
                      if (_showHeatmap && _accidentData.isNotEmpty)
                        HeatMapLayer(
                          heatMapDataSource: InMemoryHeatMapDataSource(
                            data: _getHeatmapPoints(),
                          ),
                          heatMapOptions: HeatMapOptions(radius: 20, gradient: {
                            0.2: Colors.blue, // Low intensity
                            0.5: Colors.yellow, // Medium intensity
                            0.7: Colors.orange, // High intensity
                            0.9: Colors.red, // Very high intensity
                          }),
                        ),
                      if (_showTraffic)
                        PolylineLayer(
                          polylines: _streetTraffic.entries
                              .map((entry) {
                                int index = _routePoints.indexOf(entry.key);
                                if (index < _routePoints.length - 1) {
                                  return Polyline(
                                    points: [
                                      _routePoints[index],
                                      _routePoints[index + 1]
                                    ],
                                    strokeWidth: 5.0,
                                    color: entry.value,
                                  );
                                }
                                return null;
                              })
                              .whereType<Polyline>()
                              .toList(),
                        ),
                      if (_showTrafficAll && _streetTraffic.isNotEmpty)
                        PolylineLayer(
                          polylines: _streetTraffic.entries.map((entry) {
                            return Polyline(
                              points: [entry.key],
                              strokeWidth: 8.0,
                              color: entry.value.withOpacity(0.7),
                            );
                          }).toList(),
                        ),
                      if(!_showTraffic)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            strokeWidth: 5.0,
                            color: Colors.blue,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          if (_origin != null)
                            Marker(
                              point: _origin!,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          if (_destination != null)
                            Marker(
                              point: _destination!,
                              child: const Icon(
                                Icons.location_pin,
                                color: Colors.green,
                                size: 40,
                              ),
                            ),
                          ..._accidentMarkers,
                        ],
                      ),
                    ],
                  ),
                  _buildMapOptionsMenu(),
                  // Conditionally show sidebar based on device type
                  if (!isMobile) _buildSidebar(),
                  _buildPredictionBox(),
                  if (_isLoading)
                    const Center(
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ],
        ),
        // Add mobile location panel at bottom of screen
        if (isMobile) _buildMobileLocationPanel(),
      ],
    ),
    floatingActionButton: _showRouteSearch
        ? FloatingActionButton(
            onPressed: () async {
              try {
                await _loadRoute();
                if (_routePoints.isNotEmpty) {
                  await Future.wait([
                    _fetchRouteTraffic(),
                    _fetchFutureTrafficChange(),
                  ]);
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Icon(Icons.directions),
          )
        : null,
  );
}
}