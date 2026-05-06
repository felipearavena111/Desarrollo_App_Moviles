import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nkfgapjvxuyouondwlna.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5rZmdhcGp2eHV5b3VvbmR3bG5hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5MTQ3NDksImV4cCI6MjA5MjQ5MDc0OX0.UQQKk5UMZgdN-hpDcT3gv1NSlZ1MpUxggPoc94qcK3s',
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
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.session != null) {
            return const HomeNavegacion();
          }
          return const AuthScreen(); 
        },
      ),
    );
  }
}

// ==========================================
// 1. PANTALLA DE AUTENTICACIÓN (LOGIN Y REGISTRO)
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final supabase = Supabase.instance.client;
  bool isLogin = true; 

  final nombreController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.grey[700]),
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

  Future<void> registrarUsuario() async {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmPasswordController.text;
    final nombre = nombreController.text.trim();

    if (nombre.isEmpty || email.isEmpty || !email.contains('@')) {
      mostrarMensaje('Revisa los campos de nombre y correo electrónico');
      return;
    }
    if (password != confirm) {
      mostrarMensaje('Las contraseñas no coinciden');
      return;
    }
    if (!isPasswordSecure(password)) {
      mostrarMensaje('La contraseña debe tener al menos 8 caracteres, números, letras (min/mayús) y símbolos');
      return;
    }

    try {
      final AuthResponse res = await supabase.auth.signUp(email: email, password: password);
      
      if (res.user != null) {
        await supabase.from('profiles').upsert({'id': res.user!.id, 'full_name': nombre});
      }
      mostrarMensaje('Registro exitoso. Revisa tu correo para confirmar.');
      setState(() => isLogin = true); 
    } on AuthException catch (e) {
      mostrarMensaje('Error: ${e.message}');
    }
  }

  Future<void> iniciarSesion() async {
    try {
      await supabase.auth.signInWithPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );
    } on AuthException catch (e) {
      mostrarMensaje('Error al iniciar sesión: ${e.message}');
    }
  }

  Future<void> recuperarContrasena() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      mostrarMensaje('Ingresa tu correo arriba y presiona "Olvidé mi contraseña"');
      return;
    }
    try {
      await supabase.auth.resetPasswordForEmail(email);
      mostrarMensaje('Se ha enviado un correo de recuperación.');
    } on AuthException catch (e) {
      mostrarMensaje('Error: ${e.message}');
    }
  }

  Future<void> iniciarSesionGoogle() async {
    try {
      await supabase.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      mostrarMensaje('Error con Google SignIn: $e');
    }
  }

  void mostrarMensaje(String texto) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
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
                decoration: _inputDecoration('Correo electrónico', Icons.email),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: passwordController,
                decoration: _inputDecoration('Contraseña', Icons.lock),
                obscureText: true,
              ),
              
              if (!isLogin) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  decoration: _inputDecoration('Confirmar Contraseña', Icons.lock_outline),
                  obscureText: true,
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

// ==========================================
// 4. PANTALLA DE PERFIL (Muestra ID, Correo y Actualiza Nombre)
// ==========================================
class PantallaPerfil extends StatefulWidget {
  const PantallaPerfil({super.key});

  @override
  State<PantallaPerfil> createState() => _PantallaPerfilState();
}

class _PantallaPerfilState extends State<PantallaPerfil> {
  final supabase = Supabase.instance.client;
  final nombreController = TextEditingController();
  
  String nombreMostrado = "Cargando...";

  @override
  void initState() {
    super.initState();
    _cargarDatosDePerfil();
  }

  Future<void> _cargarDatosDePerfil() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await supabase
            .from('profiles')
            .select('full_name')
            .eq('id', user.id)
            .maybeSingle();

        if (mounted) {
          setState(() {
            if (data != null && data['full_name'] != null) {
              nombreMostrado = data['full_name'];
              nombreController.text = nombreMostrado;
            } else {
              nombreMostrado = "Sin nombre registrado";
            }
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

  Future<void> guardarPerfil() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      final nuevoNombre = nombreController.text.trim();
      try {
        await supabase.from('profiles').upsert({
          'id': user.id,
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
    await supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final userEmail = user?.email ?? 'Sin correo';
    final userId = user?.id ?? 'Sin ID';

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
                  Text('ID de Usuario:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(userId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Text('Correo:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  Text(userEmail, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text('Nombre Actual:', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
            
            const SizedBox(height: 60), 
            OutlinedButton.icon(
              onPressed: cerrarSesion,
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