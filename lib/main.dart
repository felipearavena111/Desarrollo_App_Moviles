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
      title: 'App UA',
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
// 1. PANTALLA DE AUTENTICACIÓN (CON TODAS LAS CORRECCIONES DEL PROFESOR)
// =========================================================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  bool isLogin = true; 

  // Controladores de visibilidad de contraseña
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

  // Validación de contraseña robusta
  bool isPasswordSecure(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_])[A-Za-z\d\W_]{8,}$');
    return regex.hasMatch(password);
  }

  // VENTANA EMERGENTE PERSONALIZADA (Exigencia del Profesor)
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


  // REGISTRO DE USUARIOS (Corregido para que la alerta no se cierre sola)
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
      // 1. Crear el perfil de autenticación en Firebase
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password,
      );
      
      // 2. Guardar datos iniciales en la base de datos
      if (userCredential.user != null) {
        DatabaseReference ref = FirebaseDatabase.instance.ref("usuarios/${userCredential.user!.uid}");
        await ref.set({
          'full_name': nombre,
          'photo_url': '', 
        });
        
        await _auth.setLanguageCode("es");
        await userCredential.user!.sendEmailVerification();
      }

      // 3. Mostramos la alerta PRIMERO. 
      // El cierre de sesión y la limpieza ocurren SOLO cuando el usuario presiona "Confirmar y Aceptar"
      mostrarAlertaEmergente(
        titulo: '¡Registro Exitoso!',
        mensaje: 'Tu cuenta ha sido creada. Se ha enviado un correo de verificación a tu casilla de Gmail. Por favor, verifícalo para iniciar sesión.',
        onAceptar: () async {
          // Recién aquí cerramos la sesión y limpiamos la pantalla
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

  // INICIO DE SESIÓN (Optimizado para la presentación - Versión única y sin errores)
  Future<void> iniciarSesion() async {
    final email = emailController.text.trim();
    
    if (email.isEmpty || passwordController.text.isEmpty) {
      mostrarAlertaEmergente(titulo: 'Campos Vacíos', mensaje: 'Ingresa tu correo y contraseña para entrar.');
      return;
    }

    // CAMBIO: Validación adaptada a @gmail.com
    if (!email.endsWith('@gmail.com')) {
      mostrarAlertaEmergente(
        titulo: 'Acceso Denegado', 
        mensaje: 'Solo se permite el acceso con correos electrónicos de Gmail (@gmail.com).'
      );
      return;
    }

    try {
      // Iniciamos sesión directamente
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: passwordController.text,
      );

      // Mensaje rápido de éxito antes de pasar a la pantalla de Inicio
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

  // RECUPERAR CONTRASEÑA
  Future<void> recuperarContrasena() async {
    final email = emailController.text.trim();
    // CAMBIO: Validación adaptada a @gmail.com
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

// INICIAR SESIÓN / REGISTRAR CON GOOGLE (AHORA SÍ, CON EL IMPORT CORREGIDO)
  Future<void> iniciarSesionGoogle() async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) return; // El usuario canceló el flujo

      // Validación adaptada a @gmail.com
      if (!googleUser.email.endsWith('@gmail.com')) {
        await googleSignIn.signOut();
        mostrarAlertaEmergente(
          titulo: 'Cuenta No Autorizada', 
          mensaje: 'Tu cuenta de Google debe ser de Gmail (@gmail.com) para ingresar.'
        );
        return;
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      
      // Si es su primer inicio, guardamos el nombre en la base de datos
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
      mostrarAlertaEmergente(
        titulo: 'Error Google', 
        mensaje: 'No se pudo conectar con Google. Verifica que el botón de Google esté habilitado en Firebase.'
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
                child: const Icon(Icons.lock, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              
              Text(
                isLogin ? 'Login UA' : 'Registrar Usuario UA',
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
                // CAMBIO: HintText modificado a @gmail.com
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

// ==========================================
// 2. ESTRUCTURA PRINCIPAL (NAVIGATION BAR M3)
// ==========================================
class HomeNavegacion extends StatefulWidget {
  const HomeNavegacion({super.key});

  @override
  State<HomeNavegacion> createState() => _HomeNavegacionState();
}

class _HomeNavegacionState extends State<HomeNavegacion> {
  int currentPageIndex = 0;

  final List<Widget> _pantallas = [
    const PantallaInicio(), 
    const PantallaPerfil(), 
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
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 3. PANTALLA DE INICIO 
// ==========================================
class PantallaInicio extends StatelessWidget {
  const PantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inicio', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE53935),
      ),
      body: const Center(
        child: Text('Pantalla principal de la aplicación.'),
      ),
    );
  }
}

// =========================================================================
// 4. PANTALLA DE PERFIL (CON DATOS DINÁMICOS Y FOTO EN BASE64)
// =========================================================================
class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final nombreController = TextEditingController();
  String nombreMostrado = "Cargando...";
  String photoBase64 = ""; // Almacenará la foto en Base64
  bool procesandoFoto = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosDePerfil();
  }

  // CARGAR DATOS
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
        if (mounted) {
          setState(() {
            nombreMostrado = "Error al cargar datos";
          });
        }
      }
    }
  }

  // SELECCIONAR, PROCESAR Y GUARDAR FOTO EN BASE64
  Future<void> _seleccionarYGuardarFoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final picker = ImagePicker();
    final XFile? imagenSeleccionada = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 35, // Comprime la imagen para que quepa en la base de datos sin problemas
    );

    if (imagenSeleccionada != null) {
      setState(() {
        procesandoFoto = true;
      });

      try {
        File archivo = File(imagenSeleccionada.path);
        List<int> imageBytes = await archivo.readAsBytes();
        String base64Image = base64Encode(imageBytes); // Convierte a Base64

        DatabaseReference dbRef = FirebaseDatabase.instance.ref("usuarios/${user.uid}");
        await dbRef.update({
          'photo_url': base64Image,
        });

        if (mounted) {
          setState(() {
            photoBase64 = base64Image;
            procesandoFoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil actualizada con éxito.')),
          );
        }
      } catch (e) {
        setState(() {
          procesandoFoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar la imagen: $e')),
        );
      }
    }
  }

  // VENTANA EMERGENTE DE CONFIRMACIÓN PARA CERRAR SESIÓN (Punto Crítico)
  void mostrarConfirmacionCerrarSesion() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Confirmar Salida', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('¿Estás seguro de que deseas cerrar sesión en la aplicación?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
              onPressed: () {
                Navigator.of(context).pop();
                cerrarSesion();
              },
              child: const Text('Cerrar Sesión', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // GUARDAR PERFIL
  Future<void> guardarPerfil() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final nuevoNombre = nombreController.text.trim();
      if (nuevoNombre.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El nombre no puede quedar vacío.')),
        );
        return;
      }
      try {
        DatabaseReference ref = FirebaseDatabase.instance.ref("usuarios/${user.uid}");
        await ref.update({
          'full_name': nuevoNombre,
        });
        
        if (mounted) {
          setState(() {
            nombreMostrado = nuevoNombre;
          });
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perfil actualizado correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al guardar: $e')),
          );
        }
      }
    }
  }

  Future<void> cerrarSesion() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userEmail = user?.email ?? 'Sin correo';
    final userId = user?.uid ?? 'Sin ID';

    // Intenta decodificar la foto si existe en formato Base64
    ImageProvider? imagenDePerfil;
    if (photoBase64.isNotEmpty) {
      try {
        if (photoBase64.startsWith('http')) {
          imagenDePerfil = NetworkImage(photoBase64); // Por si viene de Google
        } else {
          imagenDePerfil = MemoryImage(base64Decode(photoBase64)); // Decodifica Base64
        }
      } catch (_) {
        imagenDePerfil = null;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFE53935),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AVATAR CON FOTO EN BASE64
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
                    const Positioned.fill(
                      child: CircularProgressIndicator(color: Color(0xFFE53935)),
                    ),
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
                  Text(userId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Text('Correo Institucional:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(userEmail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              onPressed: guardarPerfil,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Guardar Datos'),
            ),
            
            const SizedBox(height: 40), 
            OutlinedButton.icon(
              onPressed: mostrarConfirmacionCerrarSesion, // Alerta emergente de confirmación obligatoria
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: Colors.red),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}