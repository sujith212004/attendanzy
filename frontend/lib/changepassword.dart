import 'package:flutter/material.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:flutter_attendence_app/loginpage.dart';
import 'config/local_config.dart';

class ChangePasswordPage extends StatefulWidget {
  final String email; // logged-in user's email
  final String role; // user role: "user", "staff", "hod"

  const ChangePasswordPage({
    super.key,
    required this.email,
    required this.role,
  });

  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _loading = false;
  String _errorMessage = '';
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  final String mongoUri = LocalConfig.mongoUri;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String getCollectionName() {
    switch (widget.role.toLowerCase()) {
      case "user":
        return "profile";
      case "staff":
        return "Staff";
      case "hod":
        return "HOD";
      default:
        throw Exception("Invalid role: ${widget.role}");
    }
  }

  Future<void> _updatePassword() async {
    setState(() {
      _errorMessage = '';
      _loading = true;
    });

    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields.';
        _loading = false;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
        _loading = false;
      });
      return;
    }

    try {
      final db = await mongo.Db.create(mongoUri);
      await db.open();
      final collection = db.collection(getCollectionName());

      // Find user by email (case-insensitive)
      final user = await collection.findOne({
        "email": {
          "\$regex": "^${RegExp.escape(widget.email)}\$",
          "\$options": "i",
        },
      });

      if (user == null) {
        setState(() {
          _errorMessage = "User not found.";
          _loading = false;
        });
        await db.close();
        return;
      }

      // Update password using exact email
      final result = await collection.updateOne(
        mongo.where.eq("email", user["email"]),
        mongo.modify.set("password", newPassword),
      );

      await db.close();

      if (result.isSuccess) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
        );
      } else {
        setState(() {
          _errorMessage = "Failed to update password.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Error: $e";
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hintText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required bool isPasswordVisible,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
          prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
          suffixIcon: IconButton(
            icon: Icon(
              isPasswordVisible ? Icons.visibility : Icons.visibility_off,
              color: Colors.grey,
            ),
            onPressed: onToggleVisibility,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFFD194), Color(0xFF70E1F5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Set a new password to continue',
                  style: TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 40),
                _buildPasswordField(
                  controller: _newPasswordController,
                  hintText: 'New Password',
                  obscureText: !_isNewPasswordVisible,
                  onToggleVisibility: () {
                    setState(
                      () => _isNewPasswordVisible = !_isNewPasswordVisible,
                    );
                  },
                  isPasswordVisible: _isNewPasswordVisible,
                ),
                const SizedBox(height: 20),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  hintText: 'Confirm New Password',
                  obscureText: !_isConfirmPasswordVisible,
                  onToggleVisibility: () {
                    setState(
                      () =>
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible,
                    );
                  },
                  isPasswordVisible: _isConfirmPasswordVisible,
                ),
                const SizedBox(height: 10),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 20),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                      onPressed: _updatePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 190, 166, 7),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 50,
                          vertical: 15,
                        ),
                        textStyle: const TextStyle(fontSize: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text('Update Password'),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
