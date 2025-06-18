// pages/storelocation.dart
import 'package:flutter/material.dart';
import 'bottomnav.dart';
import 'AppBackButton.dart';
import 'HomePage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/cart_icon_button.dart';
import 'package:google_fonts/google_fonts.dart';

class StoreSelectionPage extends StatefulWidget {
  const StoreSelectionPage({super.key});

  @override
  _StoreSelectionPageState createState() => _StoreSelectionPageState();
}

class _StoreSelectionPageState extends State<StoreSelectionPage> {
  // List of all regions
  final List<String> regions = [
    'All Regions',
    'Greater Accra',
    'Ashanti',
    'Western',
    'Central',
    'Eastern',
    'Northern',
    'Upper East',
    'Upper West',
    'Volta',
    'Bono',
    'Bono East',
    'Ahafo',
    'Western North',
    'Oti',
    'Savannah',
    'North East'
  ];

  // List of all cities
  final List<City> cities = [
    City(name: 'All Cities', region: 'All Regions'),
    // Greater Accra
    City(name: 'Accra', region: 'Greater Accra'),
    City(name: 'Tema', region: 'Greater Accra'),
    City(name: 'Madina', region: 'Greater Accra'),
    City(name: 'East Legon', region: 'Greater Accra'),
    City(name: 'West Legon', region: 'Greater Accra'),
    City(name: 'Dansoman', region: 'Greater Accra'),
    City(name: 'Spintex', region: 'Greater Accra'),
    City(name: 'Adenta', region: 'Greater Accra'),
    City(name: 'Ashaiman', region: 'Greater Accra'),
    City(name: 'Kasoa', region: 'Greater Accra'),
    City(name: 'Weija', region: 'Greater Accra'),
    City(name: 'Dome', region: 'Greater Accra'),
    City(name: 'Achimota', region: 'Greater Accra'),
    City(name: 'Kokomlemle', region: 'Greater Accra'),
    City(name: 'Osu', region: 'Greater Accra'),
    City(name: 'Cantonments', region: 'Greater Accra'),
    City(name: 'Labone', region: 'Greater Accra'),
    City(name: 'Airport', region: 'Greater Accra'),
    City(name: 'Dzorwulu', region: 'Greater Accra'),
    City(name: 'Haatso', region: 'Greater Accra'),
    City(name: 'Taifa', region: 'Greater Accra'),
    City(name: 'Kaneshie', region: 'Greater Accra'),
    City(name: 'Mallam', region: 'Greater Accra'),
    City(name: 'Odorkor', region: 'Greater Accra'),
    City(name: 'Awoshie', region: 'Greater Accra'),
    City(name: 'Pokuase', region: 'Greater Accra'),
    City(name: 'Amasaman', region: 'Greater Accra'),
    City(name: 'Dodowa', region: 'Greater Accra'),
    City(name: 'Nungua', region: 'Greater Accra'),
    City(name: 'Teshie', region: 'Greater Accra'),
    City(name: 'La', region: 'Greater Accra'),
    City(name: 'Oyarifa', region: 'Greater Accra'),
    City(name: 'Adenta Frafraha', region: 'Greater Accra'),
    City(name: 'Sakumono', region: 'Greater Accra'),
    City(name: 'Lashibi', region: 'Greater Accra'),
    City(name: 'Community 1', region: 'Greater Accra'),
    City(name: 'Community 2', region: 'Greater Accra'),
    City(name: 'Community 3', region: 'Greater Accra'),
    City(name: 'Community 4', region: 'Greater Accra'),
    City(name: 'Community 5', region: 'Greater Accra'),
    City(name: 'Community 6', region: 'Greater Accra'),
    City(name: 'Community 7', region: 'Greater Accra'),
    City(name: 'Community 8', region: 'Greater Accra'),
    City(name: 'Community 9', region: 'Greater Accra'),
    City(name: 'Community 10', region: 'Greater Accra'),
    City(name: 'Community 11', region: 'Greater Accra'),
    City(name: 'Community 12', region: 'Greater Accra'),
    City(name: 'Community 13', region: 'Greater Accra'),
    City(name: 'Community 14', region: 'Greater Accra'),
    City(name: 'Community 15', region: 'Greater Accra'),
    City(name: 'Community 16', region: 'Greater Accra'),
    City(name: 'Community 17', region: 'Greater Accra'),
    City(name: 'Community 18', region: 'Greater Accra'),
    City(name: 'Community 19', region: 'Greater Accra'),
    City(name: 'Community 20', region: 'Greater Accra'),
    City(name: 'Community 21', region: 'Greater Accra'),
    City(name: 'Community 22', region: 'Greater Accra'),
    City(name: 'Community 23', region: 'Greater Accra'),
    City(name: 'Community 24', region: 'Greater Accra'),
    City(name: 'Community 25', region: 'Greater Accra'),

    // Ashanti
    City(name: 'Kumasi', region: 'Ashanti'),
    City(name: 'Obuasi', region: 'Ashanti'),
    City(name: 'Ejisu', region: 'Ashanti'),
    City(name: 'Mampong', region: 'Ashanti'),
    City(name: 'Konongo', region: 'Ashanti'),
    City(name: 'Bekwai', region: 'Ashanti'),
    City(name: 'Asante Mampong', region: 'Ashanti'),
    City(name: 'Asokore Mampong', region: 'Ashanti'),
    City(name: 'Asokwa', region: 'Ashanti'),
    City(name: 'Bantama', region: 'Ashanti'),
    City(name: 'Manhyia', region: 'Ashanti'),
    City(name: 'Suame', region: 'Ashanti'),
    City(name: 'Tafo', region: 'Ashanti'),
    City(name: 'Santasi', region: 'Ashanti'),
    City(name: 'Ayigya', region: 'Ashanti'),
    City(name: 'Deduako', region: 'Ashanti'),
    City(name: 'Kotei', region: 'Ashanti'),
    City(name: 'Ayeduase', region: 'Ashanti'),
    City(name: 'Patasi', region: 'Ashanti'),
    City(name: 'Ahodwo', region: 'Ashanti'),
    City(name: 'Nhyiaeso', region: 'Ashanti'),
    City(name: 'Kwadaso', region: 'Ashanti'),
    City(name: 'Bomso', region: 'Ashanti'),
    City(name: 'Danyame', region: 'Ashanti'),
    City(name: 'Feyiase', region: 'Ashanti'),
    City(name: 'Kaase', region: 'Ashanti'),
    City(name: 'Krofrom', region: 'Ashanti'),
    City(name: 'Abuakwa', region: 'Ashanti'),
    City(name: 'Adum', region: 'Ashanti'),
    City(name: 'Asafo', region: 'Ashanti'),
    City(name: 'Atonsu', region: 'Ashanti'),
    City(name: 'Buokrom', region: 'Ashanti'),
    City(name: 'Chirapatre', region: 'Ashanti'),
    City(name: 'Daban', region: 'Ashanti'),
    City(name: 'Ejisu', region: 'Ashanti'),
    City(name: 'Ejura', region: 'Ashanti'),
    City(name: 'Fomena', region: 'Ashanti'),
    City(name: 'Juaben', region: 'Ashanti'),
    City(name: 'Kumawu', region: 'Ashanti'),
    City(name: 'Mamponteng', region: 'Ashanti'),
    City(name: 'New Tafo', region: 'Ashanti'),
    City(name: 'Nsuta', region: 'Ashanti'),
    City(name: 'Offinso', region: 'Ashanti'),
    City(name: 'Suntreso', region: 'Ashanti'),
    City(name: 'Tech', region: 'Ashanti'),

    // Western
    City(name: 'Sekondi', region: 'Western'),
    City(name: 'Takoradi', region: 'Western'),
    City(name: 'Tarkwa', region: 'Western'),
    City(name: 'Axim', region: 'Western'),
    City(name: 'Elubo', region: 'Western'),
    City(name: 'Half Assini', region: 'Western'),
    City(name: 'Prestea', region: 'Western'),
    City(name: 'Bogoso', region: 'Western'),
    City(name: 'Dunkwa', region: 'Western'),
    City(name: 'Asankragwa', region: 'Western'),
    City(name: 'Enchi', region: 'Western'),
    City(name: 'Wassa Akropong', region: 'Western'),
    City(name: 'Wassa Amenfi', region: 'Western'),
    City(name: 'Wassa Dunkwa', region: 'Western'),
    City(name: 'Wassa Fiase', region: 'Western'),
    City(name: 'Wassa Japa', region: 'Western'),
    City(name: 'Wassa Mpohor', region: 'Western'),
    City(name: 'Wassa Nkonya', region: 'Western'),
    City(name: 'Wassa Nsuaem', region: 'Western'),
    City(name: 'Wassa Simpa', region: 'Western'),

    // Central
    City(name: 'Cape Coast', region: 'Central'),
    City(name: 'Winneba', region: 'Central'),
    City(name: 'Elmina', region: 'Central'),
    City(name: 'Saltpond', region: 'Central'),
    City(name: 'Dunkwa-on-Offin', region: 'Central'),
    City(name: 'Swedru', region: 'Central'),
    City(name: 'Kasoa', region: 'Central'),
    City(name: 'Mankessim', region: 'Central'),
    City(name: 'Apam', region: 'Central'),
    City(name: 'Gomoa Fetteh', region: 'Central'),
    City(name: 'Gomoa Manso', region: 'Central'),
    City(name: 'Gomoa Obuasi', region: 'Central'),
    City(name: 'Gomoa Potsin', region: 'Central'),
    City(name: 'Gomoa Tarkwa', region: 'Central'),
    City(name: 'Gomoa Winneba', region: 'Central'),
    City(name: 'Gomoa Yaw', region: 'Central'),
    City(name: 'Gomoa Zongo', region: 'Central'),
    City(name: 'Gomoa Zongo Junction', region: 'Central'),
    City(name: 'Gomoa Zongo Junction', region: 'Central'),
    City(name: 'Gomoa Zongo Junction', region: 'Central'),

    // Eastern
    City(name: 'Koforidua', region: 'Eastern'),
    City(name: 'Nkawkaw', region: 'Eastern'),
    City(name: 'Suhum', region: 'Eastern'),
    City(name: 'Nsawam', region: 'Eastern'),
    City(name: 'Aburi', region: 'Eastern'),
    City(name: 'Akropong', region: 'Eastern'),
    City(name: 'Mampong', region: 'Eastern'),
    City(name: 'Asamankese', region: 'Eastern'),
    City(name: 'Akim Oda', region: 'Eastern'),
    City(name: 'Akim Swedru', region: 'Eastern'),
    City(name: 'Akim Tafo', region: 'Eastern'),
    City(name: 'Akim Wenchi', region: 'Eastern'),
    City(name: 'Akim Zongo', region: 'Eastern'),
    City(name: 'Akim Zongo Junction', region: 'Eastern'),
    City(name: 'Akim Zongo Junction', region: 'Eastern'),
    City(name: 'Akim Zongo Junction', region: 'Eastern'),
    City(name: 'Akim Zongo Junction', region: 'Eastern'),
    City(name: 'Akim Zongo Junction', region: 'Eastern'),
    City(name: 'Akim Zongo Junction', region: 'Eastern'),

    // Northern
    City(name: 'Tamale', region: 'Northern'),
    City(name: 'Yendi', region: 'Northern'),
    City(name: 'Savelugu', region: 'Northern'),
    City(name: 'Bimbilla', region: 'Northern'),
    City(name: 'Gushegu', region: 'Northern'),
    City(name: 'Karaga', region: 'Northern'),
    City(name: 'Kpandai', region: 'Northern'),
    City(name: 'Kumbungu', region: 'Northern'),
    City(name: 'Mion', region: 'Northern'),
    City(name: 'Nanton', region: 'Northern'),
    City(name: 'Saboba', region: 'Northern'),
    City(name: 'Sagnarigu', region: 'Northern'),
    City(name: 'Savelugu', region: 'Northern'),
    City(name: 'Tolon', region: 'Northern'),
    City(name: 'Wulensi', region: 'Northern'),
    City(name: 'Zabzugu', region: 'Northern'),
    City(name: 'Zabzugu Junction', region: 'Northern'),
    City(name: 'Zabzugu Junction', region: 'Northern'),
    City(name: 'Zabzugu Junction', region: 'Northern'),
    City(name: 'Zabzugu Junction', region: 'Northern'),

    // Upper East
    City(name: 'Bolgatanga', region: 'Upper East'),
    City(name: 'Bawku', region: 'Upper East'),
    City(name: 'Navrongo', region: 'Upper East'),
    City(name: 'Paga', region: 'Upper East'),
    City(name: 'Bongo', region: 'Upper East'),
    City(name: 'Builsa', region: 'Upper East'),
    City(name: 'Garu', region: 'Upper East'),
    City(name: 'Tempane', region: 'Upper East'),
    City(name: 'Zebilla', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),
    City(name: 'Zebilla Junction', region: 'Upper East'),

    // Upper West
    City(name: 'Wa', region: 'Upper West'),
    City(name: 'Tumu', region: 'Upper West'),
    City(name: 'Jirapa', region: 'Upper West'),
    City(name: 'Lawra', region: 'Upper West'),
    City(name: 'Nandom', region: 'Upper West'),
    City(name: 'Daffiama', region: 'Upper West'),
    City(name: 'Hamile', region: 'Upper West'),
    City(name: 'Lambussie', region: 'Upper West'),
    City(name: 'Nadowli', region: 'Upper West'),
    City(name: 'Sissala East', region: 'Upper West'),
    City(name: 'Sissala West', region: 'Upper West'),
    City(name: 'Sissala West Junction', region: 'Upper West'),
    City(name: 'Sissala West Junction', region: 'Upper West'),
    City(name: 'Sissala West Junction', region: 'Upper West'),
    City(name: 'Sissala West Junction', region: 'Upper West'),
    City(name: 'Sissala West Junction', region: 'Upper West'),
    City(name: 'Sissala West Junction', region: 'Upper West'),
    City(name: 'Sissala West Junction', region: 'Upper West'),
    City(name: 'Sissala West Junction', region: 'Upper West'),
    City(name: 'Sissala West Junction', region: 'Upper West'),

    // Volta
    City(name: 'Ho', region: 'Volta'),
    City(name: 'Hohoe', region: 'Volta'),
    City(name: 'Keta', region: 'Volta'),
    City(name: 'Kpando', region: 'Volta'),
    City(name: 'Aflao', region: 'Volta'),
    City(name: 'Anloga', region: 'Volta'),
    City(name: 'Denu', region: 'Volta'),
    City(name: 'Keta', region: 'Volta'),
    City(name: 'Ketu North', region: 'Volta'),
    City(name: 'Ketu South', region: 'Volta'),
    City(name: 'Kpando', region: 'Volta'),
    City(name: 'Krachi East', region: 'Volta'),
    City(name: 'Krachi Nchumuru', region: 'Volta'),
    City(name: 'Krachi West', region: 'Volta'),
    City(name: 'Nkwanta North', region: 'Volta'),
    City(name: 'Nkwanta South', region: 'Volta'),
    City(name: 'North Dayi', region: 'Volta'),
    City(name: 'North Tongu', region: 'Volta'),
    City(name: 'South Dayi', region: 'Volta'),
    City(name: 'South Tongu', region: 'Volta'),

    // Bono
    City(name: 'Sunyani', region: 'Bono'),
    City(name: 'Berekum', region: 'Bono'),
    City(name: 'Dormaa Ahenkro', region: 'Bono'),
    City(name: 'Wenchi', region: 'Bono'),
    City(name: 'Atebubu', region: 'Bono'),
    City(name: 'Bechem', region: 'Bono'),
    City(name: 'Dormaa East', region: 'Bono'),
    City(name: 'Dormaa West', region: 'Bono'),
    City(name: 'Jaman North', region: 'Bono'),
    City(name: 'Jaman South', region: 'Bono'),
    City(name: 'Sunyani East', region: 'Bono'),
    City(name: 'Sunyani West', region: 'Bono'),
    City(name: 'Tain', region: 'Bono'),
    City(name: 'Tain Junction', region: 'Bono'),
    City(name: 'Tain Junction', region: 'Bono'),
    City(name: 'Tain Junction', region: 'Bono'),
    City(name: 'Tain Junction', region: 'Bono'),
    City(name: 'Tain Junction', region: 'Bono'),
    City(name: 'Tain Junction', region: 'Bono'),
    City(name: 'Tain Junction', region: 'Bono'),

    // Bono East
    City(name: 'Techiman', region: 'Bono East'),
    City(name: 'Kintampo', region: 'Bono East'),
    City(name: 'Nkoranza', region: 'Bono East'),
    City(name: 'Atebubu', region: 'Bono East'),
    City(name: 'Pru East', region: 'Bono East'),
    City(name: 'Pru West', region: 'Bono East'),
    City(name: 'Sene East', region: 'Bono East'),
    City(name: 'Sene West', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),
    City(name: 'Sene West Junction', region: 'Bono East'),

    // Ahafo
    City(name: 'Goaso', region: 'Ahafo'),
    City(name: 'Bechem', region: 'Ahafo'),
    City(name: 'Duayaw Nkwanta', region: 'Ahafo'),
    City(name: 'Hwidiem', region: 'Ahafo'),
    City(name: 'Kenyasi', region: 'Ahafo'),
    City(name: 'Kukuom', region: 'Ahafo'),
    City(name: 'Mim', region: 'Ahafo'),
    City(name: 'Nkaseim', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),
    City(name: 'Nkaseim Junction', region: 'Ahafo'),

    // Western North
    City(name: 'Sefwi Wiawso', region: 'Western North'),
    City(name: 'Bibiani', region: 'Western North'),
    City(name: 'Enchi', region: 'Western North'),
    City(name: 'Juaboso', region: 'Western North'),
    City(name: 'Aowin', region: 'Western North'),
    City(name: 'Bia East', region: 'Western North'),
    City(name: 'Bia West', region: 'Western North'),
    City(name: 'Bibiani-Anhwiaso-Bekwai', region: 'Western North'),
    City(name: 'Bodi', region: 'Western North'),
    City(name: 'Juaboso', region: 'Western North'),
    City(name: 'Sefwi Akontombra', region: 'Western North'),
    City(name: 'Sefwi Wiawso', region: 'Western North'),
    City(name: 'Sefwi Wiawso Junction', region: 'Western North'),
    City(name: 'Sefwi Wiawso Junction', region: 'Western North'),
    City(name: 'Sefwi Wiawso Junction', region: 'Western North'),
    City(name: 'Sefwi Wiawso Junction', region: 'Western North'),
    City(name: 'Sefwi Wiawso Junction', region: 'Western North'),
    City(name: 'Sefwi Wiawso Junction', region: 'Western North'),
    City(name: 'Sefwi Wiawso Junction', region: 'Western North'),
    City(name: 'Sefwi Wiawso Junction', region: 'Western North'),

    // Oti
    City(name: 'Dambai', region: 'Oti'),
    City(name: 'Jasikan', region: 'Oti'),
    City(name: 'Kadjebi', region: 'Oti'),
    City(name: 'Krachi East', region: 'Oti'),
    City(name: 'Krachi Nchumuru', region: 'Oti'),
    City(name: 'Krachi West', region: 'Oti'),
    City(name: 'Nkwanta North', region: 'Oti'),
    City(name: 'Nkwanta South', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),
    City(name: 'Nkwanta South Junction', region: 'Oti'),

    // Savannah
    City(name: 'Damongo', region: 'Savannah'),
    City(name: 'Bole', region: 'Savannah'),
    City(name: 'Sawla', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),
    City(name: 'Bole Junction', region: 'Savannah'),

    // North East
    City(name: 'Nalerigu', region: 'North East'),
    City(name: 'Gambaga', region: 'North East'),
    City(name: 'Walewale', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
    City(name: 'Walewale Junction', region: 'North East'),
  ];

  final List<Store> stores = [
    Store(
      name: 'Ernest Chemists - Accra Mall',
      city: 'Accra',
      region: 'Greater Accra',
      address: 'Accra Mall, Spintex Road',
      phone: '+233 20 123 4567',
      hours: 'Mon-Sat: 8:00 AM - 8:00 PM\nSun: 10:00 AM - 6:00 PM',
    ),
    Store(
      name: 'Ernest Chemists - West Hills Mall',
      city: 'Accra',
      region: 'Greater Accra',
      address: 'West Hills Mall, Weija',
      phone: '+233 20 234 5678',
      hours: 'Mon-Sat: 8:00 AM - 8:00 PM\nSun: 10:00 AM - 6:00 PM',
    ),
    Store(
      name: 'Ernest Chemists - Kumasi City Mall',
      city: 'Kumasi',
      region: 'Ashanti',
      address: 'Kumasi City Mall, Harper Road',
      phone: '+233 20 345 6789',
      hours: 'Mon-Sat: 8:00 AM - 8:00 PM\nSun: 10:00 AM - 6:00 PM',
    ),
    Store(
      name: 'Ernest Chemists - Tamale',
      city: 'Tamale',
      region: 'Northern',
      address: 'Central Business District',
      phone: '+233 20 456 7890',
      hours: 'Mon-Sat: 8:00 AM - 8:00 PM\nSun: 10:00 AM - 6:00 PM',
    ),
    Store(
      name: 'Ernest Chemists - Takoradi',
      city: 'Takoradi',
      region: 'Western',
      address: 'Market Circle',
      phone: '+233 20 567 8901',
      hours: 'Mon-Sat: 8:00 AM - 8:00 PM\nSun: 10:00 AM - 6:00 PM',
    ),
  ];

  String? selectedRegion;
  String? selectedCity;
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade700,
                Colors.green.shade800,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
        leading: AppBackButton(
          backgroundColor: Colors.white.withOpacity(0.2),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomePage()),
              );
            }
          },
        ),
        title: Text(
          'Store Locations',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CartIconButton(
              iconColor: Colors.white,
              iconSize: 24,
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 100, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Find a Store Near You',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select your region and city to find the nearest store',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search stores...',
                              prefixIcon: const Icon(Icons.search,
                                  color: Colors.black54, size: 20),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey[300]!),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    BorderSide(color: Colors.grey[400]!),
                              ),
                              filled: true,
                              fillColor: Colors.grey[50],
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                            ),
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedRegion,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.map,
                                        color: Colors.black54, size: 20),
                                    labelText: 'Region',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: Colors.grey[400]!),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                  ),
                                  hint: const Text('Select Region',
                                      overflow: TextOverflow.ellipsis),
                                  isExpanded: true,
                                  items: regions.map((String region) {
                                    return DropdownMenuItem<String>(
                                      value: region,
                                      child: Text(
                                        region,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedRegion = newValue;
                                      selectedCity = null;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedCity,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.location_city,
                                        color: Colors.black54, size: 20),
                                    labelText: 'City',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide:
                                          BorderSide(color: Colors.grey[400]!),
                                    ),
                                    filled: true,
                                    fillColor: Colors.grey[50],
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 12),
                                  ),
                                  hint: const Text('Select City',
                                      overflow: TextOverflow.ellipsis),
                                  isExpanded: true,
                                  items: cities
                                      .where((city) =>
                                          selectedRegion == null ||
                                          city.region == selectedRegion)
                                      .map((City city) {
                                    return DropdownMenuItem<String>(
                                      value: city.name,
                                      child: Text(
                                        city.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      selectedCity = newValue;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildStoreList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(),
    );
  }

  Widget _buildStoreList() {
    final filteredStores = _getFilteredStores();

    if (filteredStores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_mall_directory_outlined,
                size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No stores found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: filteredStores.length,
      itemBuilder: (context, index) {
        final store = filteredStores[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () => _launchMaps(store),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[100],
                        radius: 20,
                        child:
                            Icon(Icons.store, color: Colors.black54, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.location_on,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    store.address,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.access_time,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Hours',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              store.hours,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.phone,
                                    size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  'Phone',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              store.phone,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.directions,
                            color: Colors.black87, size: 18),
                        label: const Text(
                          'Get Directions',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () => _launchMaps(store),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.phone,
                            color: Colors.black87, size: 18),
                        label: const Text(
                          'Call Store',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () => _launchPhone(store.phone),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0);
      },
    );
  }

  List<Store> _getFilteredStores() {
    return stores.where((store) {
      // If "All Regions" is selected, show all stores
      if (selectedRegion == 'All Regions') {
        return true;
      }

      // If "All Cities" is selected, show all stores in the selected region
      if (selectedCity == 'All Cities') {
        return store.region == selectedRegion;
      }

      // If a specific region is selected, filter by region
      if (selectedRegion != null && store.region != selectedRegion) {
        return false;
      }

      // If a specific city is selected, filter by city
      if (selectedCity != null && store.city != selectedCity) {
        return false;
      }

      // If there's a search query, filter by store name or address
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return store.name.toLowerCase().contains(query) ||
            store.address.toLowerCase().contains(query);
      }

      return true;
    }).toList();
  }

  Future<void> _launchMaps(Store store) async {
    try {
      final query = Uri.encodeComponent('${store.name}, ${store.address}');
      final url = 'https://www.google.com/maps/search/?api=1&query=$query';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open the map')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    try {
      final url = 'tel:$phone';
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not make the call')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }
}

class City {
  final String name;
  final String region;

  const City({
    required this.name,
    required this.region,
  });
}

class Store {
  final String name;
  final String city;
  final String region;
  final String address;
  final String phone;
  final String hours;

  const Store({
    required this.name,
    required this.city,
    required this.region,
    required this.address,
    required this.phone,
    required this.hours,
  });
}
