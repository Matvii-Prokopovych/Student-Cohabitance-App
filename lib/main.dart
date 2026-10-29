import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  // Initialise Flutter bindings before asynchronous SDK setup.
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rinzthpwhkaipbirdsdv.supabase.co',
    publishableKey: 'sb_publishable_gscsSxJmL24XfgNlfmvMgQ_ZHQiBYb_',
  );

  runApp(const CohabitationApp());
}

// Reuse client after Supabase initialisation.
final supabase = Supabase.instance.client;

class CohabitationApp extends StatelessWidget {
  const CohabitationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sustainable Student Cohabitation',
      debugShowCheckedModeBanner: false,
      // Apply shared colours and input style for all screens.
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Keep same stream instance between widget rebuilds.
  late final Stream<AuthState> _authStream = supabase.auth.onAuthStateChange;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        // Auth events rebuild gate; current session selects screen.
        final session = supabase.auth.currentSession;

        return session == null
            ? const AuthScreen()
            : DashboardScreen(user: session.user);
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Form key runs validators; controllers hold current input values.
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _register = false;
  bool _loading = false;
  bool _hidePassword = true;
  String? _message;

  @override
  void dispose() {
    // Release controllers when authentication screen is removed.
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Stop request when any form field fails validation.
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      if (_register) {
        final response = await supabase.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          // Save name in Auth metadata, separate from profiles table.
          data: {'display_name': _name.text.trim()},
        );

        // Screen may be removed while registration request is running.
        if (!mounted) return;

        // Missing session indicates registration did not sign user in.
        if (response.session == null) {
          setState(() {
            _register = false;
            _message =
                'No active session. Disable Confirm email in Supabase for testing.';
          });
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      // Show server authentication errors and handle other failures separately.
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _message = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Unable to connect. Please try again.';
        });
      }
    } finally {
      // Restore form controls only while state is still mounted.
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8F6),
      body: Center(
        // Allow scrolling on small screens or when keyboard is open.
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.eco_outlined,
                        size: 48,
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sustainable Student\nCohabitation',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _register ? 'Create your account' : 'Welcome back',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Spread name field into children only for registration.
                      if (_register) ...[
                        TextFormField(
                          controller: _name,
                          enabled: !_loading,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Enter your name';
                            }
                            if (value.trim().length > 100) {
                              return 'Use no more than 100 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Require non-empty email only during prototype testing.
                      TextFormField(
                        controller: _email,
                        enabled: !_loading,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        enabled: !_loading,
                        // Toggle text visibility without changing stored password.
                        obscureText: _hidePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        onFieldSubmitted: (_) {
                          if (!_loading) _submit();
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _hidePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: () {
                              setState(() {
                                _hidePassword = !_hidePassword;
                              });
                            },
                            icon: Icon(
                              _hidePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password';
                          }
                          // New accounts require minimum eight characters locally.
                          if (_register && value.length < 8) {
                            return 'Use at least 8 characters';
                          }
                          return null;
                        },
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Text(_message!),
                      ],
                      const SizedBox(height: 24),
                      // Disable submit during request to prevent duplicate calls.
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_register ? 'Create account' : 'Sign in'),
                        ),
                      ),
                      // Switch form mode and reset validation state.
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () {
                                setState(() {
                                  _register = !_register;
                                  _message = null;
                                  _formKey.currentState?.reset();
                                });
                              },
                        child: Text(
                          _register
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account',
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
    );
  }
}

// Dashboard receives authenticated user from session gate.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({required this.user, super.key});

  final User user;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    // Block repeated sign-out calls until current request finishes.
    setState(() => _signingOut = true);

    try {
      await supabase.auth.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign out failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read registration name from metadata, with fallback for missing value.
    final name = widget.user.userMetadata?['display_name'] as String?;
    final greeting = name == null || name.trim().isEmpty
        ? 'student'
        : name.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your household'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          // Constrain content width and allow vertical scrolling.
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Hello, $greeting!',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text('Plan together. Shop smarter. Waste less.'),
              const SizedBox(height: 20),
              // Mark sample figures explicitly; no household query is used yet.
              const Card(
                color: Color(0xFFFFF3CD),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Demo dashboard — all meal, shopping and budget '
                    'figures below are sample data.',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const _DashboardCard(
                icon: Icons.restaurant_outlined,
                title: "Today's dinner",
                detail: 'Vegetable pasta · 4 servings',
              ),
              const _DashboardCard(
                icon: Icons.calendar_month_outlined,
                title: 'Weekly meal plan',
                detail: '5 of 7 dinners planned',
              ),
              const _DashboardCard(
                icon: Icons.shopping_cart_outlined,
                title: 'Shopping list',
                detail: '8 items remaining',
              ),
              // Budget values are static examples, not calculated expenditure.
              const _DashboardCard(
                icon: Icons.euro_outlined,
                title: 'Weekly budget',
                detail: '€52 estimated of €80 · €28 remaining',
              ),
              const _DashboardCard(
                icon: Icons.kitchen_outlined,
                title: 'Use soon',
                detail: 'Milk · expires in 2 days',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Reusable presentation widget for dashboard summary items.
class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: Colors.teal, size: 30),
        title: Text(title),
        subtitle: Text(detail),
      ),
    );
  }
}
