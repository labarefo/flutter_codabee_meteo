
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_codabee_meteo/my_flutter_app_icons.dart';
import 'package:flutter_codabee_meteo/temperature.dart';
import 'package:geocoder/geocoder.dart';
import 'package:location/location.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Coda Météo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  String key = "villes";
  List<String> villes = [];
  String villeChoisie;
  Coordinates coordsVilleChoisie;
  Temperature temperature;

  Location location;
  LocationData locationData;
  Stream<LocationData> stream;

  AssetImage night = new AssetImage("assets/n.jpg");
  AssetImage sun = new AssetImage("assets/d1.jpg");
  AssetImage rain = new AssetImage("assets/d2.jpg");

  String nameCurrent = "Ville actuelle";
  
  @override
  void initState() {
    super.initState();
    obtenir();
    location = new Location();
    listenToStream();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.title),
      ),
      drawer: new Drawer(
        child: new Container(
          color: Colors.blue,
          child: new ListView.builder(
            itemCount: villes.length + 2,
            itemBuilder: (context, i){
              if(i == 0){
                return new DrawerHeader(
                  child: new Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      texteAvecStyle("Mes villes", fontSize: 22.0),
                      new RaisedButton(
                          onPressed: ajoutVille,
                        color: Colors.white,
                        elevation: 8.0,
                        child: texteAvecStyle("Ajouter une ville", color: Colors.blue),
                      ),
                      
                    ],
                  ),
                );
              }else if(i == 1){
                return new ListTile(
                  title: texteAvecStyle(nameCurrent),
                  onTap: () {
                    setState(() {
                      villeChoisie = null;
                      coordsVilleChoisie = null;
                      apiMeteo();
                      Navigator.pop(context);
                    });
                  },
                );
              } else {
                String ville = villes[i - 2];
                return new ListTile(
                  onTap: () {
                    setState(() {
                      villeChoisie = ville;
                      coordsFromCity();
                      Navigator.pop(context);
                    });
                  },
                  title: texteAvecStyle(ville),
                  trailing: new IconButton(
                      icon: new Icon(Icons.delete, color: Colors.white,),
                      onPressed: () => supprimer(ville)),
                );
              }

            },
          ),
        ),
      ),
      body:
      temperature == null ?
      Center(
        child: new Text(villeChoisie ?? nameCurrent),
      )
      :
      new Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: new BoxDecoration(
          image: new DecorationImage(image: getBackground(), fit: BoxFit.cover)
        ),
        child: new Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            texteAvecStyle(villeChoisie ?? nameCurrent, fontSize: 40.0, fontStyle: FontStyle.italic),
            texteAvecStyle(temperature.description, fontSize: 30.0),
            new Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                new Image(image: getIcon(),),
                texteAvecStyle("${temperature.temp.toInt()} °C", fontSize: 75.0)
              ],
            ),
            new Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                extra("${temperature.min.toInt()} °C", MyFlutterApp.down),
                extra("${temperature.max.toInt()} °C", MyFlutterApp.up),
                extra("${temperature.pressure.toInt()}", MyFlutterApp.temperatire),
                extra("${temperature.humidity.toInt()}%", MyFlutterApp.drizzle),
              ],
            )
          ],
        ),
      ),
    );
  }

  Column extra(String data, IconData iconData) {
    return new Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Icon(iconData, color: Colors.white, size: 32.0,),
        texteAvecStyle(data)
      ],
    );
  }

  void obtenir() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    List<String> liste = await sharedPreferences.getStringList(key);
    if(liste != null){
      setState(() {
        villes = liste;
      });
    }
  }

  void supprimer(String ville) async {
    villes.remove(ville);
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setStringList(key, villes);
    obtenir();
  }

  void ajouter(String ville) async {
    if(villes.contains(ville)){
      return;
    }
    villes.add(ville);
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    await sharedPreferences.setStringList(key, villes);
    obtenir();
  }

  Future<Null> ajoutVille() async {
    return showDialog(context: context,
      barrierDismissible: true,
      builder: (BuildContext buildContext) {
        return new SimpleDialog(
          contentPadding: EdgeInsets.all(20.0),
          title: texteAvecStyle("Ajouter une ville", fontSize: 22.0, color: Colors.blue),
          children: [
            new TextField(
              decoration: new InputDecoration(labelText: "Ville :",),
              onSubmitted: (String str){
                ajouter(str);
                Navigator.pop(buildContext);
              },
            )
          ],
        );
      }
    );
  }
  // =================== Geocoder

  void apiMeteo() async {
    double lat;
    double lon;
    if(coordsVilleChoisie != null){
      lat = coordsVilleChoisie.latitude;
      lon = coordsVilleChoisie.longitude;
    }else if(locationData != null){
      lat = locationData.latitude;
      lon = locationData.longitude;
    }
    if(lat != null && lon != null){
      String baseApi = "https://api.openweathermap.org/data/2.5/weather?";
      String coordsString = "lat=$lat&lon=$lon";
      final key = "&APPID=2ff0b773e72006b7333687db4096976d";
      String lang = "&lang=${Localizations.localeOf(context).languageCode}";
      String units = "&units=metric";
      String query = baseApi + coordsString + key + lang + units;

      final response = await http.get(query);
      if(response.statusCode == 200){
        Map map = json.decode(response.body);
        setState(() {
          temperature = new Temperature(map);
          print(temperature.description);
        });
      }

    }
  }

  void locationTosString() async {
    if(locationData != null) {
      Coordinates coordinates = new Coordinates(locationData.latitude, locationData.longitude);
      final addresses = await Geocoder.local.findAddressesFromCoordinates(coordinates);

      if(addresses.length > 0){
        setState(() {
          nameCurrent = addresses.first.locality;
          print(nameCurrent);
          apiMeteo();
        });

      }
    }
  }

  void coordsFromCity() async {
    if(villeChoisie != null){
      List<Address> addresses = await Geocoder.local.findAddressesFromQuery(villeChoisie);
      if(addresses.length > 0){
        Address first = addresses.first;
        Coordinates coords = first.coordinates;
        setState(() {
          coordsVilleChoisie = coords;
          print(coordsVilleChoisie);
          apiMeteo();
        });

      }
    }

  }

  // =================== LOCATION ======================
  // une seule fois
  void listenToStream() {
    stream = location.onLocationChanged;
    stream.listen((newPosition) {
      if(locationData == null || locationData.latitude != newPosition.latitude || locationData.longitude != newPosition.longitude){
        print('position: lat=${newPosition.latitude} / lon=${newPosition.longitude}');
        setState(() {
          locationData = newPosition;
          locationTosString();
        });
      }

    });
  }

  // à chaque fois la poisition change
  void getFirstLocation() async {

    try{
      locationData = await location.getLocation();
      print('Nouvelle position: lat=${locationData.latitude} / lon=${locationData.longitude}');
      locationTosString();
    }catch(e){
      print('Nous avons une erreur: $e');
    }
  }

  Text texteAvecStyle(String data, {color: Colors.white, fontSize: 18.0, fontStyle: FontStyle.italic, textAlign: TextAlign.center}){
    return new Text(data,
      textAlign: textAlign,
      style: new TextStyle(color: color, fontStyle: fontStyle, fontSize: fontSize)
    );
  }

  AssetImage getIcon(){
    String icon = temperature.icon.replaceAll("n", "").replaceAll("d", "");
    return AssetImage("assets/$icon.png");
  }

  AssetImage getBackground() {
    if(temperature == null){
      return null;
    }
    if(temperature.icon.contains("n")){
      return night;
    }
    if(temperature.description.contains("01") || temperature.description.contains("02") || temperature.description.contains("03")){
      return sun;
    }
    return rain;
  }

}
