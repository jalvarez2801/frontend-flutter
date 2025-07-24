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
  User? _user;
  String _apiMessage = "Inicia sesión para obtener el saludo";
  late StreamSubscription<User?> _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _user = user;
          if (_user == null) {
            _apiMessage = "Inicia sesión para obtener el saludo";
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> signInAnonymously() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      // FIX (use_build_context_synchronously):
      // Se verifica si el widget todavía está "montado" (visible en el árbol de widgets)
      // antes de intentar usar su BuildContext. Esto evita errores si el usuario
      // navega a otra pantalla mientras la operación asíncrona se completaba.
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al iniciar sesión: $e")),
      );
    }
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _fetchGreeting() async {
    if (_user == null) {
      if (mounted) {
        setState(() {
          _apiMessage = "Error: Debes estar autenticado para hacer esto.";
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _apiMessage = "Obteniendo saludo...";
      });
    }

    final String url = Platform.isAndroid
        ? 'http://10.0.2.2:3000/saludo'
        : 'http://localhost:3000/saludo';

    // FIX (avoid_print):
    // Se reemplaza `print` por `debugPrint`. `debugPrint` es la alternativa recomendada
    // para logs de depuración, ya que se elimina automáticamente en las compilaciones
    // de producción (release) y evita la sobrecarga de logs en la consola.
    debugPrint("Intentando conectar a: $url");

    try {
      final response = await http.get(Uri.parse(url));

      debugPrint(
          "Respuesta recibida. Código de estado: ${response.statusCode}");

      // Se verifica si el widget está montado antes de actualizar el estado.
      if (!mounted) return;

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
      debugPrint("Ha ocurrido un error de conexión: $e");

      // Se verifica si el widget está montado antes de actualizar el estado.
      if (!mounted) return;

      setState(() {
        _apiMessage = 'Error de conexión. Revisa la consola para más detalles.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
              isSignedIn
                  ? Text("Conectado como: Anónimo\nUID: ${_user!.uid}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green[700]))
                  : const Text("No autenticado",
                      style: TextStyle(color: Colors.red)),
              const SizedBox(height: 20),
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
              ElevatedButton(
                onPressed: isSignedIn ? _fetchGreeting : null,
                child: const Text("Obtener Saludo"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
