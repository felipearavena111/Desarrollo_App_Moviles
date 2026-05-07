import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MiAplicacion());
}

class MiAplicacion extends StatelessWidget {
  const MiAplicacion({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UA Asistencia Alumno',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE53935)), // Rojo UA
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeNavegacion();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

// =========================================================================
// 1. PANTALLA DE AUTENTICACIÓN
// =========================================================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  bool isLogin = true; 

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  InputDecoration _inputDecoration(String hint, IconData icon, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  bool isPasswordSecure(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_])[A-Za-z\d\W_]{8,}$');
    return regex.hasMatch(password);
  }

  void mostrarAlertaEmergente({required String titulo, required String mensaje, VoidCallback? onAceptar}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFFE53935)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo, 
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE53935), fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(mensaje),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                if (onAceptar != null) onAceptar();
              },
              child: const Text('Confirmar y Aceptar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> registrarUsuario() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;
    final nombre = nombreController.text.trim();

    if (nombre.isEmpty || email.isEmpty) {
      mostrarAlertaEmergente(titulo: 'Campos Vacíos', mensaje: 'Por favor, completa todos los campos del formulario.');
      return;
    }

    if (!email.endsWith('@gmail.com')) {
      mostrarAlertaEmergente(
        titulo: 'Correo Inválido', 
        mensaje: 'Por favor, utiliza una cuenta de correo de Gmail (@gmail.com) para registrarte.'
      );
      return;
    }

    if (password != confirm) {
      mostrarAlertaEmergente(titulo: 'Error de Claves', mensaje: 'Las contraseñas ingresadas no coinciden.');
      return;
    }

    if (!isPasswordSecure(password)) {
      mostrarAlertaEmergente(
        titulo: 'Clave Insegura', 
        mensaje: 'Tu contraseña debe tener al menos 8 caracteres, incluir números, una mayúscula, una minúscula y un símbolo especial.'
      );
      return;
    }

    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      if (userCredential.user != null) {
        DatabaseReference ref = FirebaseDatabase.instance.ref("usuarios/${userCredential.user!.uid}");
        await ref.set({
          'full_name': nombre,
          'photo_url': '', 
        });
        
        await _auth.setLanguageCode("es");
        await userCredential.user!.sendEmailVerification();
      }

      mostrarAlertaEmergente(
        titulo: '¡Registro Exitoso!',
        mensaje: 'Tu cuenta ha sido creada. Se ha enviado un correo de verificación a tu casilla de Gmail. Por favor, verifícalo para iniciar sesión.',
        onAceptar: () async {
          await _auth.signOut();
          if (mounted) {
            setState(() {
              isLogin = true;
              emailController.clear();
              passwordController.clear();
              confirmPasswordController.clear();
              nombreController.clear();
            });
          }
        }
      );
    } on FirebaseAuthException catch (e) {
      String errorMsg = 'No pudimos completar tu registro en este momento.';
      if (e.code == 'email-already-in-use') {
        errorMsg = 'Este correo electrónico ya se encuentra registrado.';
      } else if (e.code == 'weak-password') {
        errorMsg = 'La contraseña es muy fácil de adivinar.';
      }
      mostrarAlertaEmergente(titulo: 'Error de Registro', mensaje: errorMsg);
    } catch (e) {
      mostrarAlertaEmergente(titulo: 'Error', mensaje: 'Ocurrió un problema inesperado: $e');
    }
  }

  Future<void> iniciarSesion() async {
    final email = emailController.text.trim();
    
    if (email.isEmpty || passwordController.text.isEmpty) {
      mostrarAlertaEmergente(titulo: 'Campos Vacíos', mensaje: 'Ingresa tu correo y contraseña para entrar.');
      return;
    }

    if (!email.endsWith('@gmail.com')) {
      mostrarAlertaEmergente(
        titulo: 'Acceso Denegado', 
        mensaje: 'Solo se permite el acceso con correos electrónicos de Gmail (@gmail.com).'
      );
      return;
    }

    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Iniciando sesión... ¡Bienvenido estudiante UA!'),
            duration: Duration(seconds: 1),
          ),
        );
      }

    } on FirebaseAuthException catch (e) {
      String errorMsg = 'Error al intentar iniciar sesión.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMsg = 'El correo electrónico o la contraseña son incorrectos. Inténtalo de nuevo.';
      } else if (e.code == 'user-disabled') {
        errorMsg = 'Esta cuenta ha sido deshabilitada por el administrador.';
      }
      mostrarAlertaEmergente(titulo: 'Fallo de Conexión', mensaje: errorMsg);
    }
  }

  Future<void> recuperarContrasena() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.endsWith('@gmail.com')) {
      mostrarAlertaEmergente(
        titulo: 'Correo Requerido', 
        mensaje: 'Escribe tu correo @gmail.com en el casillero de arriba y luego presiona "Olvidé mi contraseña".'
      );
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      mostrarAlertaEmergente(
        titulo: 'Enlace Enviado', 
        mensaje: 'Hemos enviado las instrucciones para restablecer tu contraseña a tu correo de Gmail.'
      );
    } on FirebaseAuthException catch (e) {
      mostrarAlertaEmergente(titulo: 'Error de Envío', mensaje: 'No pudimos enviar el correo: ${e.message}');
    }
  }

