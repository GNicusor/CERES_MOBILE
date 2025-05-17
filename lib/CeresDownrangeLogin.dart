import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'login_success_screen.dart';

class CeresDownrangeLogin extends StatefulWidget {
  @override
  _CeresDownrangeLoginState createState() => _CeresDownrangeLoginState();
}

class _CeresDownrangeLoginState extends State<CeresDownrangeLogin> {
  // Controllers for email & password
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  final String _errorMessage = "";

  Future<void> _loginUser() async {
    final url = Uri.parse("https://ubuntu1.vlahi.com/loginRest/login");


    final formBody =
        "username=${Uri.encodeComponent(_emailController.text)}"
        "&password=${Uri.encodeComponent(_passwordController.text)}"
        "&rememberMe=false";

    // maybe will work without cookies
    final headers = {
      "Content-Type": "application/x-www-form-urlencoded",
      "Accept": "application/json",
      "Ceres_client_type": "BROWSER",
      "X-Http-Method-Override": "POST",

    };

    try {
      final response = await http.post(url, headers: headers, body: formBody);

      print("Status code: ${response.statusCode}");
      print("Body: ${response.body}");

      if (response.statusCode == 200) {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LoginSuccessScreen()));
      } else {
        print("Still not working");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double boxWidth = screenSize.width * 0.85;
    final double boxHeight = screenSize.height * 0.75;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: boxWidth,
          height: boxHeight,
          padding: EdgeInsets.all(screenSize.width * 0.04),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.zero,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 10,
                offset: Offset(2, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/ceres_logo.png',
                width: screenSize.width * 0.15,
                height: screenSize.width * 0.15,
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                "Welcome to CERES !",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 5),

              const Text(
                "Chemical Emergency",
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const Text(
                "Response E-Service",
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Sign In Text
              const Text(
                "Sign In",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),

              // Email TextField
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),

              // Password TextField
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: "Password",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Sign In Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  onPressed: _loginUser,
                  child: const Text(
                    "Sign In",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

              // Show error message in red, if any
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage,
                  style: TextStyle(fontSize: 14, color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}