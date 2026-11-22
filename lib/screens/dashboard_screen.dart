import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/reading.dart';
import '../repositories/reading_repository.dart';
import '../services/notification_service.dart';

const Color _background = Color(0xFFFBF7F4);
const Color _surfaceWhite = Color(0xFFFFFFFF);
const Color _peachSoft = Color(0xFFF7EAE6);
const Color _pinkSoft = Color(0xFFFCE4E6);
const Color _borderSoft = Color(0xFFE8D8D3);
const Color _textDark = Color(0xFF261C1B);
const Color _textMuted = Color(0xFF685856);
const Color _maroon = Color(0xFF8B3A35);
const Color _accent = Color(0xFF9E4742);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReadingRepository _repository = ReadingRepository();

  int _activeTab = 0; // 0: Beranda, 1: Riwayat, 2: Laporan, 3: Pengaturan
  String _selectedNode = 'ESP32_001';
  String _historyDeviceFilter = 'ALL';
  String _historyStatusFilter = 'ALL';
  final int _historyLimit = 50;

  DateTimeRange? _reportDateRange;
  String _reportStatus = 'Semua';
  int _reportVisibleCount = 40;

  String? _lastNotifiedStatus;
  String? _lastNotifiedDevice;

  static const List<String> _tabTitles = [
    'Beranda',
    'Riwayat',
    'Laporan',
    'Pengaturan',
  ];

  String _normalizeNodeId(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? 'ESP32_001' : trimmed;
  }

  String _controlDocIdFor(String deviceId) {
    final upper = deviceId.trim().toUpperCase();
    if (upper.contains('002') || upper.endsWith('02')) {
      return 'esp32-lab-02';
    }
    return 'esp32-lab-01';
  }

  Color _conditionAccentColor(String statusUpper) {
    if (statusUpper == 'DANGER') return const Color(0xFFFF1744);
    if (statusUpper == 'WARNING') return const Color(0xFFFF9100);
    return const Color(0xFF00E676);
  }

  Color _conditionTextColor(String statusUpper) {
    if (statusUpper == 'DANGER') return const Color(0xFFC50000);
    if (statusUpper == 'WARNING') return const Color(0xFFC65102);
    return const Color(0xFF008744);
  }

  Color _conditionBannerBg(String statusUpper) {
    if (statusUpper == 'DANGER') return const Color(0xFFFCE8EB);
    if (statusUpper == 'WARNING') return const Color(0xFFFFF8E7);
    return const Color(0xFFE8F8F0);
  }

  String _conditionBannerMessage(Reading reading, String statusUpper) {
    if (statusUpper == 'DANGER') {
      return 'BAHAYA KEBAKARAN TERDETEKSI pada ${_normalizeNodeId(reading.deviceId)}! '
          'Suhu ${reading.temperature.toStringAsFixed(1)}°C, Asap ${reading.smoke.toStringAsFixed(0)} ppm. '
          'Segera periksa ruangan & ambil tindakan darurat.';
    }
    if (statusUpper == 'WARNING') {
      return 'Peringatan dini pada ${_normalizeNodeId(reading.deviceId)}: '
          'Suhu ${reading.temperature.toStringAsFixed(1)}°C, Kelembapan ${reading.humidity.toStringAsFixed(1)}%, '
          'Asap ${reading.smoke.toStringAsFixed(0)} ppm.';
    }
    return 'Kondisi laboratorium aman dan terkendali. Tidak terdeteksi lonjakan asap atau suhu kritis.';
  }

  Future<void> _sendAlarmCommand(String deviceId, bool nextEnabled) async {
    final docRef = FirebaseFirestore.instance
        .collection('alarm-control')
        .doc(_controlDocIdFor(deviceId));
    try {
      await docRef.set({
        'alarmEnabled': nextEnabled,
        'commandStatus': 'pending',
        'commandUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextEnabled
                ? 'Perintah mengaktifkan buzzer dikirim ke $deviceId.'
                : 'Perintah mematikan buzzer dikirim ke $deviceId.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim perintah alarm: $e')),
      );
    }
  }

  Future<void> _showMuteConfirmationDialog(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Matikan Buzzer Alarm Lokal?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _textDark,
          ),
        ),
        content: Text(
          'Membungkam buzzer hanya mematikan suara lokal pada $deviceId. '
          'Pemantauan sensor dan status bahaya tetap aktif.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: _textMuted, height: 1.45),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: OutlinedButton.styleFrom(
              foregroundColor: _textDark,
              side: const BorderSide(color: _borderSoft),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('← Kembali'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD50000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ya, Matikan'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _sendAlarmCommand(deviceId, false);
    }
  }

  void _openDetailSheet(String type, Reading reading, Map<String, Reading> latestByDevice) {
    final deviceId = _normalizeNodeId(reading.deviceId);
    final statusUpper = reading.status.toUpperCase();
    final statusColor = _conditionTextColor(statusUpper);

    Widget content;
    if (type == 'temp') {
      content = _sheetMetricBox(
        title: '🌡️ Detail Temperature (DHT22) • $deviceId',
        label: 'Pembacaan Saat Ini',
        value: '${reading.temperature.toStringAsFixed(1)} °C',
        valueColor: _textDark,
        extra: 'Status: ${_statusLabel(statusUpper)} • Update: ${_formatDateTime(reading.timestamp)}',
      );
    } else if (type == 'hum') {
      content = _sheetMetricBox(
        title: '💧 Detail Humidity (DHT22) • $deviceId',
        label: 'Kelembapan Relatif',
        value: '${reading.humidity.toStringAsFixed(1)} %',
        valueColor: const Color(0xFF0369A1),
        extra: 'Status: ${_statusLabel(statusUpper)} • Update: ${_formatDateTime(reading.timestamp)}',
      );
    } else if (type == 'smoke') {
      content = _sheetMetricBox(
        title: '💨 Detail MQ-2 Smoke • $deviceId',
        label: 'Konsentrasi Smoke',
        value: '${reading.smoke.toStringAsFixed(0)} ppm',
        valueColor: const Color(0xFFC65102),
        extra: 'Status: ${_statusLabel(statusUpper)} • Update: ${_formatDateTime(reading.timestamp)}',
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '📡 Informasi Node $deviceId',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderSoft),
            ),
            child: Column(
              children: [
                _infoRow('Perangkat Aktif', deviceId),
                const SizedBox(height: 8),
                _infoRow('Dokumen Kontrol', 'alarm-control/${_controlDocIdFor(deviceId)}'),
                const SizedBox(height: 8),
                _infoRow('Total Node Terdeteksi', '${latestByDevice.length} perangkat'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status Terakhir', style: TextStyle(fontSize: 12, color: _textMuted)),
                    Text(
                      _statusLabel(statusUpper),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: statusColor),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _infoRow('Waktu Pembaruan', _formatDateTime(reading.timestamp)),
              ],
            ),
          ),
        ],
      );
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: _maroon),
                    label: const Text(
                      'Kembali',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _maroon),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _borderSoft,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const Text(
                    'Detail',
                    style: TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              content,
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _background,
                    foregroundColor: _textDark,
                    side: const BorderSide(color: _borderSoft),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    '← Kembali ke Layar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAlertsSheet(List<Reading> readings) {
    final alerts = readings
        .where((r) => r.status.toUpperCase() == 'DANGER' || r.status.toUpperCase() == 'WARNING')
        .take(8)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Log Notifikasi Peringatan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close_rounded, color: _textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (alerts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Belum ada notifikasi Warning atau Danger tercatat.',
                    style: TextStyle(fontSize: 12, color: _textDark),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = alerts[index];
                      final st = item.status.toUpperCase();
                      final col = _conditionTextColor(st);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _conditionBannerBg(st),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: col.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$st • ${_normalizeNodeId(item.deviceId)} (${_formatDateTime(item.timestamp)})',
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: col),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Suhu ${item.temperature.toStringAsFixed(1)}°C • Kelembapan ${item.humidity.toStringAsFixed(1)}% • Asap ${item.smoke.toStringAsFixed(0)} ppm',
                              style: const TextStyle(fontSize: 12, color: _textDark),
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
      ),
    );
  }

  Future<void> _pickReportDateRange() async {
    final now = DateTime.now();
    final initialStart = _reportDateRange?.start ?? DateTime(now.year, now.month, now.day);
    DateTime visibleMonth = DateTime(initialStart.year, initialStart.month);
    DateTime? start = _reportDateRange?.start;
    DateTime? end = _reportDateRange?.end;

    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
          final daysInMonth = DateUtils.getDaysInMonth(visibleMonth.year, visibleMonth.month);
          final leading = firstDay.weekday % 7;
          final cells = ((leading + daysInMonth + 6) ~/ 7) * 7;
          String format(DateTime d) => '${d.day}/${d.month}/${d.year}';
          bool sameDay(DateTime? a, DateTime b) =>
              a != null && a.year == b.year && a.month == b.month && a.day == b.day;
          bool inRange(DateTime d) =>
              start != null &&
              end != null &&
              !d.isBefore(DateUtils.dateOnly(start!)) &&
              !d.isAfter(DateUtils.dateOnly(end!));

          return Dialog(
            backgroundColor: _surfaceWhite,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Pilih periode laporan',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => setDialogState(
                            () => visibleMonth = DateTime(visibleMonth.year, visibleMonth.month - 1),
                          ),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_monthName(visibleMonth.month)} ${visibleMonth.year}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textDark),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setDialogState(
                            () => visibleMonth = DateTime(visibleMonth.year, visibleMonth.month + 1),
                          ),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
                          .map((d) => Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: const TextStyle(fontSize: 10, color: _textMuted, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cells,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 3,
                        crossAxisSpacing: 3,
                      ),
                      itemBuilder: (context, index) {
                        final day = index - leading + 1;
                        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
                        final date = DateTime(visibleMonth.year, visibleMonth.month, day);
                        final selected = sameDay(start, date) || sameDay(end, date);
                        final range = inRange(date);
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => setDialogState(() {
                            if (start == null || end != null || date.isBefore(start!)) {
                              start = date;
                              end = null;
                            } else {
                              end = date;
                            }
                          }),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? _accent
                                  : range
                                      ? _peachSoft
                                      : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? Colors.white : _textDark,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        start == null
                            ? 'Pilih tanggal mulai'
                            : end == null
                                ? 'Mulai: ${format(start!)} · Pilih tanggal akhir'
                                : '${format(start!)} – ${format(end!)}',
                        style: const TextStyle(fontSize: 11, color: _textMuted),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text('Batal'),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: start != null && end != null
                              ? () => Navigator.pop(
                                    dialogContext,
                                    DateTimeRange(
                                      start: DateUtils.dateOnly(start!),
                                      end: DateUtils.dateOnly(end!),
                                    ),
                                  )
                              : null,
                          style: FilledButton.styleFrom(backgroundColor: _accent),
                          child: const Text('Terapkan'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _reportDateRange = picked;
        _reportVisibleCount = 40;
      });
    }
  }

  String _monthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 820;

    return Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          _buildTopHeader(isWide),
          Expanded(
            child: StreamBuilder<List<Reading>>(
              stream: _repository.getReadings(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _accent));
                }
                if (snapshot.hasError) {
                  return _emptyState(
                    'Data tidak dapat dibaca',
                    'Periksa koneksi internet dan pengaturan Firebase.\n${snapshot.error}',
                  );
                }

                final readings = snapshot.data ?? [];
                if (readings.isEmpty) {
                  if (_activeTab == 2) {
                    return _scrollableCentered(
                      isWide: isWide,
                      child: _buildReportTab(readings),
                    );
                  }
                  if (_activeTab == 3) {
                    return _scrollableCentered(
                      isWide: isWide,
                      child: _buildSettingsTab(),
                    );
                  }
                  return _emptyState(
                    'Belum ada data sensor',
                    'Data dari koleksi fire-activity akan tampil di halaman ini.',
                  );
                }

                final latestByDevice = <String, Reading>{};
                for (final r in readings) {
                  final id = _normalizeNodeId(r.deviceId);
                  final prev = latestByDevice[id];
                  if (prev == null || r.timestamp.isAfter(prev.timestamp)) {
                    latestByDevice[id] = r;
                  }
                }

                final sortedNodeIds = latestByDevice.keys.toList()..sort();
                final activeNodeId = sortedNodeIds.contains(_selectedNode)
                    ? _selectedNode
                    : sortedNodeIds.first;
                final activeReading = latestByDevice[activeNodeId] ?? readings.first;

                final latestOverall = readings.first;
                final latestStatusLower = latestOverall.status.toLowerCase();
                if (latestStatusLower == 'warning' || latestStatusLower == 'danger') {
                  if (_lastNotifiedStatus != latestOverall.status ||
                      _lastNotifiedDevice != latestOverall.deviceId) {
                    _lastNotifiedStatus = latestOverall.status;
                    _lastNotifiedDevice = latestOverall.deviceId;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      NotificationService.showStatusNotification(
                        status: latestOverall.status,
                        temperature: latestOverall.temperature,
                        smoke: latestOverall.smoke,
                      );
                    });
                  }
                } else {
                  _lastNotifiedStatus = null;
                  _lastNotifiedDevice = null;
                }

                Widget tabBody;
                if (_activeTab == 1) {
                  tabBody = _buildHistoryTab(readings, sortedNodeIds);
                } else if (_activeTab == 2) {
                  tabBody = _buildReportTab(readings);
                } else if (_activeTab == 3) {
                  tabBody = _buildSettingsTab();
                } else {
                  tabBody = _buildHomeTab(
                    reading: activeReading,
                    nodeId: activeNodeId,
                    availableNodes: sortedNodeIds,
                    latestByDevice: latestByDevice,
                    isWide: isWide,
                  );
                }

                return _scrollableCentered(isWide: isWide, child: tabBody);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _scrollableCentered({required bool isWide, required Widget child}) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(isWide ? 24 : 16, 14, isWide ? 24 : 16, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isWide ? 960 : 540),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader(bool isWide) {
    return Container(
      width: double.infinity,
      color: _surfaceWhite,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _borderSoft)),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 960 : 540),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _pinkSoft,
                        shape: BoxShape.circle,
                        border: Border.all(color: _accent.withValues(alpha: 0.25)),
                      ),
                      child: const Icon(Icons.local_fire_department_rounded, color: _accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _activeTab == 0
                                ? 'Fire Smart Alarm'
                                : 'Fire Smart Alarm • ${_tabTitles[_activeTab]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _textDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00E676),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Expanded(
                                child: Text(
                                  'Lab Komputer • Firebase Live',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 11, color: _textMuted, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _peachSoft.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sensors_rounded, size: 17, color: _accent),
                    ),
                    const SizedBox(width: 6),
                    StreamBuilder<List<Reading>>(
                      stream: _repository.getReadings(),
                      builder: (context, snap) {
                        final list = snap.data ?? const <Reading>[];
                        final hasAlert = list.any(
                          (r) => r.status.toUpperCase() == 'DANGER' || r.status.toUpperCase() == 'WARNING',
                        );
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _openAlertsSheet(list),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _peachSoft.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _borderSoft),
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.notifications_none_rounded, size: 18, color: _maroon),
                                if (hasAlert)
                                  Positioned(
                                    top: -1,
                                    right: -1,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF1744),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.2),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: _surfaceWhite,
        border: Border(top: BorderSide(color: _borderSoft)),
      ),
      child: SafeArea(
        top: false,
        child: BottomNavigationBar(
          currentIndex: _activeTab,
          onTap: (idx) => setState(() => _activeTab = idx),
          type: BottomNavigationBarType.fixed,
          backgroundColor: _surfaceWhite,
          selectedItemColor: _maroon,
          unselectedItemColor: _textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Beranda'),
            BottomNavigationBarItem(icon: Icon(Icons.history_rounded), label: 'Riwayat'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Laporan'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Pengaturan'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab({
    required Reading reading,
    required String nodeId,
    required List<String> availableNodes,
    required Map<String, Reading> latestByDevice,
    required bool isWide,
  }) {
    final statusUpper = reading.status.toUpperCase();
    final accentColor = _conditionAccentColor(statusUpper);
    final labelColor = _conditionTextColor(statusUpper);
    final isDanger = statusUpper == 'DANGER';
    final isWarning = statusUpper == 'WARNING';

    final dialColumn = Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _borderSoft),
      ),
      child: Center(
        child: SizedBox(
          width: 280,
          height: 280,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 262,
                height: 262,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _maroon.withValues(alpha: 0.18)),
                ),
              ),
              Container(
                width: 196,
                height: 196,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accentColor.withValues(alpha: 0.45), width: 2.5),
                ),
              ),
              Container(
                width: 188,
                height: 188,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFF5F5), _pinkSoft],
                  ),
                  border: Border.all(color: accentColor, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDanger
                            ? Icons.local_fire_department_rounded
                            : isWarning
                                ? Icons.warning_amber_rounded
                                : Icons.check_rounded,
                        color: labelColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'STATUS SISTEM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                        color: _textMuted,
                      ),
                    ),
                    Text(
                      _statusLabel(statusUpper),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: labelColor,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'MQ-2: ${reading.smoke.toStringAsFixed(0)} ppm',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: _textDark,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _surfaceWhite,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _borderSoft),
                      ),
                      child: Text(
                        nodeId,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _maroon,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: _satelliteButton(
                  emoji: '🌡️',
                  label: 'Temp',
                  onTap: () => _openDetailSheet('temp', reading, latestByDevice),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: _satelliteButton(
                  emoji: '💧',
                  label: 'Humid',
                  onTap: () => _openDetailSheet('hum', reading, latestByDevice),
                ),
              ),
              Positioned(
                bottom: 8,
                left: 8,
                child: _satelliteButton(
                  emoji: '💨',
                  label: 'Smoke',
                  onTap: () => _openDetailSheet('smoke', reading, latestByDevice),
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: _satelliteButton(
                  emoji: '📡',
                  label: 'Node',
                  onTap: () => _openDetailSheet('device', reading, latestByDevice),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _quickSummaryCard(
                emoji: '🌡️',
                title: 'Temperature',
                value: '${reading.temperature.toStringAsFixed(1)}°C',
                sub: isDanger ? 'Tinggi!' : isWarning ? 'Meningkat' : 'Stabil',
                subColor: labelColor,
                onTap: () => _openDetailSheet('temp', reading, latestByDevice),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickSummaryCard(
                emoji: '💧',
                title: 'Humidity',
                value: '${reading.humidity.toStringAsFixed(1)}%',
                sub: isDanger ? 'Kering' : isWarning ? 'Menurun' : 'Ideal',
                subColor: labelColor,
                onTap: () => _openDetailSheet('hum', reading, latestByDevice),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _quickSummaryCard(
                emoji: '💨',
                title: 'MQ-2 Smoke',
                value: '${reading.smoke.toStringAsFixed(0)} ppm',
                sub: isDanger ? 'Bahaya!' : isWarning ? 'Waspada' : 'Bersih',
                subColor: labelColor,
                onTap: () => _openDetailSheet('smoke', reading, latestByDevice),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Node & Status Koneksi',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _textDark),
                  ),
                  Text(
                    _formatDateTime(reading.timestamp),
                    style: const TextStyle(fontSize: 11, color: _textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _borderSoft),
                ),
                child: Row(
                  children: availableNodes.map((id) {
                    final selected = id == nodeId;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _selectedNode = id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: selected ? _accent : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              id,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : _textDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _conditionBannerBg(statusUpper),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withValues(alpha: 0.45)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(color: labelColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _conditionBannerMessage(reading, statusUpper),
                      style: const TextStyle(fontSize: 12.5, color: _textDark, height: 1.45, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              if (isDanger) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _showMuteConfirmationDialog(nodeId),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD50000),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.volume_off_rounded, size: 18),
                  label: const Text(
                    'MATIKAN BUZZER SEKARANG',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 330, child: dialColumn),
          const SizedBox(width: 16),
          Expanded(child: rightColumn),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        dialColumn,
        const SizedBox(height: 14),
        rightColumn,
      ],
    );
  }

  Widget _satelliteButton({
    required String emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: _peachSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _borderSoft),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14, height: 1.05)),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _maroon),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickSummaryCard({
    required String emoji,
    required String title,
    required String value,
    required String sub,
    required Color subColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: _peachSoft.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderSoft),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _textDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _textDark),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(List<Reading> readings, List<String> availableNodes) {
    final filtered = readings.where((item) {
      final devMatch = _historyDeviceFilter == 'ALL' ||
          _normalizeNodeId(item.deviceId) == _historyDeviceFilter;
      final stMatch = _historyStatusFilter == 'ALL' ||
          item.status.toUpperCase() == _historyStatusFilter;
      return devMatch && stMatch;
    }).take(_historyLimit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Riwayat Pembacaan Sensor',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
            ),
            Text(
              '${filtered.length} data',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _accent),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip(
                label: 'Semua Node',
                selected: _historyDeviceFilter == 'ALL',
                onTap: () => setState(() => _historyDeviceFilter = 'ALL'),
              ),
              ...availableNodes.map(
                (id) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: _filterChip(
                    label: id,
                    selected: _historyDeviceFilter == id,
                    onTap: () => setState(() => _historyDeviceFilter = id),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: ['ALL', 'NORMAL', 'WARNING', 'DANGER'].map((st) {
              final label = st == 'ALL' ? 'Semua Status' : _statusLabel(st);
              return Padding(
                padding: EdgeInsets.only(right: st == 'DANGER' ? 0 : 6),
                child: _filterChip(
                  label: label,
                  selected: _historyStatusFilter == st,
                  onTap: () => setState(() => _historyStatusFilter = st),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _surfaceWhite,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _borderSoft),
            ),
            child: const Text(
              'Tidak ada riwayat sesuai filter yang dipilih.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _textMuted),
            ),
          )
        else
          ...filtered.map((item) {
            final stUpper = item.status.toUpperCase();
            final stColor = _conditionTextColor(stUpper);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _surfaceWhite,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_normalizeNodeId(item.deviceId)} • ${_statusLabel(stUpper)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: stColor),
                      ),
                      Text(
                        _formatDateTime(item.timestamp),
                        style: const TextStyle(fontSize: 11, color: _textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Temp: ${item.temperature.toStringAsFixed(1)}°C  |  '
                    'Humidity: ${item.humidity.toStringAsFixed(1)}%  |  '
                    'Smoke: ${item.smoke.toStringAsFixed(0)} ppm',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _textDark),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _accent : _surfaceWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _accent : _borderSoft),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _textDark,
          ),
        ),
      ),
    );
  }

  Widget _buildReportTab(List<Reading> readings) {
    final filtered = readings.where((r) {
      final statusOk = _reportStatus == 'Semua' ||
          r.status.toLowerCase() == _reportStatus.toLowerCase();
      final range = _reportDateRange;
      final dateOk = range == null ||
          (!r.timestamp.isBefore(DateTime(range.start.year, range.start.month, range.start.day)) &&
              r.timestamp.isBefore(DateTime(range.end.year, range.end.month, range.end.day + 1)));
      return statusOk && dateOk;
    }).toList();

    final normalCount = filtered.where((r) => r.status.toLowerCase() == 'normal').length;
    final warningCount = filtered.where((r) => r.status.toLowerCase() == 'warning').length;
    final dangerCount = filtered.where((r) => r.status.toLowerCase() == 'danger').length;

    final avgTemp = filtered.isEmpty
        ? 0.0
        : filtered.map((r) => r.temperature).reduce((a, b) => a + b) / filtered.length;
    final avgHum = filtered.isEmpty
        ? 0.0
        : filtered.map((r) => r.humidity).reduce((a, b) => a + b) / filtered.length;
    final avgSmoke = filtered.isEmpty
        ? 0.0
        : filtered.map((r) => r.smoke).reduce((a, b) => a + b) / filtered.length;

    final chartSeries = filtered.reversed.take(80).toList();
    final visibleCount = _reportVisibleCount.clamp(0, filtered.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Laporan & Analisis Sensor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
                  ),
                  Text(
                    'Data telemetri Laboratorium Komputer',
                    style: TextStyle(fontSize: 12, color: _textMuted),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: filtered.isEmpty ? null : () => _exportReportPdf(filtered),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 17),
              label: const Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderSoft),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _pickReportDateRange,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _maroon,
                  side: const BorderSide(color: _borderSoft),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.calendar_month_rounded, size: 17),
                label: Text(
                  _reportDateRange == null
                      ? 'Semua tanggal'
                      : '${_dateOnly(_reportDateRange!.start)} – ${_dateOnly(_reportDateRange!.end)}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String>(
                  value: _reportStatus,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Semua', child: Text('Semua status', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Normal', child: Text('Normal', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Warning', child: Text('Warning', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Danger', child: Text('Danger', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _reportStatus = v;
                        _reportVisibleCount = 40;
                      });
                    }
                  },
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _reportDateRange = null;
                  _reportStatus = 'Semua';
                  _reportVisibleCount = 40;
                }),
                child: const Text('Reset', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textMuted)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _reportCountBox('$normalCount', 'Normal', const Color(0xFFE8F8F0), const Color(0xFF008744)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _reportCountBox('$warningCount', 'Warning', const Color(0xFFFFF8E7), const Color(0xFFC65102)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _reportCountBox('$dangerCount', 'Danger', const Color(0xFFFCE8EB), const Color(0xFFC50000)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _avgMiniCard('Rata-rata Suhu', '${avgTemp.toStringAsFixed(1)}°C'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _avgMiniCard('Rata-rata Humid', '${avgHum.toStringAsFixed(1)}%'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _avgMiniCard('Rata-rata Asap', '${avgSmoke.toStringAsFixed(0)} ppm'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (chartSeries.length >= 2) ...[
          _singleMetricChartCard(
            title: 'Grafik Temperature (°C) — DHT22',
            subtitle: 'Rata-rata: ${avgTemp.toStringAsFixed(1)}°C',
            values: chartSeries.map((r) => r.temperature).toList(),
            lineColor: _maroon,
          ),
          const SizedBox(height: 10),
          _singleMetricChartCard(
            title: 'Grafik Humidity (%) — DHT22',
            subtitle: 'Rata-rata: ${avgHum.toStringAsFixed(1)}%',
            values: chartSeries.map((r) => r.humidity).toList(),
            lineColor: const Color(0xFF0284C7),
          ),
          const SizedBox(height: 10),
          _singleMetricChartCard(
            title: 'Grafik MQ-2 Smoke (ppm)',
            subtitle: 'Rata-rata: ${avgSmoke.toStringAsFixed(0)} ppm',
            values: chartSeries.map((r) => r.smoke).toList(),
            lineColor: const Color(0xFFC65102),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          'Detail Data (${filtered.length} data)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _borderSoft),
            ),
            child: const Text('Tidak ada data untuk filter ini.', textAlign: TextAlign.center),
          )
        else ...[
          for (var i = 0; i < visibleCount; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _borderSoft),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '#${i + 1} • ${_normalizeNodeId(filtered[i].deviceId)} • ${_statusLabel(filtered[i].status.toUpperCase())}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _conditionTextColor(filtered[i].status.toUpperCase()),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${filtered[i].temperature.toStringAsFixed(1)}°C | '
                          '${filtered[i].humidity.toStringAsFixed(1)}% | '
                          '${filtered[i].smoke.toStringAsFixed(0)} ppm',
                          style: const TextStyle(fontSize: 12, color: _textDark),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatDateTime(filtered[i].timestamp),
                    style: const TextStyle(fontSize: 10.5, color: _textMuted),
                  ),
                ],
              ),
            ),
          if (visibleCount < filtered.length)
            Center(
              child: OutlinedButton(
                onPressed: () => setState(() {
                  _reportVisibleCount = (_reportVisibleCount + 40).clamp(0, filtered.length);
                }),
                child: Text('Tampilkan 40 data lagi (${filtered.length - visibleCount} tersisa)'),
              ),
            ),
        ],
      ],
    );
  }

  Widget _reportCountBox(String count, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _textDark)),
        ],
      ),
    );
  }

  Widget _avgMiniCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10.5, color: _textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _textDark)),
        ],
      ),
    );
  }

  Widget _singleMetricChartCard({
    required String title,
    required String subtitle,
    required List<double> values,
    required Color lineColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark)),
              ),
              Text(subtitle, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: lineColor)),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 135,
            width: double.infinity,
            child: CustomPaint(painter: _ReportLinePainter(values, lineColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pengaturan Sistem IoT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _textDark),
        ),
        const SizedBox(height: 12),
        const _AlarmControlCard(),
        const SizedBox(height: 14),
        const _ThresholdSettingsCard(),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _borderSoft),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SINKRONISASI CLOUD',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _maroon, letterSpacing: 0.6),
              ),
              const SizedBox(height: 10),
              _infoRow('Database Backend', 'Firebase Firestore'),
              const SizedBox(height: 8),
              _infoRow('Koleksi Pembacaan', 'fire-activity'),
              const SizedBox(height: 8),
              _infoRow('Koleksi Kontrol', 'alarm-control'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Apakah kamu yakin ingin keluar dari akun?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: FilledButton.styleFrom(backgroundColor: _accent),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    if (shouldLogout == true) {
                      await FirebaseAuth.instance.signOut();
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC50000),
                    side: const BorderSide(color: Color(0xFFE8D8D3)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Logout dari Akun', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _exportReportPdf(List<Reading> readings) async {
    final pdf = pw.Document();
    final normal = readings.where((r) => r.status.toLowerCase() == 'normal').length;
    final warning = readings.where((r) => r.status.toLowerCase() == 'warning').length;
    final danger = readings.where((r) => r.status.toLowerCase() == 'danger').length;

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'Laporan Monitoring Sensor Fire Smart Alarm',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Tanggal ekspor: ${_formatDateTime(DateTime.now())}'),
          pw.Text(
            'Periode: ${_reportDateRange == null ? 'Semua tanggal' : '${_dateOnly(_reportDateRange!.start)} - ${_dateOnly(_reportDateRange!.end)}'}',
          ),
          pw.Text('Filter status: $_reportStatus'),
          pw.SizedBox(height: 10),
          pw.Text(
            'Ringkasan: ${readings.length} data | Normal: $normal | Warning: $warning | Danger: $danger',
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: ['Waktu', 'Node', 'Suhu (°C)', 'Kelembapan (%)', 'Asap (ppm)', 'Status'],
            data: readings
                .map(
                  (r) => [
                    _formatDateTime(r.timestamp),
                    _normalizeNodeId(r.deviceId),
                    r.temperature.toStringAsFixed(1),
                    r.humidity.toStringAsFixed(1),
                    r.smoke.toStringAsFixed(1),
                    _statusLabel(r.status.toUpperCase()),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'laporan_fire_smart_alarm.pdf',
    );
  }
}

class _AlarmControlCard extends StatefulWidget {
  const _AlarmControlCard();

  @override
  State<_AlarmControlCard> createState() => _AlarmControlCardState();
}

class _AlarmControlCardState extends State<_AlarmControlCard> {
  String _selectedDevice = 'ESP32_001';
  bool _sending = false;

  String get _documentId => _selectedDevice == 'ESP32_001' ? 'esp32-lab-01' : 'esp32-lab-02';

  Future<void> _sendCommand(
    DocumentReference> ref,
    bool nextEnabled,
  ) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await ref.set({
        'alarmEnabled': nextEnabled,
        'commandStatus': 'pending',
        'commandUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Perintah gagal dikirim: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('alarm-control').doc(_documentId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kontrol Alarm', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedDevice,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pilih perangkat',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'ESP32_001', child: Text('ESP32_001')),
              DropdownMenuItem(value: 'ESP32_002', child: Text('ESP32_002')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedDevice = value);
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>>(
            stream: ref.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Gagal membaca kontrol: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: _accent));
              }

              final data = snapshot.data!.data() ?? <String, dynamic>{};
              final enabled = data['alarmEnabled'] as bool? ?? true;
              final commandStatus = data['commandStatus'] as String? ?? 'unknown';
              final buzzerStatus = data['buzzerStatus'] as bool?;
              final lastSeen = data['lastSeen'];
              final lastSeenDate = lastSeen is Timestamp ? lastSeen.toDate() : null;
              final online = lastSeenDate != null && DateTime.now().difference(lastSeenDate).inSeconds <= 30;

              String feedbackText;
              Color feedbackColor;
              if (!online) {
                feedbackText = 'ESP32 tidak merespons / belum mengirim heartbeat';
                feedbackColor = Colors.red;
              } else if (commandStatus == 'pending' || commandStatus == 'received') {
                feedbackText = commandStatus == 'pending'
                    ? 'Perintah terkirim, menunggu ESP32...'
                    : 'ESP32 menerima perintah, sedang menerapkan...';
                feedbackColor = Colors.orange;
              } else if (commandStatus == 'success') {
                feedbackText = enabled
                    ? 'ESP32 mengonfirmasi pengaturan alarm ON'
                    : 'ESP32 mengonfirmasi pengaturan alarm OFF';
                feedbackColor = Colors.green;
              } else {
                feedbackText = 'ESP32 online';
                feedbackColor = Colors.blueGrey;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        enabled ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                        color: enabled ? _accent : Colors.red,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enabled ? 'Alarm diaktifkan' : 'Alarm dinonaktifkan',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: _textDark),
                            ),
                            const Text(
                              'Pengaturan buzzer saat kondisi Danger',
                              style: TextStyle(fontSize: 11, color: _textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : () => _sendCommand(ref, !enabled),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(enabled ? Icons.notifications_off_rounded : Icons.notifications_active_rounded),
                      label: Text(
                        _sending ? 'Mengirim perintah...' : enabled ? 'Matikan Buzzer' : 'Aktifkan Buzzer',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(feedbackText, style: TextStyle(fontSize: 11.5, color: feedbackColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    buzzerStatus == null
                        ? 'Output buzzer: belum ada konfirmasi'
                        : 'Output buzzer ESP32: ${buzzerStatus ? "AKTIF" : "MATI"}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _textDark),
                  ),
                  const SizedBox(height: 4),
                  Text('Dokumen: alarm-control/$_documentId', style: const TextStyle(fontSize: 10, color: _textMuted)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThresholdSettingsCard extends StatefulWidget {
  const _ThresholdSettingsCard();

  @override
  State<_ThresholdSettingsCard> createState() => _ThresholdSettingsCardState();
}

class _ThresholdSettingsCardState extends State<_ThresholdSettingsCard> {
  String _selectedDevice = 'ESP32_001';
  bool _saving = false;

  String get _documentId => _selectedDevice == 'ESP32_001' ? 'esp32-lab-01' : 'esp32-lab-02';

  Future<void> _editThreshold(int currentWarning, int currentDanger) async {
    final warningController = TextEditingController(text: '$currentWarning');
    final dangerController = TextEditingController(text: '$currentDanger');
    String? errorText;

    final result = await showDialog>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Ubah Nilai Threshold'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: warningController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Batas Warning (ppm)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dangerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Batas Danger (ppm)', border: OutlineInputBorder()),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: () {
                final warning = int.tryParse(warningController.text.trim());
                final danger = int.tryParse(dangerController.text.trim());
                if (warning == null || danger == null || warning < 1 || danger > 4095) {
                  setDialogState(() => errorText = 'Masukkan angka antara 1 sampai 4095.');
                  return;
                }
                if (warning >= danger) {
                  setDialogState(() => errorText = 'Batas Warning harus lebih kecil dari Danger.');
                  return;
                }
                Navigator.pop(dialogContext, {'warning': warning, 'danger': danger});
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    warningController.dispose();
    dangerController.dispose();
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('alarm-control').doc(_documentId).set({
        'thresholdWarning': result['warning'],
        'thresholdDanger': result['danger'],
        'thresholdUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nilai threshold berhasil disimpan.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan threshold: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance.collection('alarm-control').doc(_documentId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surfaceWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengaturan Threshold Sensor',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _textDark),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedDevice,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pilih perangkat',
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            items: const [
              DropdownMenuItem(value: 'ESP32_001', child: Text('ESP32_001')),
              DropdownMenuItem(value: 'ESP32_002', child: Text('ESP32_002')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedDevice = value);
            },
          ),
          const SizedBox(height: 12),
          StreamBuilder<DocumentSnapshot>>(
            stream: ref.snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? <String, dynamic>{};
              final warning = (data['thresholdWarning'] as num?)?.toInt() ?? 450;
              final danger = (data['thresholdDanger'] as num?)?.toInt() ?? 600;
              final valid = warning < danger;
              final shownWarning = valid ? warning : 450;
              final shownDanger = valid ? danger : 600;

              return Column(
                children: [
                  _infoRow('Normal', 'Asap < $shownWarning ppm'),
                  const SizedBox(height: 6),
                  _infoRow('Warning', 'Asap $shownWarning – ${shownDanger - 1} ppm'),
                  const SizedBox(height: 6),
                  _infoRow('Danger', 'Asap >= $shownDanger ppm'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _saving || snapshot.hasError
                          ? null
                          : () => _editThreshold(shownWarning, shownDanger),
                      icon: const Icon(Icons.edit_rounded, size: 17, color: Colors.white),
                      label: Text(
                        _saving ? 'Menyimpan...' : 'Ubah Nilai Threshold',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportLinePainter extends CustomPainter {
  _ReportLinePainter(this.values, this.lineColor);

  final List<double> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    const pad = 10.0;
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final span = (maxVal - minVal).abs() < 0.0001 ? 1.0 : maxVal - minVal;
    final h = size.height - pad * 2;

    final gridPaint = Paint()
      ..color = _borderSoft
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = pad + h * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = pad + h * (1 - (values[i] - minVal) / span);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _ReportLinePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.values.length != values.length ||
      oldDelegate.values.asMap().entries.any((e) => e.value != values[e.key]);
}

Widget _sheetMetricBox({
  required String title,
  required String label,
  required String value,
  required Color valueColor,
  required String extra,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _textDark)),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _borderSoft),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: _textMuted)),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: valueColor)),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(extra, style: const TextStyle(fontSize: 11, color: _textMuted)),
    ],
  );
}

Widget _infoRow(String left, String right) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(left, style: const TextStyle(fontSize: 12, color: _textMuted)),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textDark),
        ),
      ),
    ],
  );
}

Widget _emptyState(String title, String subtitle) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors_rounded, size: 46, color: _accent),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: _textMuted)),
        ],
      ),
    ),
  );
}

String _statusLabel(String statusUpper) {
  if (statusUpper == 'DANGER') return 'DANGER';
  if (statusUpper == 'WARNING') return 'Warning';
  return 'Normal';
}

String _dateOnly(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _formatDateTime(DateTime dt) =>
    '${_dateOnly(dt)} '
    '${dt.hour.toString().padLeft(2, '0')}:'
    '${dt.minute.toString().padLeft(2, '0')}:'
    '${dt.second.toString().padLeft(2, '0')}';