Future<void> iniciarSesionGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      
      // 1. Limpiamos cualquier sesión previa para obligar a que aparezca el selector
      await googleSignIn.signOut();
      
      // 2. Iniciamos el proceso de login
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) return; // El usuario canceló

      // 3. Validación de dominio @gmail.com
      if (!googleUser.email.endsWith('@gmail.com')) {
        await googleSignIn.signOut();
        mostrarAlertaEmergente(
          titulo: 'Cuenta No Autorizada', 
          mensaje: 'Tu cuenta de Google debe ser de Gmail (@gmail.com) para ingresar.'
        );
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // 4. Registro inicial en la base de datos si es nuevo (Avance 2)
      if (userCredential.user != null) {
        DatabaseReference ref = FirebaseDatabase.instance.ref("usuarios/${userCredential.user!.uid}");
        final snapshot = await ref.child("full_name").get();
        
        if (!snapshot.exists) {
          await ref.set({
            'full_name': userCredential.user!.displayName ?? 'Estudiante UA',
            'photo_url': userCredential.user!.photoURL ?? '',
          });
        }
      }
    } catch (e) {
      // Si el error persiste, es probable que falte habilitar Google en la consola de Firebase
      mostrarAlertaEmergente(
        titulo: 'Error Google', 
        mensaje: 'No se pudo conectar. Asegúrate de tener conexión a internet y de haber habilitado Google en Authentication de Firebase.'
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.co_present_rounded, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              
              Text(
                isLogin ? 'Portal Estudiante UA' : 'Registrar Estudiante',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE53935),
                ),
              ),
              const SizedBox(height: 40),

              if (!isLogin) ...[
                TextField(
                  controller: nombreController,
                  decoration: _inputDecoration('Nombre completo', Icons.person),
                ),
                const SizedBox(height: 16),
              ],
              
              TextField(
                controller: emailController,
                decoration: _inputDecoration('Correo electrónico @gmail.com', Icons.email),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: passwordController,
                decoration: _inputDecoration(
                  'Contraseña', 
                  Icons.lock,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscurePassword,
              ),
              
              if (!isLogin) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: _inputDecoration(
                    'Confirmar Contraseña', 
                    Icons.lock_outline,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                ),
                obscureText: _obscureConfirmPassword,
              ),
              ],
              
              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: isLogin ? iniciarSesion : registrarUsuario,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(isLogin ? Icons.login : Icons.app_registration),
                    const SizedBox(width: 8),
                    Text(
                      isLogin ? 'Iniciar sesión' : 'Registrar',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              TextButton(
                onPressed: () {
                  setState(() {
                    isLogin = !isLogin;
                  });
                },
                child: Text(
                  isLogin ? '¿No tienes cuenta? Regístrate' : '¿Ya tienes cuenta? Inicia sesión',
                  style: const TextStyle(color: Color(0xFFE53935)),
                ),
              ),

              if (isLogin) ...[
                TextButton(
                  onPressed: recuperarContrasena,
                  child: const Text('Olvidé mi contraseña', style: TextStyle(color: Colors.grey)),
                ),
                const Divider(height: 30),
                OutlinedButton.icon(
                  onPressed: iniciarSesionGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.blue),
                  label: const Text('Continuar con Google', style: TextStyle(color: Colors.black87)),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 2. ESTRUCTURA PRINCIPAL (3 PANTALLAS EXIGIDAS EN AVANCE 2)
// =========================================================================
class HomeNavegacion extends StatefulWidget {
  const HomeNavegacion({super.key});

  @override
  State<HomeNavegacion> createState() => _HomeNavegacionState();
}

class _HomeNavegacionState extends State<HomeNavegacion> {
  int currentPageIndex = 0;

  final List<Widget> _pantallas = [
    const PantallaSolicitudesCRUD(), // 1. Módulo Principal CRUD de Solicitudes
    const PantallaHistorialAsistencia(), // 2. Pantalla Informativa / Historial
    const PantallaPerfil(), // 3. Pantalla de Perfil de Estudiante
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pantallas[currentPageIndex],
      bottomNavigationBar: NavigationBar(
        onDestinationSelected: (int index) {
          setState(() {
            currentPageIndex = index;
          });
        },
        selectedIndex: currentPageIndex,
        destinations: const <Widget>[
          NavigationDestination(
            icon: Icon(Icons.edit_document),
            selectedIcon: Icon(Icons.assignment_turned_in),
            label: 'Justificar',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Mi Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Mi Perfil',
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// 3. MÓDULO PRINCIPAL: CRUD COMPLETO DE JUSTIFICACIONES (AVANCE 2)
// =========================================================================
class PantallaSolicitudesCRUD extends StatefulWidget {
  const PantallaSolicitudesCRUD({super.key});

  @override
  State<PantallaSolicitudesCRUD> createState() => _PantallaSolicitudesCRUDState();
}

class _PantallaSolicitudesCRUDState extends State<PantallaSolicitudesCRUD> {
  final _auth = FirebaseAuth.instance;
  final _dbRef = FirebaseDatabase.instance.ref();
  
  final _asignaturaController = TextEditingController();
  final _motivoController = TextEditingController();
  String _fechaSeleccionada = "Hoy"; 

  List<Map<dynamic, dynamic>> _solicitudesList = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _escucharSolicitudes();
  }

  // LEER (R): Lista Dinámica en tiempo real filtrada por alumno autenticado
void _escucharSolicitudes() {
    final user = _auth.currentUser;
    if (user != null) {
      _dbRef.child("solicitudes/${user.uid}").onValue.listen((event) {
        final List<Map<dynamic, dynamic>> temporalList = [];
        final data = event.snapshot.value as Map<dynamic, dynamic>?;

        if (data != null) {
          data.forEach((key, value) {
            temporalList.add({
              'id': key,
              'asignatura': value['asignatura'],
              'motivo': value['motivo'],
              'fecha': value['fecha'],
              'estado': value['estado'] ?? 'Pendiente',
            });
          });
        }

        if (mounted) {
          setState(() {
            // Reemplazamos la lista por completo con los datos del usuario actual
            _solicitudesList = temporalList; 
            _cargando = false;
          });
        }
      });
    } else {
      // Si por algún motivo el usuario es nulo, vaciamos la lista de inmediato
      if (mounted) {
        setState(() {
          _solicitudesList = [];
          _cargando = false;
        });
      }
    }
  }

  // CREAR (C) / ACTUALIZAR (U): Formulario para enviar o editar justificación
  void _mostrarFormulario({String? id, String? asignaturaOriginal, String? motivoOriginal, String? fechaOriginal}) {
    if (id != null) {
      _asignaturaController.text = asignaturaOriginal ?? "";
      _motivoController.text = motivoOriginal ?? "";
      _fechaSeleccionada = fechaOriginal ?? "Hoy";
    } else {
      _asignaturaController.clear();
      _motivoController.clear();
      _fechaSeleccionada = "Hoy";
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(id == null ? 'Nueva Justificación' : 'Editar Justificación', style: const TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _asignaturaController,
                      decoration: const InputDecoration(labelText: 'Asignatura (ej: Cálculo)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _motivoController,
                      decoration: const InputDecoration(labelText: 'Motivo (ej: Falla de tarjeta RFID)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _fechaSeleccionada,
                      decoration: const InputDecoration(labelText: 'Fecha de la Inasistencia'),
                      items: <String>['Hoy', 'Ayer', 'Clase Anterior'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setDialogState(() {
                          _fechaSeleccionada = newValue!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
                  onPressed: () => _guardarJustificacion(id: id),
                  child: const Text('Enviar', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // VALIDACIONES antes de guardar
  void _guardarJustificacion({String? id}) async {
    final asignatura = _asignaturaController.text.trim();
    final motivo = _motivoController.text.trim();
    final user = _auth.currentUser;

    if (user == null) return;

    if (asignatura.isEmpty || motivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa la materia y el motivo antes de enviar.')),
      );
      return;
    }

    try {
      if (id == null) {
        // CREAR en Firebase
        await _dbRef.child("solicitudes/${user.uid}").push().set({
          'asignatura': asignatura,
          'motivo': motivo,
          'fecha': _fechaSeleccionada,
          'estado': 'Pendiente',
        });
        _mostrarSnackBar('¡Solicitud de justificación enviada!');
      } else {
        // ACTUALIZAR en Firebase
        await _dbRef.child("solicitudes/${user.uid}/$id").update({
          'asignatura': asignatura,
          'motivo': motivo,
          'fecha': _fechaSeleccionada,
        });
        _mostrarSnackBar('¡Solicitud modificada con éxito!');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _mostrarSnackBar('Error al guardar: $e');
    }
  }

  // ELIMINAR (D) con diálogo de confirmación explícita
  void _confirmarEliminar(String id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cancelar Solicitud', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('¿Estás seguro de que deseas retirar esta solicitud de justificación?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final user = _auth.currentUser;
                if (user != null) {
                  await _dbRef.child("solicitudes/${user.uid}/$id").remove();
                  _mostrarSnackBar('Solicitud eliminada.');
                }
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _mostrarSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Justificar Asistencia', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFE53935),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE53935))) // Estado de carga
          : _solicitudesList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_document, size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes solicitudes pendientes de revisión.\n¡Usa el botón + si tuviste problemas de asistencia!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : ListView.builder( // Lista Dinámica
                  padding: const EdgeInsets.all(16),
                  itemCount: _solicitudesList.length,
                  itemBuilder: (context, index) {
                    final item = _solicitudesList[index];
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE53935),
                          foregroundColor: Colors.white,
                          child: Icon(Icons.assignment_late),
                        ),
                        title: Text(
                          item['asignatura'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Text(
                          'Motivo: ${item['motivo']}\nFecha: ${item['fecha']}   |   Estado: ${item['estado']}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blueAccent),
                              onPressed: () => _mostrarFormulario(
                                id: item['id'],
                                asignaturaOriginal: item['asignatura'],
                                motivoOriginal: item['motivo'],
                                fechaOriginal: item['fecha'],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _confirmarEliminar(item['id']),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormulario(),
        backgroundColor: const Color(0xFFE53935),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// =========================================================================
// 4. PANTALLA SECUNDARIA: HISTORIAL DE ASISTENCIA
// =========================================================================
class PantallaHistorialAsistencia extends StatelessWidget {
  const PantallaHistorialAsistencia({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Historial de Asistencia', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE53935),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.history_toggle_off, size: 80, color: Color(0xFFE53935)),
            const SizedBox(height: 24),
            const Text(
              'Bitácora de Clases',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 12),
            Text(
              'Aquí podrás visualizar todas tus asistencias registradas exitosamente por el lector de tarjetas RFID de la universidad.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// 5. PANTALLA DE PERFIL (CON FOTO EN BASE64)
// =========================================================================
class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final nombreController = TextEditingController();
  String nombreMostrado = "Cargando...";
  String photoBase64 = ""; 
  bool procesandoFoto = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosDePerfil();
  }

  Future<void> _cargarDatosDePerfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DatabaseReference ref = FirebaseDatabase.instance.ref("usuarios/${user.uid}");
        final snapshot = await ref.get();

        if (mounted && snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            nombreMostrado = data['full_name'] ?? "Sin nombre registrado";
            nombreController.text = nombreMostrado;
            photoBase64 = data['photo_url'] ?? "";
          });
        }
      } catch (e) {
        if (mounted) setState(() { nombreMostrado = "Error al cargar"; });
      }
    }
  }

  Future<void> _seleccionarYGuardarFoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final XFile? imagenSeleccionada = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 35, 
    );

    if (imagenSeleccionada != null) {
      setState(() { procesandoFoto = true; });
      try {
        String base64Image = base64Encode(await File(imagenSeleccionada.path).readAsBytes());
        await FirebaseDatabase.instance.ref("usuarios/${user.uid}").update({'photo_url': base64Image});

        if (mounted) {
          setState(() {
            photoBase64 = base64Image;
            procesandoFoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto actualizada.')));
        }
      } catch (e) {
        setState(() { procesandoFoto = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Lógica inteligente para mostrar la imagen sin errores
    ImageProvider? imagenDePerfil;
    
    if (photoBase64.isNotEmpty) {
      if (photoBase64.startsWith('http')) {
        // Si la ruta comienza con http, es una URL directa (Google)
        imagenDePerfil = NetworkImage(photoBase64);
      } else {
        // Si no, intentamos decodificar el Base64 (Galería)
        try {
          imagenDePerfil = MemoryImage(base64Decode(photoBase64));
        } catch (e) {
          // Si el base64 está corrupto o mal formateado, volvemos al icono por defecto
          imagenDePerfil = null;
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE53935),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: imagenDePerfil,
                    child: imagenDePerfil == null
                        ? const Icon(Icons.person, size: 60, color: Colors.white)
                        : null,
                  ),
                  if (procesandoFoto)
                    const Positioned.fill(child: CircularProgressIndicator(color: Color(0xFFE53935))),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      backgroundColor: const Color(0xFFE53935),
                      radius: 20,
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        onPressed: _seleccionarYGuardarFoto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID de Estudiante:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(user?.uid ?? '---', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Text('Correo Institucional:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(user?.email ?? '---', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text('Nombre Registrado:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(nombreMostrado, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFFE53935))),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Text('Editar información', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),

            TextField(
              controller: nombreController,
              decoration: InputDecoration(
                labelText: 'Nuevo Nombre Completo',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.edit),
              ),
            ),
            const SizedBox(height: 16),
            
            ElevatedButton(
              onPressed: () async {
                await FirebaseDatabase.instance.ref("usuarios/${user!.uid}").update({'full_name': nombreController.text});
                setState(() { nombreMostrado = nombreController.text; });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado con éxito.')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Guardar Datos'),
            ),
            
            const SizedBox(height: 40), 
            OutlinedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                await GoogleSignIn().signOut();
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}