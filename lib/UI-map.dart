import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';
import 'package:percent_indicator/percent_indicator.dart';

import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;

// Key for controlling scaffold (e.g. open drawer)
GlobalKey<ScaffoldState> mapScaffoldKey = GlobalKey();

class MapScreen extends StatefulWidget {
  @override
  MapScreenState createState() => new MapScreenState();
}

class MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  // Define timer object and speed for later use
  Timer changeImageTimer;
  Duration speed = Duration(milliseconds: 800);

  // Animation controls and current overlay counter
  int _count = 0;
  bool _playing = false;
  Icon _playPauseIcon = Icon(Icons.play_arrow);

  // flutter_map and user_location variables
  MapController mapController = MapController();
  List<Marker> markerList = [Marker(point: loc.lastKnownLocation, builder: ux.locMarker)];

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
    await loc.updateLastKnownLocation();
    await update.radarOutages();
    if (await update.remoteImagery(context, false, true)) {
      await update.legends();
      setState( () {
        if (_playing) {
          _togglePlaying();
        }
        _count = 0;
        imageCache.clear();
        imageCache.clearLiveImages();
      });
      update.forecasts();
    }
  }
  _locatePressed() async {
    if (await loc.checkLocPerm() == false || await loc.checkLocService() == false) {
      ux.showSnackBarIf(true, ux.locationOffSnack, context, 'map.MapScreenState._locatePressed: Could not update location');
    } else {
      await loc.updateLastKnownLocation(withRequests: true); 
      setState(() {markerList = [Marker(point: loc.lastKnownLocation, builder: ux.locMarker)]; mapController.move(loc.lastKnownLocation, 9);});
    }
  }
  Widget _returnSpacer() {
    return Text('      ');
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
              swPanBoundary: imagery.sw,
              nePanBoundary: imagery.ne,
            ),
            layers: [
              TileLayerOptions(
                tileProvider: AssetTileProvider(),
                urlTemplate: ux.darkMode(context) 
                  ? "assets/jawg-matrix/{z}/{x}/{y}.png" 
                  : "assets/jawg-sunny/{z}/{x}/{y}.png",
                minNativeZoom: 5,
                maxNativeZoom: 9,
                backgroundColor: ux.darkMode(context) 
                  ? Color(0xFF000000) 
                  : Color(0xFFCCE7FC),
                overrideTilesWhenUrlChanges: true, 
                tileFadeInDuration: 0, 
                tileFadeInStartWhenOverride: 1.0,
                retinaMode: ux.retinaMode(context), // Set retinamode based on device DPI
              ),
              OverlayImageLayerOptions(
                overlayImages: <OverlayImage>[
                  OverlayImage(
                    bounds: LatLngBounds(
                      imagery.sw, imagery.ne
                    ),
                    opacity: 0.6,
                    imageProvider: io.localFile('forecast.$_count.png').existsSync() 
                      ? MemoryImage(io.localFile('forecast.$_count.png').readAsBytesSync()) 
                      : AssetImage('assets/launcher/logo.png'),
                    gaplessPlayback: true,
                  )
                ]
              ),
              MarkerLayerOptions(
                markers: markerList,
              ),
            ], // End of layers
          ),
          Container (
            alignment: Alignment.bottomLeft,
            child: Container(
              margin: EdgeInsets.all(12), 
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).canvasColor,
                boxShadow: [
                  BoxShadow(color: Colors.black54.withOpacity(0.4), blurRadius: 7.0, offset: const Offset(1, 2.5),)
                ],
              ),
              child: CircularPercentIndicator(
                animationDuration: speed.inMilliseconds,
                restartAnimation: false,
                animation: true,
                animateFromLastPercent: true,
                radius: 56.0,
                lineWidth: 4.0,
                circularStrokeCap: CircularStrokeCap.round,
                percent: _count/8,
                center: imagery.legends.length == 9 
                  ? Text(imagery.legends[_count].substring(imagery.legends[_count].length - 12, imagery.legends[_count].length - 7), style: ux.latoWhite.merge(TextStyle(color: Theme.of(context).textTheme.bodyText1.color))) 
                  : Text("...", style: ux.latoWhite),
                progressColor: Theme.of(context).accentColor,
                backgroundColor: Theme.of(context).backgroundColor,
              )
            ),
          )
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
      // TODO Rest of drawer: speed and opacity settings, possibly other layers e.g. barbs and composite, make proper legend with hex colors in support-imagery
      drawer: Drawer(
        child: ListView(
          children: <Widget>[
            Align(
              alignment: Alignment(0,0), 
              child: Container(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    // Legend
                    Align(alignment: Alignment.center, child: Text("Legend")),
                    Container(child: Row(children: [Text("Rain"), Spacer(), Text('Hail')]), margin: EdgeInsets.all(8),), 
                    Row(children: [ 
                      for (int _i=0; _i<1; _i++) 
                        _returnSpacer(),
                      for (Color _color in imagery.colorsHex.sublist(0,12))
                        Container(color: _color, child: _returnSpacer())
                    ]),
                    Container(child: Align(alignment: Alignment.centerLeft, child: Text("Transition")), margin: EdgeInsets.all(8),),
                    Row(children: [ 
                      for (int _i=0; _i<1; _i++) 
                        _returnSpacer(),
                      for (Color _color in imagery.colorsHex.sublist(12,17))
                        Container(color: _color, child: _returnSpacer())
                    ]),
                    Container(child: Row(children: [Text("Snow"), _returnSpacer(), _returnSpacer(), _returnSpacer(), Text('Wet Snow')]), margin: EdgeInsets.all(8),),
                    Row(children: [ 
                      for (Color _color in imagery.colorsHex.sublist(18))
                        Container(color: _color, child: _returnSpacer())
                    ]),
                    // Speed control
                    Align(alignment: Alignment.center, child: Text("Animation Speed")),
                    Slider.adaptive(
                      value: 700-speed.inMilliseconds.toDouble(),
                      min: -700,
                      max: 700,
                      divisions: 14,
                      onChanged: (newSpeed) {
                        setState(() {
                          speed = Duration(milliseconds: newSpeed.round()+700);
                          if (_playing) {
                            _togglePlaying();
                          }
                        });
                      },
                    )
                  ]
                )
              ),
            ),
          ],
        )
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.my_location),
        onPressed: () {_locatePressed();},
      ),
    );
  }
}