import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Holographic Widget Cards - Beautiful, lazy-loaded response cards
/// Performance optimized with RepaintBoundary and const constructors

// ============================================================================
// BASE HOLOGRAPHIC CARD - Reusable glassmorphic container
// ============================================================================

class HolographicCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final Color accentColor;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  const HolographicCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.accentColor = Colors.cyan,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              width: width,
              height: height,
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accentColor.withOpacity(0.15),
                    Colors.black.withOpacity(0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: accentColor.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: -5,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// WEATHER CARD - Animated weather display
// ============================================================================

class WeatherHoloCard extends StatelessWidget {
  final String temperature;
  final String condition;
  final String location;
  final String? feelsLike;
  final String? humidity;
  final String? wind;

  const WeatherHoloCard({
    super.key,
    required this.temperature,
    required this.condition,
    required this.location,
    this.feelsLike,
    this.humidity,
    this.wind,
  });

  // Lazy icon mapping
  IconData get _weatherIcon {
    final lower = condition.toLowerCase();
    if (lower.contains('sun') || lower.contains('clear')) return Icons.wb_sunny;
    if (lower.contains('cloud')) return Icons.cloud;
    if (lower.contains('rain')) return Icons.water_drop;
    if (lower.contains('storm') || lower.contains('thunder'))
      return Icons.thunderstorm;
    if (lower.contains('snow')) return Icons.ac_unit;
    if (lower.contains('fog') || lower.contains('mist')) return Icons.foggy;
    return Icons.thermostat;
  }

  Color get _accentColor {
    final lower = condition.toLowerCase();
    if (lower.contains('sun') || lower.contains('clear')) return Colors.orange;
    if (lower.contains('rain') || lower.contains('storm')) return Colors.blue;
    if (lower.contains('snow')) return Colors.lightBlue;
    return Colors.cyan;
  }

  @override
  Widget build(BuildContext context) {
    return HolographicCard(
      accentColor: _accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.location_on, size: 14, color: Colors.white54),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  location.toUpperCase(),
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Main temp display
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Animated icon
              RepaintBoundary(
                child: Icon(_weatherIcon, size: 48, color: _accentColor)
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 2000.ms,
                    ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      temperature,
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      condition,
                      style: GoogleFonts.inter(
                        color: _accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Extra details (lazy render only if provided)
          if (feelsLike != null || humidity != null || wind != null) ...[
            const SizedBox(height: 12),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (feelsLike != null)
                  _buildStat('FEELS', feelsLike!, Icons.thermostat_outlined),
                if (humidity != null)
                  _buildStat('HUMID', humidity!, Icons.water_drop_outlined),
                if (wind != null) _buildStat('WIND', wind!, Icons.air),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
        ),
        Text(
          label,
          style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 9),
        ),
      ],
    );
  }
}

// ============================================================================
// CALENDAR CARD - Today's events display
// ============================================================================

class CalendarEvent {
  final String title;
  final String time;
  final String? location;
  final Color color;

  const CalendarEvent({
    required this.title,
    required this.time,
    this.location,
    this.color = Colors.cyan,
  });
}

class CalendarHoloCard extends StatelessWidget {
  final String date;
  final List<CalendarEvent> events;

  const CalendarHoloCard({super.key, required this.date, required this.events});

  @override
  Widget build(BuildContext context) {
    return HolographicCard(
      accentColor: Colors.purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.purpleAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S AGENDA',
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white54,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      date,
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${events.length} EVENTS',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.purpleAccent,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          if (events.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Lazy list - only build visible items
            ...events.take(3).map((event) => _buildEventTile(event)),
            if (events.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '+${events.length - 3} more events',
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ),
          ] else
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'No events scheduled',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventTile(CalendarEvent event) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: event.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 11, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text(
                      event.time,
                      style: GoogleFonts.shareTechMono(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    if (event.location != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.location_on, size: 11, color: Colors.white38),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: GoogleFonts.shareTechMono(
                            color: Colors.white38,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// QUICK STATS CARD - Animated statistics display
// ============================================================================

class QuickStat {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double? progress; // 0.0 to 1.0 for progress bar

  const QuickStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color = Colors.cyan,
    this.progress,
  });
}

class QuickStatsHoloCard extends StatelessWidget {
  final String title;
  final List<QuickStat> stats;

  const QuickStatsHoloCard({
    super.key,
    required this.title,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return HolographicCard(
      accentColor: Colors.teal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 18,
                color: Colors.tealAccent,
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: GoogleFonts.shareTechMono(
                  color: Colors.tealAccent,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats grid - lazy build
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: stats.map((stat) => _buildStatItem(stat)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(QuickStat stat) {
    return RepaintBoundary(
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(stat.icon, size: 14, color: stat.color.withOpacity(0.8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    stat.label,
                    style: GoogleFonts.shareTechMono(
                      color: Colors.white54,
                      fontSize: 9,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stat.value,
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (stat.progress != null) ...[
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: stat.progress,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation(stat.color),
                  minHeight: 3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// NEWS CARD - Compact news display
// ============================================================================

class NewsItem {
  final String headline;
  final String source;
  final String? imageUrl;

  const NewsItem({required this.headline, required this.source, this.imageUrl});
}

class NewsHoloCard extends StatelessWidget {
  final List<NewsItem> items;

  const NewsHoloCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return HolographicCard(
      accentColor: Colors.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.newspaper,
                  size: 16,
                  color: Colors.amberAccent,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'TOP STORIES',
                style: GoogleFonts.shareTechMono(
                  color: Colors.amberAccent,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                    'LIVE',
                    style: GoogleFonts.shareTechMono(
                      color: Colors.redAccent,
                      fontSize: 10,
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(duration: 800.ms)
                  .then()
                  .fadeOut(duration: 800.ms),
            ],
          ),
          const SizedBox(height: 12),

          // News items - lazy render top 3
          ...items.take(3).toList().asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(bottom: entry.key < 2 ? 10 : 0),
              child: _buildNewsItem(entry.value, entry.key + 1),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNewsItem(NewsItem item, int index) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Text(
              '$index',
              style: GoogleFonts.orbitron(
                color: Colors.amberAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.headline,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                item.source,
                style: GoogleFonts.shareTechMono(
                  color: Colors.white38,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// NOTIFICATION/ALERT CARD
// ============================================================================

class AlertHoloCard extends StatelessWidget {
  final String title;
  final String message;
  final String type; // 'info', 'success', 'warning', 'error'
  final VoidCallback? onDismiss;

  const AlertHoloCard({
    super.key,
    required this.title,
    required this.message,
    this.type = 'info',
    this.onDismiss,
  });

  Color get _color {
    switch (type) {
      case 'success':
        return Colors.green;
      case 'warning':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData get _icon {
    switch (type) {
      case 'success':
        return Icons.check_circle;
      case 'warning':
        return Icons.warning_amber;
      case 'error':
        return Icons.error;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return HolographicCard(
      accentColor: _color,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon, size: 20, color: _color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, size: 16, color: Colors.white38),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
