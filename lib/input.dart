import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class TrafficAnalysisApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: StreetInputScreen(),
    );
  }
}

class StreetInputScreen extends StatefulWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Traffic Analysis")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: "Enter Street Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                if (_controller.text.isNotEmpty) {
                  fetchAnalysis(_controller.text);
                }
              },
              child: Text("Get Analysis"),
            ),
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

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Column(children: [
      Text(
        "${data['street_name']}",
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
      ), //data['most_congested_hour']['street'][0] didnt work for some reason, idk why
      Flexible(
          child: SingleChildScrollView(
        child: Center(child:Column(
          children: [
            SizedBox(
              height: 8,
            ),
            Wrap(children: [
              Row(children:[
                _Stats(
                title: "Most Congested Hour",
                value: data['most_congested_hour']['idxmax'],
                volume: data['most_congested_hour']['max'],
              ),
              SizedBox(width: 50,),
              _Stats(
                  title: "Least Congested Hour",
                  value: data['least_congested_hour']['idxmin'],
                  volume: data['least_congested_hour']['min']),
              ]),
              SizedBox(
                height: 400,
                width: 600,
                child: Image.memory(base64Decode(data["hour_plot"])),
              ),
              SizedBox(width: 50,),
              SizedBox(
                height: 400,
                width: 600,
                child: Image.memory(base64Decode(data["accidents"])),
              ),
              SizedBox(width: 50,),
              SizedBox(
                height: 400,
                width: 600,
                child: Image.memory(base64Decode(data["vehicle_types"])),
              ),
            ]),
            // Text(
            //     "Most Congested Hour: ${data['most_congested_hour']['idxmax']} (Volume: ${data['most_congested_hour']['max']})",
            //     style: const TextStyle(
            //       fontSize: 20,
            //     )), // fetching max and all from a dictionary
            // Text(
            //     "Least Congested Hour: ${data['least_congested_hour']['idxmin']} (Volume: ${data['least_congested_hour']['min']})",
            //     style: const TextStyle(
            //       fontSize: 20,
            //     )),
            SizedBox(height: 10),
            // Text("Traffic Volume per Hour:"),
            // for (var entry in data['hourly_volume'])
            //   Text("Hour ${entry['HH']}: ${entry['Vol']}"),
            // SizedBox(height: 10),
            // Text("Yearly Trend (Mean & Std Dev):"),
            // for (var entry in data['yearly_trend'])
            //   Text("Year ${entry['Yr']}: Mean=${entry['mean']}, Std=${entry['std']}"),
          ],
        ),)
      ))
    ]));
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
