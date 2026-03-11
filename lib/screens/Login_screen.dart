import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_providers.dart';
import '../services/translator_service.dart';
import '../services/auth_service.dart';
import '../utils/translated_text.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  final bool sessionExpired;
  const LoginScreen({super.key, this.sessionExpired = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  // Credentials
  static const _validUser = 'admin';
  static const _validPass = 'Wings@123';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  // ── Language change ────────────────────────────────────────────────────────
  Future<void> _onLanguageChanged(String? code) async {
    if (code == null) return;
    await context.read<SettingsProvider>().onLanguageChanged(code);
    if (mounted) setState(() {});
  }

  // ── Login ──────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter username and password');
      return;
    }

    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 800));

    if (user == _validUser && pass == _validPass) {
      await AuthService.saveLogin(); // ← Save login timestamp
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainShell()),
        );
      }
    } else {
      setState(() { _loading = false; _error = 'Invalid username or password'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final size = MediaQuery.of(context).size;
    final theme = AppTimeTheme.forHour(DateTime.now().hour);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image ───────────────────────────────────────────────
          Image.asset(
            'assets/icon/sky_bg.jpg',
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),

          // ── Dark overlay ────────────────────────────────────────────────────
          Container(color: Colors.black.withOpacity(0.12)),

          // ── Content ─────────────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.07,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),

                    // ── App logo / title ───────────────────────────────────
                    _buildHeader(size),

                    const SizedBox(height: 28),

                    // ── Language selector (ABOVE login card) ───────────────
                    _buildLanguageSelector(settings.languageCode),

                    const SizedBox(height: 20),

                    // ── Session expired banner ─────────────────────────────
                    if (widget.sessionExpired) _buildExpiredBanner(),

                    if (widget.sessionExpired) const SizedBox(height: 14),

                    // ── Login card ─────────────────────────────────────────
                    _buildLoginCard(theme),

                    const SizedBox(height: 24),

                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Session Expired Banner ─────────────────────────────────────────────────
  Widget _buildExpiredBanner() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.4)),
          ),
          child: Row(
            children: const [
              Icon(Icons.timer_off_outlined, color: Colors.orange, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your session has expired. Please log in again.',
                  style: TextStyle(color: Colors.orange, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(Size size) {
    final logoSize = size.width * 0.24;
    return Column(
      children: [
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/icon/App_Icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'WINGS App',
          style: TextStyle(
            fontSize: 28, fontWeight: FontWeight.bold,
            color: Colors.white, letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Weather Information Guidance System',
          style: TextStyle(fontSize: 13, color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        const Text(
          'NCMRWF',
          style: TextStyle(fontSize: 11, color: Colors.white54, letterSpacing: 3),
        ),
      ],
    );
  }

  // ── Language Selector ──────────────────────────────────────────────────────
  Widget _buildLanguageSelector(String currentCode) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white30),
          ),
          child: Row(
            children: [
              const Icon(Icons.language, color: Colors.white70, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: currentCode,
                    dropdownColor: const Color(0xFF0D1B2A),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    iconEnabledColor: Colors.white70,
                    isExpanded: true,
                    items: TranslatorService.supportedLanguages.map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang['code'],
                        child: Text(
                          '${lang['native']}  (${lang['name']})',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14),
                        ),
                      );
                    }).toList(),
                    onChanged: _onLanguageChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Login Card ─────────────────────────────────────────────────────────────
  Widget _buildLoginCard(AppTimeTheme theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white30),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TranslatedText(
                'Sign In',
                style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                controller: _userCtrl,
                label: 'Username',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 14),

              _buildTextField(
                controller: _passCtrl,
                label: 'Password',
                icon: Icons.lock_outline,
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.white60, size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 20),

              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.accent.withOpacity(0.85),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _loading
                      ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                      : TranslatedText(
                    'Login',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: Icon(icon, color: Colors.white60, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    return Column(
      children: const [
        Text(
          'Ministry of Earth Sciences',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        SizedBox(height: 2),
        Text(
          'Government of India',
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      ],
    );
  }
}