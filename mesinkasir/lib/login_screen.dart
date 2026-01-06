import 'package:flutter/material.dart';
import 'auth_store.dart';
import 'admin_home.dart';
import 'kasir_home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _loading = false;
  String? _error;

  late final AnimationController _animCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _animCtrl,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _animCtrl.forward();
  }

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String s) {
    // Simple & cukup aman untuk UI validation
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
  }

  Future<void> doLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final u = await AuthStore.login(
        email: emailCtrl.text.trim().toLowerCase(),
        password: passCtrl.text,
        deviceName: 'flutter',
      );

      if (!mounted) return;

      if (u == null) {
        setState(() {
          _loading = false;
          _error = 'Login gagal (email/password salah atau akun nonaktif)';
        });
        return;
      }

      final next = u.role == 'admin' ? const AdminHome() : const KasirHome();

      setState(() => _loading = false);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => next),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Gagal konek ke server';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.primaryContainer],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: _Blob(size: 220, color: Colors.white.withOpacity(0.12)),
          ),
          Positioned(
            bottom: -90,
            left: -70,
            child: _Blob(size: 260, color: Colors.white.withOpacity(0.10)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _HeaderCard(
                            title: 'Selamat Datang',
                            subtitle: 'Silakan login untuk melanjutkan',
                            icon: Icons.lock_rounded,
                          ),
                          const SizedBox(height: 16),
                          Material(
                            color: Colors.white,
                            elevation: 10,
                            shadowColor: Colors.black.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(18),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Login',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Masukkan email dan password kamu',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: Colors.black54,
                                          ),
                                    ),
                                    const SizedBox(height: 16),

                                    // EMAIL
                                    TextFormField(
                                      controller: emailCtrl,
                                      textInputAction: TextInputAction.next,
                                      keyboardType: TextInputType.emailAddress,
                                      autofillHints: const [AutofillHints.email],
                                      decoration: const InputDecoration(
                                        labelText: 'Email',
                                        hintText: 'contoh: budi@email.com',
                                        prefixIcon: Icon(Icons.email_rounded),
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) {
                                        final s = (v ?? '').trim();
                                        if (s.isEmpty) return 'Email wajib diisi';
                                        if (!_isValidEmail(s)) return 'Format email tidak valid';
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),

                                    // PASSWORD
                                    TextFormField(
                                      controller: passCtrl,
                                      textInputAction: TextInputAction.done,
                                      obscureText: _obscurePass,
                                      onFieldSubmitted: (_) => doLogin(),
                                      autofillHints: const [AutofillHints.password],
                                      decoration: InputDecoration(
                                        labelText: 'Password',
                                        hintText: '••••••••',
                                        prefixIcon: const Icon(Icons.lock_rounded),
                                        border: const OutlineInputBorder(),
                                        suffixIcon: IconButton(
                                          tooltip: _obscurePass ? 'Tampilkan' : 'Sembunyikan',
                                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                          icon: Icon(
                                            _obscurePass ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                          ),
                                        ),
                                      ),
                                      validator: (v) {
                                        final s = (v ?? '');
                                        if (s.trim().isEmpty) return 'Password wajib diisi';
                                        if (s.length < 6) return 'Password minimal 6 karakter';
                                        return null;
                                      },
                                    ),

                                    if (_error != null) ...[
                                      const SizedBox(height: 12),
                                      _ErrorBanner(text: _error!),
                                    ],
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      height: 48,
                                      child: ElevatedButton.icon(
                                        onPressed: _loading ? null : doLogin,
                                        icon: _loading
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Icon(Icons.login_rounded),
                                        label: Text(_loading ? 'Memproses...' : 'Masuk'),
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Tip: Pastikan email/password benar dan akun aktif.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Colors.black54,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '© ${DateTime.now().year} POS App',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withOpacity(0.85),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.16),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.22)),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withOpacity(0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_rounded, color: cs.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: cs.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double size;
  final Color color;
  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
