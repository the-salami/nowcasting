import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:latlong/latlong.dart';

//import 'package:Nowcasting/main.dart'; // Would be needed for sharedpref
import 'package:Nowcasting/support-update.dart' as update;
import 'package:Nowcasting/support-imagery.dart' as imagery;
import 'package:Nowcasting/support-location.dart' as loc;
import 'package:Nowcasting/support-ux.dart' as ux;
import 'package:Nowcasting/support-io.dart' as io;
import 'package:Nowcasting/UI-forecastSliver.dart';

// Widgets
class ForecastScreen extends StatefulWidget  {
  @override
  ForecastScreenState createState() => new ForecastScreenState();
}

class ForecastScreenState extends State<ForecastScreen> {
  bool _editing = false;
  
  _addLocationPressed() async {
    setState(() {
      if (loc.currentLocation.coordinates == null || imagery.coordOutOfBounds(loc.currentLocation.coordinates)) {
        loc.savedPlaces.add(loc.SavedLocation(
          name: "New Location", 
          coordinates: LatLng(0,0), 
          notify: false
        ));
        io.savePlaceData();
      } else {
        loc.savedPlaces.add(loc.SavedLocation(
          name: "Copy of Current Location", 
          coordinates: new LatLng(loc.currentLocation.coordinates.latitude, loc.currentLocation.coordinates.longitude), 
          notify: false
        ));
        io.savePlaceData();
      }
    });
  }

  _editPressed() async {
    _editing
    ? setState(() {
      _editing = false;
      io.savePlaceData();
    })
    : setState(() {
      _editing = true;
    });
  }
  
  _rebuild() {
    setState(() {
      // If we are rebuilding after deleting the last item
      // in the list, swap out of editing mode
      if (loc.savedPlaces.isEmpty) {
        _editing = false;
        io.savePlaceData();
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    // This build should be checked more for null safety, probably
    // when the feature becomes available. It depends on a lot of different
    // variables that do have defaults, but are manipulated by loading/restore
    // methods on the splash screen that could leave them with nulls.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forecast'),
        actions: <Widget>[
          loc.savedPlaces.isNotEmpty
            ? IconButton(
              icon: _editing
                ? Icon(Icons.done)
                : Icon(Icons.edit),
              onPressed: () {_editPressed();},
            )
            : Container(), 
        ],
      ),
      body: RefreshIndicator(
        color: ux.darkMode(context)
          ? Colors.white
          : ux.nowcastingColor,
        onRefresh: () async {
            await update.completeUpdate(false, false, context: this.context);
            _rebuild();
          },
          child: CustomScrollView(
            scrollDirection: Axis.vertical,
            slivers: <Widget>[
              // Radar outage sliver
              loc.radarOutage
                ? SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    itemExtent: ux.sliverThinHeight,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => new ux.WarningSliver(ux.radarOutageText, ux.WarningLevel.notice, url: ux.radarOutageUrl),
                      childCount: loc.radarOutage ? 1 : 0,
                    ),
                  ),
                ) 
                : SliverToBoxAdapter( 
                  child: Container(),
                ),
              // Weather alert sliver
              loc.weatherAlert
                ? SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    itemExtent: ux.sliverThinHeight,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => new ux.WarningSliver(ux.alertText, ux.WarningLevel.alert, url: ux.alertUrl),
                      childCount: 1, //TODO loc.alerts.length? store in array for multiple location alerts?
                    ),
                  ),
                )
                : SliverToBoxAdapter( 
                  child: Container(),
                ),
              // Current location sliver
              loc.currentLocation.coordinates != null
                // If current location is available
                ? SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    delegate: imagery.coordOutOfBounds(loc.currentLocation.coordinates) == false 
                      // geoToPixel returns false if location is outside bbox. 
                      // If geoToPixel doesn't return false, build the forecast sliver:
                      ? SliverChildBuilderDelegate(
                        (context, index) => new ForecastSliver(loc.currentLocation, _editing, () {_rebuild();}),
                        childCount: 1,
                      )
                      // Otherwise, display a notice that tells the user they are out of coverage.
                      : SliverChildBuilderDelegate(
                        (context, index) => new ux.WarningSliver("McGill's Nowcasting service does not provide data for your current location.", ux.WarningLevel.notice),
                        childCount: 1,
                      ),
                    itemExtent: imagery.coordOutOfBounds(loc.currentLocation.coordinates) == false 
                      ? _editing
                        ? ux.sliverHeightExpanded
                        : ux.sliverHeight
                      : ux.sliverThinHeight,
                  ),
                )
                // If current location is unavailable
                : SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    itemExtent: ux.sliverThinHeight,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => new ux.WarningSliver("Could not detect current location.", ux.WarningLevel.notice),
                      childCount: 1,
                    ),
                  ),
                ),
              // Slivers for stored locations
              (loc.savedPlaces.isNotEmpty)
                ? SliverPadding(
                  padding: const EdgeInsets.symmetric(vertical: 0.0),
                  sliver: SliverFixedExtentList(
                    itemExtent: _editing
                      ? ux.sliverHeightExpanded
                      : ux.sliverHeight,
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => new ForecastSliver(loc.savedPlaces[index], _editing, () {_rebuild();}),
                      childCount: loc.savedPlaces.length,
                    ),
                  ),
                )
                : loc.savedPlaces.isEmpty 
                  ? SliverToBoxAdapter( 
                    child: Container(),
                  )
                  : SliverPadding(
                    padding: const EdgeInsets.symmetric(vertical: 0.0),
                    sliver: SliverFixedExtentList(
                      itemExtent: ux.sliverThinHeight,
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => new ux.WarningSliver("There was an error loading your stored locations.", ux.WarningLevel.alert),
                        childCount: 1,
                      ),
                    ),
                  ),
              // Add location sliver
              SliverToBoxAdapter( 
                child: GestureDetector(
                  onTap: () {_addLocationPressed();},
                  child: Container(
                    margin: ux.sliverBottomMargins,
                    child: Icon(Icons.add, color: Colors.white),
                    height: ux.sliverTinyHeight,
                    decoration: new BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.rectangle,
                      borderRadius: new BorderRadius.circular(8.0),
                      boxShadow: [ux.sliverShadow],
                    ),
                  ),
                )
              )
            ],
          ),
        )
    );
  }
}
