import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {

  GlobalKey<FormState> formKey = new GlobalKey<FormState>();

  //variables
  static double zoomValue = 15.0;
  CameraPosition initialPosition = CameraPosition(target: LatLng(20.5937,78.9629),zoom: 5.0);
  Completer<GoogleMapController> _controller = Completer();
  Position currentLocation;
  bool showTopSheet = false;
  bool storeSelected = false;
  MapType mapType = MapType.normal;
  CollectionReference collectionReference = Firestore.instance.collection('rewari');
  Set<Marker> markers = Set();
  String enteredCity = null,tempCity;
  CollectionReference collectionReferenceCity;



  //initialize to get user current location
  @override
  void initState() {
    super.initState();
    print("Init state called");
    getUserCurrentLocation();
  }

  @override
  void dispose() {
    markers.clear();
    print("Dispose called");
    super.dispose();
  }

  //Scaffold starts here
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        title: Text("Food flame",style: TextStyle(color: Colors.white),),
        actions: <Widget>[

          IconButton(
           icon: Icon(Icons.search,color: Colors.white,),
           splashColor: Colors.white,
           onPressed: (){
            showDialog(
              barrierDismissible: false,
              context: (context),
              builder: (BuildContext context){
                  return Container(
                    child: AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)
                      ),
                      title: Text("Enter city name to search"),
                      content: citySearchForm(),
                      actions: [
                        Row(
                          children: [
                            RaisedButton(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              color:Colors.red[800],
                              child: Text("Cancel",style: TextStyle(color: Colors.white),),
                              onPressed: (){
                                Navigator.pop(context);
                              },
                            ),
                            SizedBox(width: 20.0,),
                            RaisedButton(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                              color:Colors.blue[800],
                              child: Text("Search",style: TextStyle(color: Colors.white),),
                              onPressed: (){
                                if(formKey.currentState.validate()){
                                  formKey.currentState.save();
                                  searchCity(enteredCity);
                                  Navigator.pop(context);
                                }else{
                                  print("Error in validatind");
                                }
                              },
                            )
                          ],
                        )
                      ],
                    ),
                  );
              }
            );
           },
          ),

          IconButton(
            icon: Icon(Icons.arrow_drop_down_circle,color: Colors.white,),
            onPressed: (){
              if(showTopSheet == true){
                setState(() {
                  showTopSheet = false;
                });
              }else{
                setState(() {
                  showTopSheet = true;
                });
              }
            },
          )
        ],
      ),


      //body starts here

      body:currentLocation == null?
          Center(child: CircularProgressIndicator(),):
      Stack(
        children: <Widget>[
          GoogleMap(
            mapType: mapType,
            initialCameraPosition: initialPosition,
            onMapCreated: (GoogleMapController controller){
              _controller.complete(controller);
            },
            myLocationEnabled: true,
            markers: markers
          ),


          //container located at top beside the app bar
          Positioned(
            top: showTopSheet?2:(-(MediaQuery.of(context).size.height)/2)+15,
            child: Container(
              margin: EdgeInsets.only(left: 10.0),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25.0),
                  color: Colors.white,
                ),
                height: ((MediaQuery.of(context).size.height)/2)-40,
                width: (MediaQuery.of(context).size.width)-20,
                child: collectionReferenceCity == null?Center(child: Text("No data to show!\nEnter City name correctly",
                  style: TextStyle(fontSize: 17.0),),)
                    :buildContainer(context),
              )
          ),


          //bottom icons

          Align(
            alignment: Alignment.bottomLeft,
            child: Container(
              margin: EdgeInsets.only(bottom: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    onPressed: (){
                      zoomValue--;
                      zoomInorOut(zoomValue);
                    },
                    child: Icon(Icons.zoom_out,color: Colors.white,),
                    backgroundColor: Colors.blue[800],
                  ),

                  SizedBox(width: 15.0,),

                  FloatingActionButton(
                    backgroundColor: Colors.green[700],
                    splashColor: Colors.white,
                    onPressed: (){

                      if(mapType == MapType.normal){
                        setState(() {
                          mapType = MapType.satellite;
                        });
                      }else{
                        setState(() {
                          mapType = MapType.normal;
                        });

                      }
                    },
                    child: Icon(Icons.satellite,color: Colors.white,),
                  ),

                  SizedBox(width: 15.0,),

                  FloatingActionButton(
                    onPressed: (){
                        zoomValue++;
                        zoomInorOut(zoomValue);
                    },
                    child: Icon(Icons.zoom_in,color: Colors.white,),
                    backgroundColor: Colors.blue[800],
                  ),
                ],
              ),
            )
          )


        ],
      ),
    );
  }


  //build the list of items

  Widget buildContainer(BuildContext context){

    return StreamBuilder<QuerySnapshot>(
      stream: collectionReferenceCity.snapshots(),
      builder: (context,snapshot){

        if(snapshot.connectionState == ConnectionState.none){
          return const Center(child: Text("Internet lost"));
        }else if(snapshot.connectionState == ConnectionState.waiting){
          return Center(child: CircularProgressIndicator(),);
        }else if(!snapshot.hasData) return const Center(child: Text("Loading..."),);

        return Align(
            alignment: Alignment.topLeft,
            child: Container(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6.0,top: 5.0),
                child: ListView.builder(
                  itemCount: snapshot.data.documents.length,
                  itemBuilder: (context,index){
                    return Padding(
                      padding: EdgeInsets.all(8.0),
                      child: GestureDetector(

                        //detect gesture here
                        onTap: (){
                          setState(() {
                            showTopSheet = false;
                          });
                          goToLocation(snapshot.data.documents[index].data['geopoint'].latitude, snapshot.data.documents[index].data['geopoint'].longitude);
                          Marker newLocationMarker = Marker(
                            markerId: MarkerId("${snapshot.data.documents[index].data['name']}"),
                            infoWindow: InfoWindow(title: "${snapshot.data.documents[index].data['name']}"),
                            onTap: (){

                            },
                            position:LatLng(snapshot.data.documents[index].data['geopoint'].latitude,snapshot.data.documents[index].data['geopoint'].longitude),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                          );
                          markers.add(newLocationMarker);
                        },
                        child: Container(
                          height: 80.0,
                          width: 200.0,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(width: 5.0,),
                                Container(
                                  height: 120,
                                  width: 120,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(25.0),
                                    child: Image.network("${snapshot.data.documents[index].data['imageLink']}",fit: BoxFit.cover,),
                                  ),
                                ),

                                SizedBox(width: 5.0,),

                                Column(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: <Widget>[
                                    Text("${snapshot.data.documents[index].data['name']}"),

                                    Row(
                                      children: <Widget>[
                                        Text("${snapshot.data.documents[index].data['ratings']} rate stars."),
                                        SizedBox(width: 5.0,),

                                        RatingBarIndicator(
                                          itemSize: 20.0,
                                          rating: double.parse("${snapshot.data.documents[index].data['ratings']}"),
                                          itemBuilder: (context,index){
                                            return Icon(Icons.star,color: Colors.amber,);
                                          },
                                        ),
                                      ],
                                    ),

                                    Text("Tap to visit",style: TextStyle(color: Colors.grey),),

                                  ],
                                ),

                              ],
                            ),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25.0),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
        );
      },
    );
  }


  //Retrieve current location
  Future getUserCurrentLocation() async {
    Position geoLocator = await Geolocator().getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    setState(() {
      currentLocation = geoLocator;
    });
    Marker currentLocationMarker = Marker(
      markerId: MarkerId("My location"),
      infoWindow: InfoWindow(title: "current location"),
      onTap: (){
        goToLocation(currentLocation.latitude, currentLocation.longitude);
      },
      position:currentLocation == null?LatLng(20.5937, 78.9629):LatLng(currentLocation.latitude, currentLocation.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    );
    markers.add(currentLocationMarker);
  }


  //animated camera to marker
  Future goToLocation(double lat,double lon) async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(lat, lon),zoom: 15,bearing: 40.0)));
    Marker(
      markerId: MarkerId("Here is it"),
      infoWindow: InfoWindow(title: "Here is it"),
      onTap: (){

      },
      position:LatLng(lat, lon),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
    );
  }


  //function to zoom in and zoom out
  Future zoomInorOut(double value) async {
    GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: LatLng(currentLocation.latitude, currentLocation.longitude),zoom: value)));
  }

  Future searchCity(String cityName) async {
  formKey.currentState.save();
  print("city name: $cityName");
  collectionReferenceCity = Firestore.instance.collection('$cityName');
  print("${collectionReferenceCity.reference().path}");
  }

  Widget citySearchForm() {
    return Form(
      key: formKey,
      child: TextFormField(
        decoration: InputDecoration(
          labelText: "City",
          hintText: "Enter city",
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(
              color: Colors.blue
            )
          )
        ),
        onChanged: (value){
          this.tempCity = value.toLowerCase();
        },
        onSaved: (value){
          this.enteredCity = value.toLowerCase();
        },
        validator: (value){
          if(value.length<=2){
            return "Please enter a valid name";
          }else{
            return null;
          }
        },
      ),
    );
}
}
