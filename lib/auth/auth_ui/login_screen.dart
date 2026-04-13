import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../auth_viewmodel/auth_viewmodel.dart';
import '../../ui/registered_admin_screen.dart';
import '../../ui/registered_user_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _ocultarPassword = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthViewModel(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Consumer<AuthViewModel>(
          builder: (context, viewModel, child) {
            return Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(top: 80, left: -50, child: _circle(200, Colors.white.withOpacity(0.05))),
                Positioned(top: 150, right: -30, child: _circle(150, Colors.white.withOpacity(0.05))),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      Image.asset(
                        'asset/images/transparent.png',
                        height: 100,
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Bienvenido",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),                      const SizedBox(height: 40),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.only(top: 24, left: 24, right: 24),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Correo electrónico',
                                      prefixIcon: Icon(Icons.email),
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Por favor ingresa tu correo';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _ocultarPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(Icons.lock),
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: Icon(_ocultarPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                        onPressed: () {
                                          setState(() {
                                            _ocultarPassword = !_ocultarPassword;
                                          });
                                        },
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return "Introducir contraseña";
                                      if (value.length < 6) return "Min 6 characters";
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 30),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: viewModel.isLoading ? null : () => _handleLogin(context, viewModel),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: viewModel.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Log in"),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("¿No tienes cuenta? "),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (context) => const RegisterPage()),
                                          );
                                        },
                                        child: const Text(
                                          "Regístrate",
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleLogin(BuildContext context, AuthViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await viewModel.login(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );

    if (success && mounted) {
      final role = viewModel.currentUser?.role ?? 'usuario';
      if (role == 'admin') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisteredAdminScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegisteredUserScreen()));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.error ?? "Fallo durante inicio de sesion")));
      }
    }
  }

  Widget _circle(double size, Color color) {
    return Container(height: size, width: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}