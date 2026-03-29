import 'package:flutter/material.dart';
import 'dart:math';

class Ejercicio3 extends StatefulWidget {
  const Ejercicio3({super.key});

  @override
  State<Ejercicio3> createState() => _Ejercicio3State();
}

class _Ejercicio3State extends State<Ejercicio3> {
  int numero = 0;
  bool generado = false;

  void generarNumero() {
    setState(() {
      numero = Random().nextInt(100) + 1;
      generado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Numero aleatorio'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              generado ? 'Numero: $numero' : 'Presiona el boton',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: generarNumero,
              child: const Text('Generar numero'),
            ),
          ],
        ),
      ),
    );
  }
}