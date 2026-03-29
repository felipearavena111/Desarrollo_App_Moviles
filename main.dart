import 'package:flutter/material.dart';

import 'Ej1Taller.dart';
//import 'Ej2Taller.dart';
//import 'Ej3Taller.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Ejercicio1(), 
      //home: Ejercicio2(), 
      //home: Ejercicio3(), 
    );
  }
}