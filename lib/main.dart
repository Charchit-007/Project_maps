import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const OpenStreetMapRouteApp());
}

class OpenStreetMapRouteApp extends StatelessWidget {
  const OpenStreetMapRouteApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapsPage(),
    );
  }
}

class MapsPage extends StatefulWidget {
  const MapsPage({Key? key}) : super(key: key);

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  LatLng? _origin;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  bool _isLoading = false;
  List<dynamic> _originSuggestions = [];
  List<dynamic> _destinationSuggestions = [];
  TextEditingController _originController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();

  Future<void> _searchLocation(String query, bool isOrigin) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching suggestions: $e')),
      );
    }
  }

  Future<void> _loadRoute() async {
    if (_origin == null || _destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both origin and destination')),
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

  Widget _buildSuggestions(bool isOrigin) {
    final suggestions = isOrigin ? _originSuggestions : _destinationSuggestions;

    return ListView.builder(
      shrinkWrap: true,
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final suggestion = suggestions[index];
        final displayName = suggestion['display_name'];
        final lat = double.parse(suggestion['lat']);
        final lon = double.parse(suggestion['lon']);

        return ListTile(
          title: Text(displayName),
          onTap: () {
            setState(() {
              if (isOrigin) {
                _origin = LatLng(lat, lon);
                _originController.text = displayName;
                _originSuggestions.clear();
              } else {
                _destination = LatLng(lat, lon);
                _destinationController.text = displayName;
                _destinationSuggestions.clear();
              }
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Route Map"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _originController,
                  onChanged: (value) => _searchLocation(value, true),
                  decoration: InputDecoration(
                    hintText: "Enter Origin",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                _buildSuggestions(true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                TextField(
                  controller: _destinationController,
                  onChanged: (value) => _searchLocation(value, false),
                  decoration: InputDecoration(
                    hintText: "Enter Destination",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                _buildSuggestions(false),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    center: _origin ?? LatLng(28.7041, 77.1025),
                    zoom: 11.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4.0,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        if (_origin != null)
                          Marker(
                            point: _origin!,
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        if (_destination != null)
                          Marker(
                            point: _destination!,
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.location_pin,
                              color: Colors.green,
                              size: 40,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                if (_isLoading)
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadRoute,
        child: const Icon(Icons.search),
      ),
    );
  }
}