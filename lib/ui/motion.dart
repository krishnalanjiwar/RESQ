import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Interface sounds and haptics. Sounds are a nicety: a phone without audio
/// (or a widget test) silently skips them.
abstract final class Sfx {
  static const MethodChannel _channel = MethodChannel('resq/alerts');

  /// Light tick for ordinary taps (follows the system "touch sounds" setting).
  static void tap() {
    unawaited(HapticFeedback.selectionClick());
    unawaited(SystemSound.play(SystemSoundType.click).catchError((Object _) {}));
  }

  /// Something worked: saved, accepted.
  static void success() {
    unawaited(HapticFeedback.mediumImpact());
    _tone('success');
  }

  /// An SOS left this phone.
  static void send() {
    unawaited(HapticFeedback.heavyImpact());
    _tone('send');
  }

  /// Declined, cancelled or blocked.
  static void warn() {
    unawaited(HapticFeedback.vibrate());
    _tone('warn');
  }

  static void _tone(String kind) {
    unawaited(_channel.invokeMethod<bool>('tone', {'kind': kind}).then<void>((_) {}, onError: (Object _) {}));
  }
}

/// Shrinks its child slightly while pressed: tactile feedback for cards and
/// big buttons. The child keeps its own ripple and tap handling.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}

/// Fades and slides its child in once, after [index] × a short stagger, so
/// lists settle into place instead of popping.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  static const int _stepMs = 45;
  static const int _runMs = 360;

  late final int _delayMs = (widget.index.clamp(0, 8)) * _stepMs;
  late final AnimationController _c =
      AnimationController(vsync: this, duration: Duration(milliseconds: _delayMs + _runMs));
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Interval(_delayMs / (_delayMs + _runMs), 1, curve: Curves.easeOutCubic));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.value = 1;
    } else if (_c.status == AnimationStatus.dismissed) {
      unawaited(_c.forward());
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _t,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(_t),
          child: widget.child,
        ),
      );
}

/// Soft pulsing glow around an urgent card (a ringing offer).
class PulseGlow extends StatefulWidget {
  const PulseGlow({super.key, required this.child, required this.color, this.active = true, this.radius = 20});

  final Widget child;
  final Color color;
  final bool active;
  final double radius;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PulseGlow old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final run = widget.active && !MediaQuery.of(context).disableAnimations;
    if (run && !_c.isAnimating) {
      unawaited(_c.repeat(reverse: true));
    } else if (!run && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: widget.active
                ? [BoxShadow(color: widget.color.withValues(alpha: 0.15 + 0.3 * _c.value), blurRadius: 6 + 14 * _c.value, spreadRadius: 1 + 2 * _c.value)]
                : const [],
          ),
          child: child,
        ),
        child: widget.child,
      );
}
