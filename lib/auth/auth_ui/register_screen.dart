import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../auth_viewmodel/auth_viewmodel.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoPaternoController = TextEditingController();
  final _apellidoMaternoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _ocultarPassword = true;
  bool _ocultarConfirmPassword = true;

  String _selectedRole = 'usuario';

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoPaternoController.dispose();
    _apellidoMaternoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                Positioned(top: 60, left: -50, child: _circle(200, Colors.white.withOpacity(0.05))),
                Positioned(top: 140, right: -30, child: _circle(150, Colors.white.withOpacity(0.05))),
                SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 40),
                      const Text("Crea tu cuenta", style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
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
                                  const SizedBox(height: 10),
                                  _buildTextFieldNormal(_nombreController, "Nombre", Icons.person),
                                  const SizedBox(height: 15),
                                  _buildTextFieldNormal(_apellidoPaternoController, "Apellido Paterno", Icons.person),
                                  const SizedBox(height: 15),
                                  _buildTextFieldNormal(_apellidoMaternoController, "Apellido Materno", Icons.person),
                                  const SizedBox(height: 15),

                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: 'Correo',
                                      prefixIcon: const Icon(Icons.email),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Ingresa tu correo';
                                      if (!value.contains('@')) return 'Ingresa un correo válido';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 15),

                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _ocultarPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Contraseña',
                                      prefixIcon: const Icon(Icons.lock),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      suffixIcon: IconButton(
                                        icon: Icon(_ocultarPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                        onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return "Introducir contraseña";
                                      if (value.length < 6) return "Mínimo 6 caracteres";
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 15),

                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _ocultarConfirmPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Confirmar Contraseña',
                                      prefixIcon: const Icon(Icons.lock),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      suffixIcon: IconButton(
                                        icon: Icon(_ocultarConfirmPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                        onPressed: () => setState(() => _ocultarConfirmPassword = !_ocultarConfirmPassword),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return "Confirma tu contraseña";
                                      if (value != _passwordController.text) return "Las contraseñas no coinciden";
                                      return null;
                                    },
                                  ),

                                  const SizedBox(height: 20),
                                  Container(
                                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedRole,
                                      decoration: const InputDecoration(border: InputBorder.none, prefixIcon: Icon(Icons.person_outline), labelText: 'Rol'),
                                      items: const [
                                        DropdownMenuItem(value: 'usuario', child: Text('Usuario')),
                                        DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                                      ],
                                      onChanged: (value) => setState(() => _selectedRole = value!),
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _selectedRole == 'admin' ? 'Los administradores pueden gestionar reportes y modificar severidades.' : 'Los usuarios pueden crear reportes y corroborar incidentes.',
                                            style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 30),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: viewModel.isLoading ? null : () => _handleRegister(context, viewModel),
                                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                      child: viewModel.isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Registrarse"),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('¿Ya tienes cuenta? Inicia sesión', style: TextStyle(color: Colors.blue)),
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

  Future<void> _handleRegister(BuildContext context, AuthViewModel viewModel) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await viewModel.register(
      nombre: _nombreController.text.trim(),
      apellidoPaterno: _apellidoPaternoController.text.trim(),
      apellidoMaterno: _apellidoMaternoController.text.trim(),
      correo: _emailController.text.trim(), // Se envía libre, como estaba
      contrasena: _passwordController.text.trim(),
      role: _selectedRole,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("¡Registro exitoso! Ahora inicia sesión como ${_selectedRole == 'admin' ? 'Administrador' : 'Usuario'}"), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
        _nombreController.clear();
        _apellidoPaternoController.clear();
        _apellidoMaternoController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        Navigator.pop(context);
      }
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.error ?? "Error al registrarse")));
    }
  }

  Widget _circle(double size, Color color) {
    return Container(height: size, width: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }

  Widget _buildTextFieldNormal(TextEditingController controller, String hint, IconData icon) {
    return TextFormField(
      controller: controller,
      validator: (value) => (value == null || value.isEmpty) ? "Ingrese $hint" : null,
      decoration: InputDecoration(
        labelText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}