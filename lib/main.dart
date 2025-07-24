import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io'; // Importante para detectar la plataforma
import 'dart:async';

void main() async {
  // Asegura que los bindings de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();
  // Inicializa Firebase
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase & API Demo',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ),
      home: const AuthExample(),
    );
  }
}

class AuthExample extends StatefulWidget {
  const AuthExample({super.key});

  @override
  AuthExampleState createState() => AuthExampleState();
}

class AuthExampleState extends State<AuthExample> {
  // ✅ MEJORA: Usar el objeto User? para un estado de autenticación más robusto
  User? _user;
  String _apiMessage = "Inicia sesión para obtener el saludo";

  // ✅ MEJORA: Un listener para reaccionar a los cambios de autenticación
  late StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Escucha los cambios en el estado de autenticación (login/logout)
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      setState(() {
        _user = user;
        // Si el usuario cierra sesión, reseteamos el mensaje de la API.
        if (_user == null) {
          _apiMessage = "Inicia sesión para obtener el saludo";
        }
      });
    });
  }

  @override
  void dispose() {
    // Es crucial cancelar la suscripción para evitar fugas de memoria
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> signInAnonymously() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      // El listener de authStateChanges se encargará de actualizar la UI
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al iniciar sesión: $e")),
      );
    }
  }

  // ✅ MEJORA: Función para cerrar sesión
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _fetchGreeting() async {
    // Doble verificación: aunque el botón está deshabilitado, es una buena práctica verificar.
    if (_user == null) {
      setState(() {
        _apiMessage = "Error: Debes estar autenticado para hacer esto.";
      });
      return;
    }

    setState(() {
      _apiMessage = "Obteniendo saludo...";
    });

    final String url = Platform.isAndroid
        ? 'http://10.0.2.2:3000/saludo'
        : 'http://localhost:3000/saludo';
    print("Intentando conectar a: $url");

    try {
      final response = await http.get(Uri.parse(url));

      print("Respuesta recibida. Código de estado: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _apiMessage =
              data['mensaje'] ?? 'El JSON no tiene la clave "mensaje".';
        });
      } else {
        setState(() {
          _apiMessage =
              'Error del servidor: ${response.statusCode}\nCuerpo: ${response.body}';
        });
      }
    } catch (e) {
      print("Ha ocurrido un error de conexión: $e");
      setState(() {
        _apiMessage = 'Error de conexión. Revisa la consola de Flutter.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determina si el usuario está autenticado
    final bool isSignedIn = _user != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Firebase & API")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Estado de Firebase:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              // ✅ MEJORA: Muestra un estado claro basado en si _user es nulo o no
              isSignedIn
                  ? Text("Conectado como: Anónimo\nUID: ${_user!.uid}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green[700]))
                  : const Text("No autenticado",
                      style: TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
              // ✅ MEJORA: Muestra un botón u otro dependiendo del estado de autenticación
              if (isSignedIn)
                ElevatedButton(
                  onPressed: signOut,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Cerrar Sesión"),
                )
              else
                ElevatedButton(
                  onPressed: signInAnonymously,
                  child: const Text("Login anónimo"),
                ),
              const Divider(height: 40, thickness: 1),
              const Text("Respuesta de la API:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(_apiMessage, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              // ✅ MEJORA CLAVE: El botón se deshabilita si `isSignedIn` es falso.
              // La propiedad `onPressed` se pone a null para deshabilitarlo.
              ElevatedButton(
                onPressed:
                    isSignedIn ? _fetchGreeting : null, // <-- AQUÍ LA MAGIA
                child: const Text("Obtener Saludo"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
