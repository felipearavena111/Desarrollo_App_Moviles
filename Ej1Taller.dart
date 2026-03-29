import 'package:flutter/material.dart';

class Ejercicio1 extends StatefulWidget {
  const Ejercicio1({super.key});

  @override
  State<Ejercicio1> createState() => _Ejercicio1State();
}

class _Ejercicio1State extends State<Ejercicio1> {
  int contador = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contador'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Contador: $contador',
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  iconSize: 40,
                  onPressed: () {
                    setState(() {
                      contador--;
                    });
                  },
                ),
                const SizedBox(width: 30),
                IconButton(
                  icon: const Icon(Icons.add),
                  iconSize: 40,
                  onPressed: () {
                    setState(() {
                      contador++;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}