import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';

// ─── Model ──────────────────────────────────────────────────────────────────

class TutorialStep {
  final String emoji;
  final String title;
  final String description;
  final GlobalKey targetKey;
  final double spotlightPadding;

  const TutorialStep({
    required this.emoji,
    required this.title,
    required this.description,
    required this.targetKey,
    this.spotlightPadding = 10,
  });
}

// ─── Servis ─────────────────────────────────────────────────────────────────

class TutorialService {
  /// Uygulamadaki tüm tur anahtarları — "Tanıtım Turunu Sıfırla" bunları siler.
  static const allKeys = [
    'tutorial_home_v2',
    'tutorial_ingredients_v1',
    'tutorial_detail_v2',
    'tutorial_calendar_v1',
    'tutorial_profile_v1',
  ];

  static Future<bool> shouldShow(String key) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return false;

    // Turu gösterme hakkını ekrana eklemeden önce tüket. Kullanıcı tur
    // sırasında uygulamayı kapatsa bile her açılışta yeniden başlamaz.
    await prefs.setBool(key, true);
    return true;
  }

  static Future<void> markShown(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  /// Tüm turları sıfırla — ekranlar bir sonraki açılışta turu yeniden gösterir.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in allKeys) {
      await prefs.remove(k);
    }
  }
}

// ─── Overlay Widget ──────────────────────────────────────────────────────────

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final String storageKey;
  final VoidCallback onDone;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.storageKey,
    required this.onDone,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  int _step = 0;
  Rect? _spotlight;

  late final AnimationController _bounceCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _bounceAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(
      begin: 0,
      end: 8,
    ).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut));

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      value: 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) => _calcSpotlight());
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // Hedef widget'ın ekran koordinatlarını hesapla
  void _calcSpotlight() {
    if (_step >= widget.steps.length) return;
    final key = widget.steps[_step].targetKey;
    final ctx = key.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final pad = widget.steps[_step].spotlightPadding;
    if (mounted) {
      setState(() {
        _spotlight = Rect.fromLTWH(
          offset.dx - pad,
          offset.dy - pad,
          size.width + pad * 2,
          size.height + pad * 2,
        );
      });
    }
  }

  Future<void> _next() async {
    if (_step >= widget.steps.length - 1) {
      await _done();
      return;
    }
    await _fadeCtrl.reverse();
    if (!mounted) return;
    setState(() {
      _step++;
      _spotlight = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _calcSpotlight());
    _fadeCtrl.forward();
  }

  Future<void> _done() async {
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // Uyarlanabilir reklam ve alt gezinme çubuğu tooltip'i kapatmasın.
    final safeBottom = MediaQuery.of(context).padding.bottom + 196.0;
    final step = widget.steps[_step];
    final spotlight = _spotlight;

    // Tooltip kartı spotlight'ın altına mı üstüne mi gidecek?
    final bool cardBelow =
        spotlight == null || spotlight.top < size.height * 0.45;

    return FadeTransition(
      opacity: _fadeAnim,
      child: GestureDetector(
        // Yanlışlıkla arka plana tıklanmayı engelle
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // ── Karartma + spotlight deliği ──
            if (spotlight != null)
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, _) => CustomPaint(
                  size: size,
                  painter: _SpotlightPainter(
                    spotlight: spotlight,
                    pulse: _pulseAnim.value,
                  ),
                ),
              )
            else
              Container(color: Colors.black.withValues(alpha: 0.78)),

            // ── "Geç" butonu ──
            Positioned(
              top: MediaQuery.of(context).padding.top + 14,
              right: 16,
              child: GestureDetector(
                onTap: _done,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'Geç',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // ── Ok + Tooltip ──
            if (spotlight != null)
              _buildCallout(
                context,
                size,
                spotlight,
                step,
                cardBelow,
                safeBottom,
              ),

            // ── Adım göstergesi ──
            Positioned(
              bottom: safeBottom,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.steps.length, (i) {
                  final active = i == _step;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primary
                          : Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallout(
    BuildContext context,
    Size screenSize,
    Rect spotlight,
    TutorialStep step,
    bool cardBelow,
    double safeBottom,
  ) {
    const cardW = 296.0;
    const cardH = 148.0;
    const arrowSize = 36.0;
    const gap = 10.0;

    final cardLeft = ((screenSize.width - cardW) / 2).clamp(
      12.0,
      screenSize.width - cardW - 12,
    );

    double arrowTop;
    double cardTop;
    IconData arrowIcon;

    if (cardBelow) {
      // Spotlight üstte → ok aşağı → kart altta
      arrowTop = spotlight.bottom + gap;
      cardTop = arrowTop + arrowSize + gap;
      arrowIcon = Icons.arrow_downward_rounded;
    } else {
      // Spotlight altta → ok yukarı → kart üstte
      arrowTop = spotlight.top - gap - arrowSize;
      cardTop = arrowTop - gap - cardH;
      arrowIcon = Icons.arrow_upward_rounded;
    }

    // Ekran dışına taşmasın
    cardTop = cardTop.clamp(
      MediaQuery.of(context).padding.top + 60.0,
      screenSize.height - cardH - safeBottom,
    );

    return Stack(
      children: [
        // Animasyonlu ok
        AnimatedBuilder(
          animation: _bounceAnim,
          builder: (_, _) => Positioned(
            top:
                arrowTop + (cardBelow ? _bounceAnim.value : -_bounceAnim.value),
            left: spotlight.center.dx - arrowSize / 2,
            child: Container(
              width: arrowSize,
              height: arrowSize,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.5),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(arrowIcon, color: AppColors.primaryText, size: 20),
            ),
          ),
        ),

        // Tooltip kart
        Positioned(
          left: cardLeft,
          top: cardTop,
          width: cardW,
          child: _TooltipCard(
            step: step,
            stepIndex: _step,
            totalSteps: widget.steps.length,
            onNext: _next,
          ),
        ),
      ],
    );
  }
}

// ─── Tooltip Kartı ───────────────────────────────────────────────────────────

class _TooltipCard extends StatelessWidget {
  final TutorialStep step;
  final int stepIndex;
  final int totalSteps;
  final VoidCallback onNext;

  const _TooltipCard({
    required this.step,
    required this.stepIndex,
    required this.totalSteps,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = stepIndex == totalSteps - 1;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(step.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryDarker,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              step.description,
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.grey[600],
                height: 1.55,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                // Adım numarası
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${stepIndex + 1} / $totalSteps',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDarker,
                    ),
                  ),
                ),
                const Spacer(),
                // İleri / Başla butonu
                GestureDetector(
                  onTap: onNext,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLast ? 'Başla!' : 'İleri',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: AppColors.primaryText,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CustomPainter (spotlight deliği) ────────────────────────────────────────

class _SpotlightPainter extends CustomPainter {
  final Rect spotlight;
  final double pulse; // 0.0 → 1.0

  const _SpotlightPainter({required this.spotlight, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    // Karartma
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.78);
    final fullPath = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          spotlight.inflate(4),
          const Radius.circular(18),
        ),
      );
    canvas.drawPath(fullPath, bgPaint);

    // Pulse halkası
    final ringOpacity = (0.55 * (1 - pulse)).clamp(0.0, 1.0);
    final ringInflate = 4.0 + pulse * 14.0;
    final ringPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: ringOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        spotlight.inflate(ringInflate),
        const Radius.circular(20),
      ),
      ringPaint,
    );

    // Sabit yeşil kenarlık
    final borderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight.inflate(4), const Radius.circular(18)),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.spotlight != spotlight || old.pulse != pulse;
}
