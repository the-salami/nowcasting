import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:user_location/user_location.dart';
import 'package:latlong/latlong.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-update.dart' as update;

// Key for controlling scaffold (e.g. open drawer)
GlobalKey<ScaffoldState> mapScaffoldKey = GlobalKey();

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => new MapScreenState();
}

class MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  // Define timer object and speed for later use
  Timer changeImageTimer;
  Duration speed = Duration(milliseconds: 500);

  // Animation controls and current overlay counter
  int _count = 0;
  bool _playing = false;
  Icon _playPauseIcon = Icon(Icons.play_arrow);

  // flutter_map and user_location variables
  MapController mapController = MapController();
  List<Marker> markers = [];

  // Dark mode listening
  @override
  void didChangePlatformBrightness() {
    // Trigger rebuild
    setState(() {});
  }

  // State management helper functions
  _nextPressed() {
    setState(() {
      if (_count < 8)
        _count++;
      else
        _count = 0;
    });
  }
  _previousPressed() {
    setState(() {
      if (_count == 0)
        _count = 8;
      else
        _count--;
    });
  }
  _togglePlaying() {
    setState(() {
      if (_playing) {
        _playing = false;
        _playPauseIcon = Icon(Icons.play_arrow);
        changeImageTimer.cancel();
      } else {
        _playing = true;
        _playPauseIcon = Icon(Icons.pause);
        changeImageTimer = Timer.periodic(speed, (timer) { _nextPressed();});
      }
    });
  }
  _refreshPressed() async {
    if (await update.remoteImagery(context, false, true)) {
      setState( () {
        if (_playing) {
          _togglePlaying();
        }
        _count = 0;
        imageCache.clear();
        imageCache.clearLiveImages();
        update.legends();
      });
    }
  }

  // Widget definition
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: mapScaffoldKey,
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              center: LatLng(45.5088, -73.5878),
              zoom: 6.0,
              maxZoom: ux.retinaMode(context) ? 8.4 : 9, // Dynamically determined because retina mode doesn't work with overzooming+limited native z, requires lower threshold
              minZoom: 5,
              swPanBoundary: LatLng(35.0491, -88.7654),
              nePanBoundary: LatLng(51.0000, -66.7500),
              plugins: [
                UserLocationPlugin(),
              ],
            ),
            layers: [
              TileLayerOptions(
                tileProvider: AssetTileProvider(),
                urlTemplate: ux.darkMode(context) ? "assets/jawg-matrix/{z}/{x}/{y}.png" : "assets/jawg-sunny/{z}/{x}/{y}.png",
                minNativeZoom: 5,
                maxNativeZoom: 9,
                backgroundColor: ux.darkMode(context) ? Color(0xFF000000) : Color(0xFFCCE7FC),
                overrideTilesWhenUrlChanges: true, 
                tileFadeInDuration: 0, 
                tileFadeInStartWhenOverride: 1.0,
                retinaMode: ux.retinaMode(context), // Set retinamode based on device DPI
              ),
              OverlayImageLayerOptions(overlayImages: <OverlayImage>[
                OverlayImage(
                  bounds: LatLngBounds(
                    LatLng(35.0491, -88.7654), LatLng(51.0000, -66.7500)
                  ),
                  opacity: 0.6,
                  imageProvider: io.localFile('forecast.$_count.png').existsSync() ? MemoryImage(io.localFile('forecast.$_count.png').readAsBytesSync()) : AssetImage('assets/logo.png'),
                  gaplessPlayback: true,
                )
              ]),
              MarkerLayerOptions(
                markers: markers
              ),
              UserLocationOptions(
                context: context,
                mapController: mapController,
                markers: markers,
                updateMapLocationOnPositionChange: false,
                showMoveToCurrentLocationFloatingActionButton: true,
                zoomToCurrentLocationOnLoad: true,
                moveToCurrentLocationFloatingActionButton: Container(
                  decoration: BoxDecoration(
                  color: Theme.of(context).floatingActionButtonTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(color: Colors.black54.withOpacity(0.4), blurRadius: 7.0, offset: const Offset(1, 2.5),)
                    ]),
                  child: Icon(
                    Icons.my_location,
                    color: Theme.of(context).floatingActionButtonTheme.foregroundColor,
                  ),
                )
              )
            ], // End of layers
          ),
          SafeArea(child: Image.file(io.localFile('forecast_legend.$_count.png'), gaplessPlayback: true)),
        ]
      ),
      bottomNavigationBar: BottomAppBar(
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.menu),
                onPressed: () {mapScaffoldKey.currentState.openDrawer();}
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.navigate_before),
                onPressed: _previousPressed,
              ),
              IconButton(
                icon: _playPauseIcon,
                onPressed: _togglePlaying,
              ),
              IconButton(
                icon: Icon(Icons.navigate_next),
                onPressed: _nextPressed,
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {_refreshPressed();},
              ),
            ],
          )
      ),
      // TODO Drawer
      drawer: Drawer(
          child: ListView(
            children: <Widget>[
              Align(
                alignment: Alignment(0,0), 
                child: Column(
                  children: [
                    Icon(Icons.warning), 
                    Text("Under Construction")
                  ]
                )
              ),
            ],
          )
      ),
    );
  }
}