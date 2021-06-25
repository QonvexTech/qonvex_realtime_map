import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if(!kIsWeb){
    await Firebase.initializeApp();
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Future<FirebaseApp> _firebaseInit = Firebase.initializeApp();
  // CollectionReference reference = FirebaseFirestore.instance.collection('obrero-location-collection');
  late final CollectionReference _collectionReference = _firestore.collection('obrero-location-collection');
  final Completer<GoogleMapController> _controller = Completer();
  void _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return ;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      print('Location permissions are permanently denied, we cannot request permissions.');
      return ;
    }

    Geolocator.getPositionStream().listen((pos) {
      print(pos.latitude);
      _collectionReference.where('id',isEqualTo: 3).get().then((QuerySnapshot<Object?> val) {
        if(val.docs.length > 0){
          /// Existing Record
          _collectionReference.doc(val.docs[0].id).update({'location' : "${pos.latitude}, ${pos.longitude}"});
        }else{
          _collectionReference.add({
            'id' : 3,
            'location' : "${pos.latitude}, ${pos.longitude}",
            // 'location' : new GeoPoint(pos.latitude, pos.longitude),
            'is_active' : true
          });
        }
      });
    });
  }
  @override
  void initState(){
    if(!kIsWeb){
      _determinePosition();
    }
    super.initState();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("APP"),
      ),
      body: FutureBuilder(
        future: _firebaseInit,
        builder: (_,snapshot) {
          if(snapshot.hasError){
            return Center(
              child: Text("ERROR ${snapshot.error}"),
            );
          }
          if(snapshot.connectionState == ConnectionState.done){
            if(kIsWeb){
              return StreamBuilder<QuerySnapshot>(
                stream: _collectionReference.snapshots(),
                builder: (_, firestoreSnap) {
                  if (firestoreSnap.hasError) {
                    return Center(
                      child: Text("SERVER ERROR : ${firestoreSnap.error}"),
                    );
                  }
                  if (firestoreSnap.hasData) {
                    List<RealtimeLocationData> data = firestoreSnap.data!.docs
                        .toList()
                        .map((DocumentSnapshot documentSnapshot) {
                      Map<String, dynamic> mappedData =
                      documentSnapshot.data() as Map<String, dynamic>;
                      return RealtimeLocationData.fromJson(mappedData);
                    }).toList();
                    Set<Marker> markers;
                    markers = data
                        .map((e) => new Marker(
                        markerId: MarkerId("${e.id + Random().nextInt(20)}"),
                        visible: e.isActive,
                        position: LatLng(
                            double.parse(e.location!.split(',')[0].toString()),
                            double.parse(
                                e.location!.split(',')[1].toString()))))
                        .toSet();

                    print(markers);
                    return GoogleMap(
                      onMapCreated: (controller) {
                        _controller.complete(controller);
                      },
                      myLocationButtonEnabled: true,
                      rotateGesturesEnabled: true,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(48.864716, 2.349014),
                        zoom: 15.0,
                      ),
                      buildingsEnabled: true,
                      mapType: MapType.none,
                      myLocationEnabled: true,
                      markers: markers,
                    );
                  }
                  return Center(
                    child: Text("Connecting..."),
                  );
                },
              );
            }else{
              /// MOBILE VIEW
              return Container(

              );
            }
          }
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      )
    );
  }
}
class RealtimeLocationData {
  final int id;
  final String? location;
  bool isActive;
  RealtimeLocationData({required this.id,required this.location, required this.isActive });
  factory RealtimeLocationData.fromJson(Map<String,dynamic> parsedJson){
    return RealtimeLocationData(
      id : int.parse(parsedJson['id'].toString()),
      location : parsedJson['location'] is String ? parsedJson['location'] : null,
      isActive : parsedJson['is_active'] == null ? false : parsedJson['is_active'],
    );
  }
  Map<String,dynamic> toJson()=>{
    'id' : id,
    'location' : location,
    'is_active' : isActive,
  };
}
