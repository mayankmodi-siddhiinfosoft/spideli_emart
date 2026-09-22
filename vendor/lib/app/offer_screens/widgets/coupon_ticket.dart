import 'package:flutter/material.dart';
import 'package:vendor/themes/ds/ds.dart';

/// Ticket-shaped surface: a coloured stub on the leading side, a perforated
/// divider with two half-circle notches, and the body on the trailing side.
/// Pure presentation, shared by the offer list and the offer form preview.
class CouponTicket extends StatelessWidget {
  final Widget stub;
  final Widget body;
  final double stubWidth;
  final Gradient? stubGradient;
  final EdgeInsetsGeometry bodyPadding;

  const CouponTicket({
    super.key,
    required this.stub,
    required this.body,
    this.stubWidth = 108,
    this.stubGradient,
    this.bodyPadding = const EdgeInsets.fromLTRB(DsSpace.lg, DsSpace.md, DsSpace.md, DsSpace.md),
  });

  static const double _notch = 11;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: DsRadius.brLg, boxShadow: DsShadows.sm(context)),
      child: CustomPaint(
        foregroundPainter: _TicketOutlinePainter(stubWidth: stubWidth, notch: _notch, rtl: rtl, border: c.border, dash: c.borderStrong),
        child: ClipPath(
          clipper: _TicketClipper(stubWidth: stubWidth, notch: _notch, rtl: rtl),
          child: ColoredBox(
            color: c.surface,
            child: Stack(
              children: [
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: stubWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: stubGradient ?? DsGradients.brand(context)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.md),
                      child: Center(
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(color: Colors.white),
                          child: IconTheme.merge(data: const IconThemeData(color: Colors.white), child: stub),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.only(start: stubWidth),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 116),
                    child: Padding(padding: bodyPadding, child: body),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Path _ticketPath(Size size, double stubWidth, double notch, bool rtl) {
  final x = rtl ? size.width - stubWidth : stubWidth;
  final r = DsRadius.lg;
  final outer = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(r)));
  final cuts = Path()
    ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: notch))
    ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: notch));
  return Path.combine(PathOperation.difference, outer, cuts);
}

class _TicketClipper extends CustomClipper<Path> {
  final double stubWidth;
  final double notch;
  final bool rtl;
  _TicketClipper({required this.stubWidth, required this.notch, required this.rtl});

  @override
  Path getClip(Size size) => _ticketPath(size, stubWidth, notch, rtl);

  @override
  bool shouldReclip(covariant _TicketClipper old) => old.stubWidth != stubWidth || old.notch != notch || old.rtl != rtl;
}

class _TicketOutlinePainter extends CustomPainter {
  final double stubWidth;
  final double notch;
  final bool rtl;
  final Color border;
  final Color dash;
  _TicketOutlinePainter({required this.stubWidth, required this.notch, required this.rtl, required this.border, required this.dash});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _ticketPath(size, stubWidth, notch, rtl),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = border,
    );
    // Perforation.
    final x = rtl ? size.width - stubWidth : stubWidth;
    final p = Paint()
      ..color = dash
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    double y = notch + 6;
    while (y < size.height - notch - 6) {
      canvas.drawLine(Offset(x, y), Offset(x, (y + 5).clamp(0, size.height - notch - 6)), p);
      y += 10;
    }
  }

  @override
  bool shouldRepaint(covariant _TicketOutlinePainter old) => old.border != border || old.dash != dash || old.stubWidth != stubWidth || old.rtl != rtl;
}

/// The discount headline inside the stub ("20 % Off").
class CouponStubLabel extends StatelessWidget {
  final String text;
  final IconData icon;
  const CouponStubLabel({super.key, required this.text, this.icon = Icons.local_offer_rounded});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: Colors.white.withValues(alpha: 0.9)),
        const DsGap(DsSpace.sm),
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: DsTypography.titleSm.copyWith(color: Colors.white, fontWeight: FontWeight.w700, height: 1.15),
        ),
      ],
    );
  }
}
