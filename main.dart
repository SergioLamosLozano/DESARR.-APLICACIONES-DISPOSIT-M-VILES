import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Adivina el Número',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

// TickerProviderStateMixin (no Single) porque usamos 2 AnimationControllers
class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  // ── Estado del juego ────────────────────────────────────────────────────────
  late int _numeroSecreto;
  int _intentos = 0;
  int _intentosRestantes = 7;
  int _intentosMaximos = 7;
  String _mensaje = '';
  final TextEditingController _controller = TextEditingController();
  bool _juegoTerminado = false;
  bool _juegoPerdido = false;
  bool _pistaDada = false;

  // ── Modo difícil ─────────────────────────────────────────────────────────────
  bool _modoDificil = false;

  // ── Historial de intentos [{valor, tipo: 'alto'|'bajo'|'correcto'|'pista'}]
  final List<Map<String, dynamic>> _historial = [];

  // ── Récord (SharedPreferences) ───────────────────────────────────────────────
  int _mejorPuntaje = 0; // 0 = sin récord aún

  // ── Animaciones ──────────────────────────────────────────────────────────────
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // ── Mensajes de inicio ───────────────────────────────────────────────────────
  final List<String> _mensajesFacil = [
    '🚀 ¡Arranca tu mente! Tienes 7 intentos para lograrlo',
    '🎮 ¡Modo detective activado! 7 oportunidades nada más',
    '🧠 El número te espera... ¿Podrás adivinarlo en 7?',
    '🔥 ¡Desafío aceptado! 7 intentos para descubrirlo',
  ];

  final List<String> _mensajesDificil = [
    '💀 ¡Modo DIFÍCIL! 1-200, solo 4 intentos',
    '🧨 ¡Al límite! 4 oportunidades, número entre 1 y 200',
    '😈 ¿Te atreves? 4 intentos para un número entre 1 y 200',
  ];

  // ── Ciclo de vida ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Animación de entrada (fade + slide)
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Animación de rebote para victoria
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bounceAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 30),
          TweenSequenceItem(tween: Tween(begin: 1.5, end: 0.85), weight: 25),
          TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.15), weight: 25),
          TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 20),
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
        );

    _cargarMejorPuntaje();
    _iniciarJuego();
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  // ── SharedPreferences: cargar y guardar récord ──────────────────────────────
  Future<void> _cargarMejorPuntaje() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mejorPuntaje = prefs.getInt('mejor_puntaje') ?? 0;
    });
  }

  Future<void> _guardarMejorPuntaje(int intentos) async {
    if (_mejorPuntaje == 0 || intentos < _mejorPuntaje) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('mejor_puntaje', intentos);
      setState(() => _mejorPuntaje = intentos);
    }
  }

  // ── Lógica del juego ──────────────────────────────────────────────────────────
  void _iniciarJuego() {
    final int maxNum = _modoDificil ? 200 : 50;
    final int maxIntentos = _modoDificil ? 4 : 7;
    final mensajes = _modoDificil ? _mensajesDificil : _mensajesFacil;

    _historial.clear();
    setState(() {
      _numeroSecreto = Random().nextInt(maxNum) + 1;
      _intentos = 0;
      _intentosRestantes = maxIntentos;
      _intentosMaximos = maxIntentos;
      _mensaje = mensajes[Random().nextInt(mensajes.length)];
      _juegoTerminado = false;
      _juegoPerdido = false;
      _pistaDada = false;
      _controller.clear();
    });

    _bounceController.reset();
    _animationController.reset();
    _animationController.forward();
  }

  void _darPista() {
    if (_juegoTerminado || _juegoPerdido || _pistaDada) return;
    if (_intentosRestantes <= 1) {
      _mostrarMensajeTemporal(
        '⚠️ ¡Necesitas al menos 2 intentos para pedir pista!',
        Colors.red,
      );
      return;
    }

    final bool esPar = _numeroSecreto % 2 == 0;

    setState(() {
      _pistaDada = true;
      _intentosRestantes--;
      _intentos++;
      _historial.add({'tipo': 'pista', 'detalle': esPar ? 'PAR' : 'IMPAR'});
    });

    _mostrarMensajeTemporal(
      '💡 El número es ${esPar ? "PAR ✅" : "IMPAR ✅"}  (−1 intento)',
      Colors.purple,
    );
  }

  void _verificarAdivinanza() {
    if (_juegoTerminado || _juegoPerdido) return;

    final String texto = _controller.text.trim();
    if (texto.isEmpty) {
      _mostrarMensajeTemporal('📝 ¡Ingresa un número!', Colors.orange);
      return;
    }

    final int maxNum = _modoDificil ? 200 : 50;
    final int? adivinanza = int.tryParse(texto);
    if (adivinanza == null || adivinanza < 1 || adivinanza > maxNum) {
      _mostrarMensajeTemporal(
        '⚠️ Solo números entre 1 y $maxNum',
        Colors.orange,
      );
      return;
    }

    setState(() {
      _intentos++;
      _intentosRestantes--;
      _controller.clear();

      if (adivinanza == _numeroSecreto) {
        _mensaje =
            '🔥 ¡INCREÍBLE! 🔥\nLo lograste en $_intentos ${_intentos == 1 ? 'intento' : 'intentos'}';
        _juegoTerminado = true;
        _historial.add({'valor': adivinanza, 'tipo': 'correcto'});
        _guardarMejorPuntaje(_intentos);
        _bounceController.forward();
      } else if (_intentosRestantes == 0) {
        _mensaje = '😓 ¡GAME OVER! 😓\nEl número secreto era $_numeroSecreto';
        _juegoPerdido = true;
        _historial.add({
          'valor': adivinanza,
          'tipo': adivinanza < _numeroSecreto ? 'bajo' : 'alto',
        });
      } else if (adivinanza < _numeroSecreto) {
        _mensaje =
            '🔺 ¡Apunta más alto! (Te quedan $_intentosRestantes intentos)';
        _historial.add({'valor': adivinanza, 'tipo': 'bajo'});
      } else {
        _mensaje = '🔻 ¡Baja un poco! (Te quedan $_intentosRestantes intentos)';
        _historial.add({'valor': adivinanza, 'tipo': 'alto'});
      }
    });

    _animationController.reset();
    _animationController.forward();
  }

  void _mostrarMensajeTemporal(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Helpers de color ───────────────────────────────────────────────────────
  Color _getMensajeColor() {
    if (_juegoTerminado) return Colors.green;
    if (_juegoPerdido) return Colors.red;
    if (_mensaje.contains('alto')) return Colors.blue;
    if (_mensaje.contains('bajo')) return Colors.red;
    return Colors.deepOrange;
  }

  /// Verde > 50 % · Naranja 26–50 % · Rojo ≤ 25 %
  Color _getProgressColor() {
    final double ratio = _intentosMaximos > 0
        ? _intentosRestantes / _intentosMaximos
        : 0;
    if (ratio > 0.5) return Colors.green;
    if (ratio > 0.25) return Colors.orange;
    return Colors.red;
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final int maxNum = _modoDificil ? 200 : 50;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepOrange.shade50,
              Colors.white,
              Colors.deepOrange.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Fila superior: Récord + Switch de modo ─────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Récord
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.emoji_events,
                                  color: Colors.amber,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _mejorPuntaje == 0
                                      ? 'Sin récord'
                                      : '🏅 Récord: $_mejorPuntaje',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Switch modo fácil / difícil
                          Row(
                            children: [
                              Text(
                                _modoDificil ? '💀 Difícil' : '😊 Fácil',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _modoDificil
                                      ? Colors.red
                                      : Colors.green,
                                ),
                              ),
                              Switch(
                                value: _modoDificil,
                                activeColor: Colors.red,
                                inactiveThumbColor: Colors.green,
                                onChanged: (val) {
                                  setState(() => _modoDificil = val);
                                  _iniciarJuego();
                                },
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // ── Ícono animado (header) ──────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.withOpacity(0.2),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: _juegoTerminado
                            // Rebote al ganar
                            ? ScaleTransition(
                                scale: _bounceAnimation,
                                child: const Icon(
                                  Icons.emoji_events,
                                  size: 60,
                                  color: Colors.amber,
                                ),
                              )
                            // Rotación normal durante el juego
                            : TweenAnimationBuilder(
                                duration: const Duration(seconds: 2),
                                tween: Tween<double>(begin: 0, end: 2 * pi),
                                builder: (context, double value, child) {
                                  return Transform.rotate(
                                    angle: value,
                                    child: child,
                                  );
                                },
                                child: Icon(
                                  _juegoPerdido
                                      ? Icons.sentiment_dissatisfied
                                      : Icons.psychology_alt,
                                  size: 60,
                                  color: _juegoPerdido
                                      ? Colors.red
                                      : Colors.deepOrange,
                                ),
                              ),
                      ),

                      const SizedBox(height: 20),

                      // ── Mensaje principal con AnimatedContainer ─────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _getMensajeColor().withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Text(
                          _mensaje,
                          style: TextStyle(
                            fontSize: _juegoTerminado ? 24 : 20,
                            fontWeight: FontWeight.w600,
                            color: _getMensajeColor(),
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── LinearProgressIndicator de intentos ─────────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Intentos: $_intentosRestantes / $_intentosMaximos',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: _getProgressColor(),
                                ),
                              ),
                              Icon(
                                _intentosRestantes <= 1
                                    ? Icons.warning_amber_rounded
                                    : Icons.hourglass_bottom,
                                color: _getProgressColor(),
                                size: 16,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: _intentosMaximos > 0
                                  ? _intentosRestantes / _intentosMaximos
                                  : 0,
                              minHeight: 12,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _getProgressColor(),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ── Historial de intentos ───────────────────────────────
                      if (_historial.isNotEmpty)
                        Container(
                          constraints: const BoxConstraints(maxHeight: 130),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '📋 Historial',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Expanded(
                                child: ListView.builder(
                                  reverse: true,
                                  itemCount: _historial.length,
                                  itemBuilder: (context, index) {
                                    final item =
                                        _historial[_historial.length -
                                            1 -
                                            index];
                                    final String tipo = item['tipo'];

                                    Color color;
                                    String label;
                                    IconData icon;

                                    switch (tipo) {
                                      case 'correcto':
                                        color = Colors.green;
                                        label =
                                            '✅ ${item['valor']} — ¡Correcto!';
                                        icon = Icons.check_circle;
                                        break;
                                      case 'alto':
                                        color = Colors.red;
                                        label =
                                            '🔻 ${item['valor']} — Muy alto';
                                        icon = Icons.arrow_downward;
                                        break;
                                      case 'bajo':
                                        color = Colors.blue;
                                        label =
                                            '🔺 ${item['valor']} — Muy bajo';
                                        icon = Icons.arrow_upward;
                                        break;
                                      default: // pista
                                        color = Colors.purple;
                                        label =
                                            '💡 Pista: número ${item['detalle']}';
                                        icon = Icons.lightbulb;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Row(
                                        children: [
                                          Icon(icon, size: 14, color: color),
                                          const SizedBox(width: 6),
                                          Text(
                                            label,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 14),

                      // ── Campo de texto ──────────────────────────────────────
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _controller,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          enabled: !_juegoTerminado && !_juegoPerdido,
                          style: const TextStyle(fontSize: 18),
                          decoration: InputDecoration(
                            hintText: 'Número entre 1 y $maxNum',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(
                              Icons.casino,
                              color: Colors.deepOrange,
                            ),
                            suffixIcon: _controller.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () => _controller.clear(),
                                  )
                                : null,
                          ),
                          onSubmitted: (_) => _verificarAdivinanza(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Botones: Adivinar + Pista ───────────────────────────
                      Row(
                        children: [
                          // Botón principal "Adivinar"
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 55,
                              child: ElevatedButton(
                                onPressed: (_juegoTerminado || _juegoPerdido)
                                    ? null
                                    : _verificarAdivinanza,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _juegoTerminado
                                      ? Colors.green
                                      : (_juegoPerdido
                                            ? Colors.red
                                            : Colors.deepOrange),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: _juegoTerminado
                                      ? Colors.green.shade100
                                      : (_juegoPerdido
                                            ? Colors.red.shade100
                                            : Colors.deepOrange.shade100),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 5,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _juegoTerminado
                                          ? Icons.emoji_events
                                          : (_juegoPerdido
                                                ? Icons
                                                      .sentiment_very_dissatisfied
                                                : Icons.check_circle_outline),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _juegoTerminado
                                          ? '¡Ganaste!'
                                          : (_juegoPerdido
                                                ? 'Perdiste'
                                                : 'Adivinar'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          // Botón "💡 Pista"
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 55,
                              child: OutlinedButton.icon(
                                onPressed:
                                    (_juegoTerminado ||
                                        _juegoPerdido ||
                                        _pistaDada)
                                    ? null
                                    : _darPista,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.purple,
                                  disabledForegroundColor: Colors.grey,
                                  side: BorderSide(
                                    color:
                                        (_juegoTerminado ||
                                            _juegoPerdido ||
                                            _pistaDada)
                                        ? Colors.grey.shade300
                                        : Colors.purple,
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(Icons.lightbulb_outline),
                                label: Text(
                                  _pistaDada ? 'Usada' : 'Pista',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ── Botón "Jugar de nuevo" (solo visible al terminar) ───
                      if (_juegoTerminado || _juegoPerdido)
                        TweenAnimationBuilder(
                          duration: const Duration(milliseconds: 500),
                          tween: Tween<double>(begin: 0, end: 1),
                          builder: (context, double value, child) {
                            return Transform.scale(scale: value, child: child);
                          },
                          child: OutlinedButton.icon(
                            onPressed: _iniciarJuego,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepOrange,
                              side: const BorderSide(
                                color: Colors.deepOrange,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 15,
                              ),
                            ),
                            icon: const Icon(Icons.replay),
                            label: const Text(
                              'Jugar de nuevo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
