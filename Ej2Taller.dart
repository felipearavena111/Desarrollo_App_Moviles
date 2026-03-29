import 'package:flutter/material.dart';
import 'dart:math';

class Ejercicio2 extends StatefulWidget {
  const Ejercicio2({super.key});

  @override
  State<Ejercicio2> createState() => _Ejercicio2State();
}

class _Ejercicio2State extends State<Ejercicio2> {
  Color colorFondo = Colors.white;

  void cambiarColor() {
    setState(() {
      colorFondo = Colors.primaries[Random().nextInt(Colors.primaries.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Color aleatorio'),
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: colorFondo,
        child: Center(
          child: ElevatedButton(
            onPressed: cambiarColor,
            child: const Text('Cambiar color'),
          ),
        ),
      ),
    );
  }
}