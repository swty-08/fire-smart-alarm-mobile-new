import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/reading.dart';
import '../repositories/reading_repository.dart';
import '../services/notification_service.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const Color _background = Color(0xFFFBF7F4);
const Color _cardColor = Color(0xFFFFF4F1);
const Color _statusCardColor = Color(0xFFFCE6E4);
const Color _accent = Color(0xFF8B3A35);
const Color _accentSecondary = Color(0xFF9E4742);
const Color _borderWarm = Color(0xFFEDE2DE);
const Color _textDark = Color(0xFF352725);
const Color _textMuted = Color(0xFF7A6A67);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ReadingRepository _repository = ReadingRepository();
  int _mobileTab = 0;
  int _desktopTab = 0;
  int _desktopHistoryCount = 20;
  DateTimeRange? _reportDateRange;
  String _reportStatus = 'Semua';
  String _selectedDetailDevice = 'Semua perangkat';
  String _selectedHistoryDevice = 'Semua perangkat';
  int _reportVisibleCount = 40;

  String? _lastNotifiedStatus;
  String? _lastNotifiedDevice;

  Future<void> _pickReportDateRange() async {
    final now = DateTime.now();
    final initialStart =
        _reportDateRange?.start ?? DateTime(now.year, now.month, now.day);
    DateTime visibleMonth = DateTime(initialStart.year, initialStart.month);
    DateTime? start = _reportDateRange?.start;
    DateTime? end = _reportDateRange?.end;

    final picked = await showDialog<DateTimeRange>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final firstDay = DateTime(visibleMonth.year, visibleMonth.month, 1);
          final daysInMonth = DateUtils.getDaysInMonth(
            visibleMonth.year,
            visibleMonth.month,
          );
          final leading = firstDay.weekday % 7;
          final cells = ((leading + daysInMonth + 6) ~/ 7) * 7;
          String format(DateTime d) => '${d.day}/${d.month}/${d.year}';
          bool sameDay(DateTime? a, DateTime b) =>
              a != null &&
              a.year == b.year &&
              a.month == b.month &&
              a.day == b.day;
          bool inRange(DateTime d) =>
              start != null &&
              end != null &&
              !d.isBefore(DateUtils.dateOnly(start!)) &&
              !d.isAfter(DateUtils.dateOnly(end!));

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
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
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _textDark,
                            ),
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
                            () => visibleMonth = DateTime(
                              visibleMonth.year,
                              visibleMonth.month - 1,
                            ),
                          ),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              '${_monthName(visibleMonth.month)} ${visibleMonth.year}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setDialogState(
                            () => visibleMonth = DateTime(
                              visibleMonth.year,
                              visibleMonth.month + 1,
                            ),
                          ),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab']
                          .map(
                            (d) => Expanded(
                              child: Center(
                                child: Text(
                                  d,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 6),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cells,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 3,
                            crossAxisSpacing: 3,
                          ),
                      itemBuilder: (context, index) {
                        final day = index - leading + 1;
                        if (day < 1 || day > daysInMonth) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime(
                          visibleMonth.year,
                          visibleMonth.month,
                          day,
                        );
                        final selected =
                            sameDay(start, date) || sameDay(end, date);
                        final range = inRange(date);
                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => setDialogState(() {
                            if (start == null ||
                                end != null ||
                                date.isBefore(start!)) {
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
                                  ? _cardColor
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 12,
                                color: selected ? Colors.white : _textDark,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.normal,
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
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Batal',
                            style: TextStyle(fontSize: 13),
                          ),
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
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            'Terapkan',
                            style: TextStyle(fontSize: 13),
                          ),
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
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return months[month - 1];
  }

  Widget _buildMobileOverview(List<Reading> deviceReadings) {
    final danger = deviceReadings
        .where((r) => r.status.toLowerCase() == 'danger')
        .length;
    final warning = deviceReadings
        .where((r) => r.status.toLowerCase() == 'warning')
        .length;
    final normal = deviceReadings.length - danger - warning;
    final Color stateColor = danger > 0
        ? const Color(0xFFC62828)
        : warning > 0
        ? const Color(0xFFE58A18)
        : const Color(0xFF21865D);
    final String stateLabel = danger > 0
        ? 'Bahaya terdeteksi'
        : warning > 0
        ? 'Perlu perhatian'
        : 'Semua perangkat normal';

    Widget countItem(String label, int value, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: _textMuted),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderWarm),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pemantauan Laboratorium',
            style: TextStyle(
              fontSize: 13,
              color: _textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                danger > 0
                    ? Icons.warning_rounded
                    : warning > 0
                    ? Icons.info_rounded
                    : Icons.check_circle_rounded,
                color: stateColor,
                size: 23,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: stateColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              countItem('Normal', normal, const Color(0xFF21865D)),
              const SizedBox(width: 8),
              countItem('Warning', warning, const Color(0xFFE58A18)),
              const SizedBox(width: 8),
              countItem('Danger', danger, const Color(0xFFC62828)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${deviceReadings.length} perangkat terpantau • data diperbarui secara real-time',
            style: const TextStyle(fontSize: 11, color: _textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestReadingsSection(List<Reading> deviceReadings) {
    final deviceIds =
        deviceReadings
            .map(
              (reading) => reading.deviceId.trim().isEmpty
                  ? 'Perangkat tanpa ID'
                  : reading.deviceId.trim(),
            )
            .toSet()
            .toList()
          ..sort();

    final selectedDevice =
        _selectedDetailDevice == 'Semua perangkat' ||
            deviceIds.contains(_selectedDetailDevice)
        ? _selectedDetailDevice
        : 'Semua perangkat';

    final selectedReadings = selectedDevice == 'Semua perangkat'
        ? deviceReadings
        : deviceReadings.where((reading) {
            final id = reading.deviceId.trim().isEmpty
                ? 'Perangkat tanpa ID'
                : reading.deviceId.trim();
            return id == selectedDevice;
          }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 430;
            const heading = Text(
              'Detail Pembacaan Terbaru',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textDark,
              ),
            );
            final filter = DropdownButtonFormField<String>(
              initialValue: selectedDevice,
              isExpanded: true,
              style: const TextStyle(fontSize: 12, color: _textDark),
              selectedItemBuilder: (context) => ['Semua perangkat', ...deviceIds]
                  .map(
                    (id) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _textDark),
                      ),
                    ),
                  )
                  .toList(),
              decoration: InputDecoration(
                labelText: 'Filter perangkat',
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _borderWarm),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _borderWarm),
                ),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'Semua perangkat',
                  child: Text(
                    'Semua perangkat',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                ...deviceIds.map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(
                      id,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedDetailDevice = value);
                }
              },
            );
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: filter),
                ],
              );
            }
            return Row(
              children: [
                const Expanded(child: heading),
                const SizedBox(width: 12),
                SizedBox(width: 200, child: filter),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (selectedReadings.isEmpty)
          const Text('Belum ada pembacaan sensor.')
        else
          ...selectedReadings.map((reading) {
            final deviceId = reading.deviceId.trim().isEmpty
                ? 'Perangkat tanpa ID'
                : reading.deviceId.trim();
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderWarm),
                boxShadow: [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory, color: _accent, size: 20),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          deviceId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _textDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _formatDateTime(reading.timestamp),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildStatusCard(reading),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 420;
                      if (compact) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildSensorCard(
                                    icon: Icons.thermostat,
                                    title: 'Temperature',
                                    value:
                                        '${reading.temperature.toStringAsFixed(1)} °C',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildSensorCard(
                                    icon: Icons.water_drop,
                                    title: 'Humidity',
                                    value:
                                        '${reading.humidity.toStringAsFixed(1)} %',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildSmokeCard(reading),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(
                            child: _buildSensorCard(
                              icon: Icons.thermostat,
                              title: 'Temperature',
                              value:
                                  '${reading.temperature.toStringAsFixed(1)} °C',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSensorCard(
                              icon: Icons.water_drop,
                              title: 'Humidity',
                              value:
                                  '${reading.humidity.toStringAsFixed(1)} %',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSmokeCard(reading)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      backgroundColor: _background,
      appBar: isWeb
          ? null
          : AppBar(
              backgroundColor: _background,
              elevation: 0,
              centerTitle: false,
              titleSpacing: 0,
              leading: _mobileTab == 0
                  ? const Padding(
                      padding: EdgeInsets.only(left: 16),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: _accent,
                        size: 27,
                      ),
                    )
                  : IconButton(
                      tooltip: 'Kembali ke Beranda',
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: _textDark,
                      ),
                      onPressed: () => setState(() => _mobileTab = 0),
                    ),
              title: Text(
                const [
                  'Fire Smart Alarm',
                  'Riwayat Sensor',
                  'Laporan',
                  'Pengaturan',
                ][_mobileTab],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              actions: [
                if (_mobileTab == 0)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.sensors_rounded, color: _accent),
                  ),
              ],
            ),
      bottomNavigationBar: isWeb
          ? null
          : BottomNavigationBar(
              currentIndex: _mobileTab,
              selectedItemColor: _accent,
              unselectedItemColor: const Color(0xFF817674),
              backgroundColor: Colors.white,
              elevation: 12,
              selectedFontSize: 11,
              unselectedFontSize: 10,
              iconSize: 22,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              onTap: (i) => setState(() => _mobileTab = i),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded),
                  label: 'Beranda',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_rounded),
                  label: 'Riwayat',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.assessment_rounded),
                  label: 'Laporan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_rounded),
                  label: 'Pengaturan',
                ),
              ],
            ),
      body: StreamBuilder<List<Reading>>(
        stream: _repository.getReadings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }
          if (snapshot.hasError) {
            return _message(
              'Data tidak dapat dibaca',
              'Periksa koneksi internet dan pengaturan Firebase.\n${snapshot.error}',
            );
          }
          final readings = snapshot.data ?? [];
          if (readings.isEmpty) {
            if (!isWeb && _mobileTab == 2) {
              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  child: _buildReportSection(readings),
                ),
              );
            }
            if (!isWeb && _mobileTab == 3) {
              return const MobileSettingsScreen(embedded: true);
            }
            if (!isWeb && _mobileTab == 1) {
              return _message(
                'Belum ada riwayat',
                'Data sensor akan tampil setelah tersedia di Firebase.',
              );
            }
            return _message(
              'Belum ada data sensor',
              'Data dari Firebase akan tampil di halaman ini.',
            );
          }
          final historyDeviceIds =
              readings
                  .map(
                    (reading) => reading.deviceId.trim().isEmpty
                        ? 'Perangkat tanpa ID'
                        : reading.deviceId.trim(),
                  )
                  .toSet()
                  .toList()
                ..sort();
          final selectedHistoryDevice =
              _selectedHistoryDevice == 'Semua perangkat' ||
                  historyDeviceIds.contains(_selectedHistoryDevice)
              ? _selectedHistoryDevice
              : 'Semua perangkat';
          final historyDeviceReadings = selectedHistoryDevice == 'Semua perangkat'
              ? readings
              : readings.where((reading) {
                  final id = reading.deviceId.trim().isEmpty
                      ? 'Perangkat tanpa ID'
                      : reading.deviceId.trim();
                  return id == selectedHistoryDevice;
                }).toList();

          final latestByDevice = <String, Reading>{};
          for (final reading in readings) {
            final id = reading.deviceId.trim().isEmpty
                ? 'Perangkat tanpa ID'
                : reading.deviceId.trim();
            final previous = latestByDevice[id];
            if (previous == null ||
                reading.timestamp.isAfter(previous.timestamp)) {
              latestByDevice[id] = reading;
            }
          }
          final deviceReadings = latestByDevice.values.toList()
            ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
          final latest = readings.first;
          final currentStatus = latest.status.toLowerCase();

          if (currentStatus == 'warning' || currentStatus == 'danger') {
            if (_lastNotifiedStatus != latest.status ||
                _lastNotifiedDevice != latest.deviceId) {
              _lastNotifiedStatus = latest.status;
              _lastNotifiedDevice = latest.deviceId;

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                NotificationService.showStatusNotification(
                  status: latest.status,
                  temperature: latest.temperature,
                  smoke: latest.smoke,
                );
              });
            }
          } else {
            _lastNotifiedStatus = null;
            _lastNotifiedDevice = null;
          }
          final trend = readings.take(20).toList().reversed.toList();
          if (!isWeb) {
            if (_mobileTab == 1) {
              final history = historyDeviceReadings
                  .take(_desktopHistoryCount)
                  .toList();
              return SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    _sectionTitle('Pilih perangkat'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedHistoryDevice,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12, color: _textDark),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _accent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _accent),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'Semua perangkat',
                            child: Text(
                              'Semua perangkat',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          ...historyDeviceIds.map(
                            (id) => DropdownMenuItem(
                              value: id,
                              child: Text(
                                id,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedHistoryDevice = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Pilih jumlah data'),
                    const SizedBox(height: 10),
                    Row(
                      children: [20, 50, 100]
                          .map(
                            (count) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: count == 100 ? 0 : 8,
                                ),
                                child: ChoiceChip(
                                  label: Center(child: Text('$count')),
                                  selected: _desktopHistoryCount == count,
                                  showCheckmark: false,
                                  selectedColor: _accent,
                                  backgroundColor: _cardColor,
                                  labelStyle: TextStyle(
                                    color: _desktopHistoryCount == count
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  onSelected: (_) => setState(
                                    () => _desktopHistoryCount = count,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 14),
                    _buildChartCard(history.reversed.toList(), height: 190),
                    const SizedBox(height: 20),
                    _sectionTitle('Riwayat Sensor (${history.length} data)'),
                    const SizedBox(height: 10),
                    if (history.isEmpty)
                      const Text('Belum ada riwayat sensor.')
                    else
                      ...history.asMap().entries.map(
                        (e) => _buildHistoryCard(e.value, e.key + 1),
                      ),
                  ],
                ),
              );
            }
            if (_mobileTab == 2) {
              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  child: _buildReportSection(readings),
                ),
              );
            }
            if (_mobileTab == 3) {
              return const MobileSettingsScreen(embedded: true);
            }
            return SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _buildMobileOverview(deviceReadings),
                      const SizedBox(height: 20),
                      _buildLatestReadingsSection(deviceReadings),
                      const SizedBox(height: 16),
                      const _AlarmControlCard(),
                      const SizedBox(height: 22),
                      _sectionTitle('Tren pembacaan sensor'),
                      const SizedBox(height: 10),
                      _buildChartCard(trend, height: 190),
                      const SizedBox(height: 22),
                      _sectionTitle('Aktivitas sensor terbaru'),
                      const SizedBox(height: 10),
                      ...readings
                          .take(5)
                          .toList()
                          .asMap()
                          .entries
                          .map((e) => _buildHistoryCard(e.value, e.key + 1)),
                      OutlinedButton.icon(
                        onPressed: () => setState(() => _mobileTab = 1),
                        icon: const Icon(Icons.history),
                        label: const Text('Lihat Semua Riwayat'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Row(
            children: [
              Container(
                width: 205,
                color: const Color(0xFF9E342F),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 22, 12, 30),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_fire_department,
                              color: Colors.white,
                              size: 30,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Fire Smart Alarm',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      _sideItem(
                        Icons.dashboard,
                        'Dashboard',
                        _desktopTab == 0,
                        () => setState(() => _desktopTab = 0),
                      ),
                      _sideItem(
                        Icons.list_alt,
                        'Riwayat Sensor',
                        _desktopTab == 1,
                        () => setState(() => _desktopTab = 1),
                      ),
                      _sideItem(
                        Icons.show_chart,
                        'Grafik',
                        _desktopTab == 2,
                        () => setState(() => _desktopTab = 2),
                      ),
                      _sideItem(
                        Icons.settings,
                        'Pengaturan',
                        _desktopTab == 3,
                        () => setState(() => _desktopTab = 3),
                      ),
                      _sideItem(
                        Icons.info,
                        'Tentang',
                        _desktopTab == 4,
                        () => setState(() => _desktopTab = 4),
                      ),
                      _sideItem(
                        Icons.assessment,
                        'Laporan',
                        _desktopTab == 5,
                        () => setState(() => _desktopTab = 5),
                      ),
                      const SizedBox(height: 12),
                      _sideItem(Icons.logout, 'Logout', false, () async {
                        final shouldLogout = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Logout'),
                            content: const Text(
                              'Apakah kamu yakin ingin keluar dari akun?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Batal'),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Logout'),
                              ),
                            ],
                          ),
                        );

                        if (shouldLogout == true) {
                          await FirebaseAuth.instance.signOut();
                        }
                      }),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
                    children: [
                      if (_desktopTab != 5) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _desktopTab == 1
                                        ? 'Riwayat Sensor'
                                        : _desktopTab == 2
                                        ? 'Grafik Sensor'
                                        : _desktopTab == 3
                                        ? 'Pengaturan Sistem'
                                        : _desktopTab == 4
                                        ? 'Tentang Fire Smart Alarm'
                                        : 'Dashboard Monitoring',
                                    style: const TextStyle(
                                      fontSize: 21,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    _desktopTab == 1
                                        ? 'Lihat riwayat pembacaan sensor.'
                                        : _desktopTab == 2
                                        ? 'Pantau perubahan suhu, kelembapan, dan asap.'
                                        : _desktopTab == 3
                                        ? 'Kelola alarm dan lihat aturan kondisi sensor.'
                                        : 'Pantau kondisi laboratorium secara real-time',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.circle,
                              color: Colors.red,
                              size: 10,
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              'Real-time',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                            const SizedBox(width: 22),
                            Text(
                              _formatDateTime(DateTime.now()),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                      ],
                      if (_desktopTab == 0) ...[
                        _buildLatestReadingsSection(deviceReadings),
                        const SizedBox(height: 14),
                        const _AlarmControlCard(),
                        const SizedBox(height: 16),
                        _sectionTitle('Grafik 20 data terakhir'),
                        const SizedBox(height: 10),
                        _buildChartCard(trend, height: 118),
                        const SizedBox(height: 18),
                        _sectionTitle('Riwayat Sensor Terbaru'),
                        const SizedBox(height: 8),
                        _desktopHistoryTable(readings.take(5).toList()),
                      ] else if (_desktopTab == 1) ...[
                        _sectionTitle('Pilih perangkat'),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 280,
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedHistoryDevice,
                            isExpanded: true,
                            style: const TextStyle(
                              fontSize: 12,
                              color: _textDark,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFFFBFA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: _accentSecondary,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: _accentSecondary,
                                ),
                              ),
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'Semua perangkat',
                                child: Text(
                                  'Semua perangkat',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              ...historyDeviceIds.map(
                                (id) => DropdownMenuItem(
                                  value: id,
                                  child: Text(
                                    id,
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedHistoryDevice = value);
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        _sectionTitle('Pilih jumlah data'),
                        const SizedBox(height: 10),
                        Row(
                          children: [20, 50, 100]
                              .map(
                                (dataCount) => Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      right: dataCount == 100 ? 0 : 10,
                                    ),
                                    child: ChoiceChip(
                                      label: Center(child: Text('$dataCount')),
                                      selected: _desktopHistoryCount == dataCount,
                                      showCheckmark: false,
                                      selectedColor: _accent,
                                      backgroundColor: _cardColor,
                                      labelStyle: TextStyle(
                                        color: _desktopHistoryCount == dataCount
                                            ? Colors.white
                                            : Colors.black87,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide.none,
                                      ),
                                      onSelected: (_) => setState(
                                        () => _desktopHistoryCount = dataCount,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        _buildChartCard(
                          historyDeviceReadings
                              .take(_desktopHistoryCount)
                              .toList()
                              .reversed
                              .toList(),
                          height: 220,
                        ),
                        const SizedBox(height: 18),
                        _sectionTitle(
                          'Daftar Riwayat Sensor (${historyDeviceReadings.length > _desktopHistoryCount ? _desktopHistoryCount : historyDeviceReadings.length} data terbaru)',
                        ),
                        const SizedBox(height: 8),
                        _desktopHistoryTable(
                          historyDeviceReadings
                              .take(_desktopHistoryCount)
                              .toList(),
                        ),
                      ] else if (_desktopTab == 2) ...[
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _sectionTitle('Tren 20 data sensor terakhir'),
                                const SizedBox(height: 10),
                                _buildChartCard(trend, height: 280),
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _buildSensorCard(
                                        icon: Icons.thermostat,
                                        title: 'Suhu terbaru',
                                        value:
                                            '${latest.temperature.toStringAsFixed(1)} °C',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildSensorCard(
                                        icon: Icons.water_drop,
                                        title: 'Kelembapan terbaru',
                                        value:
                                            '${latest.humidity.toStringAsFixed(1)} %',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(child: _buildSmokeCard(latest)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (_desktopTab == 3) ...[
                        const _AlarmControlCard(),
                        const SizedBox(height: 16),
                        const _ThresholdSettingsCard(),
                      ] else if (_desktopTab == 4) ...[
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _borderWarm),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: Color(0xFFF44336),
                                    size: 34,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Fire Smart Alarm',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Sistem pemantauan kondisi laboratorium menggunakan sensor suhu, kelembapan, dan asap. Data ditampilkan secara real-time untuk membantu pengguna memantau kondisi ruangan.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'Komponen: ESP32, DHT22, MQ-2, buzzer, LED, dan Firebase Firestore.',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ] else if (_desktopTab == 5) ...[
                        _buildReportSection(readings),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReportSection(List<Reading> readings) {
    final filtered = readings.where((reading) {
      final statusMatches =
          _reportStatus == 'Semua' ||
          reading.status.toLowerCase() == _reportStatus.toLowerCase();
      final range = _reportDateRange;
      final dateMatches =
          range == null ||
          (!reading.timestamp.isBefore(
                DateTime(range.start.year, range.start.month, range.start.day),
              ) &&
              reading.timestamp.isBefore(
                DateTime(range.end.year, range.end.month, range.end.day + 1),
              ));
      return statusMatches && dateMatches;
    }).toList();

    final dangerCount = filtered
        .where((r) => r.status.toLowerCase() == 'danger')
        .length;
    final warningCount = filtered
        .where((r) => r.status.toLowerCase() == 'warning')
        .length;
    final normalCount = filtered
        .where((r) => r.status.toLowerCase() == 'normal')
        .length;
    final averageTemp = filtered.isEmpty
        ? 0.0
        : filtered.map((r) => r.temperature).reduce((a, b) => a + b) /
              filtered.length;
    final averageHumidity = filtered.isEmpty
        ? 0.0
        : filtered.map((r) => r.humidity).reduce((a, b) => a + b) /
              filtered.length;
    final averageSmoke = filtered.isEmpty
        ? 0.0
        : filtered.map((r) => r.smoke).reduce((a, b) => a + b) /
              filtered.length;
    final chartReadings = filtered.reversed.toList();
    const maxChartPoints = 180;
    final chartStep = chartReadings.length > maxChartPoints
        ? (chartReadings.length / maxChartPoints).ceil()
        : 1;
    final chartPoints = chartStep == 1
        ? chartReadings
        : [
            for (var i = 0; i < chartReadings.length; i += chartStep)
              chartReadings[i],
          ];
    final visibleMobileCount = _reportVisibleCount.clamp(0, filtered.length);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 600;
    final isNarrow = screenWidth < 1100;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(
                  child: Text(
                    'Laporan Monitoring Sensor',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            const Text(
              'Ringkasan dan riwayat pembacaan sensor berdasarkan periode dan status.',
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _borderWarm),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D6D332D),
                    blurRadius: 18,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: _cardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: _accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Filter laporan',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _textDark,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Sesuaikan periode dan status sensor',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isMobile)
                        FilledButton.icon(
                          onPressed: filtered.isEmpty
                              ? null
                              : () => _exportReportPdf(filtered),
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 18,
                          ),
                          label: const Text('Ekspor PDF'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            textStyle: const TextStyle(fontSize: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickReportDateRange,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _accent,
                          side: const BorderSide(color: Color(0xFFE3C9C4)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month_rounded, size: 19),
                        label: Text(
                          _reportDateRange == null
                              ? 'Semua tanggal'
                              : '${_dateOnly(_reportDateRange!.start)} – ${_dateOnly(_reportDateRange!.end)}',
                        ),
                      ),
                      if (isMobile)
                        FilledButton.icon(
                          onPressed: filtered.isEmpty
                              ? null
                              : () => _exportReportPdf(filtered),
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 18,
                          ),
                          label: const Text('Ekspor PDF'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 15,
                            ),
                            textStyle: const TextStyle(fontSize: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: 200,
                        height: 50,
                        child: DropdownButtonFormField<String>(
                          initialValue: _reportStatus,
                          isExpanded: true,
                          style: const TextStyle(
                            fontSize: 14,
                            color: _textDark,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: 'Status sensor',
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: _accent,
                            ),
                            prefixIcon: const Icon(
                              Icons.sensors_rounded,
                              color: _accent,
                              size: 18,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFFFFBFA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3C9C4),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFFE3C9C4),
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Semua',
                              child: Text('Semua status'),
                            ),
                            DropdownMenuItem(
                              value: 'Normal',
                              child: Text('Normal'),
                            ),
                            DropdownMenuItem(
                              value: 'Warning',
                              child: Text('Warning'),
                            ),
                            DropdownMenuItem(
                              value: 'Danger',
                              child: Text('Danger'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _reportStatus = value;
                                _reportVisibleCount = 40;
                              });
                            }
                          },
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _reportDateRange = null;
                          _reportStatus = 'Semua';
                          _reportVisibleCount = 40;
                        }),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF675A57),
                          side: const BorderSide(color: Color(0xFFE8DEDC)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          textStyle: const TextStyle(fontSize: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.restart_alt_rounded, size: 19),
                        label: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 4
                    : constraints.maxWidth >= 600
                    ? 2
                    : 1;
                const gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: width,
                      child: _reportSummaryCard(
                        'Total Data',
                        '${filtered.length}',
                        Icons.sensors,
                        _accent,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _reportSummaryCard(
                        'Normal',
                        '$normalCount',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _reportSummaryCard(
                        'Warning',
                        '$warningCount',
                        Icons.warning_amber,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _reportSummaryCard(
                        'Danger',
                        '$dangerCount',
                        Icons.warning,
                        Colors.red,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 1;
                const gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    SizedBox(
                      width: width,
                      child: _reportMetricCard(
                        'Rata-rata Suhu',
                        '${averageTemp.toStringAsFixed(1)} °C',
                        Icons.thermostat,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _reportMetricCard(
                        'Rata-rata Kelembapan',
                        '${averageHumidity.toStringAsFixed(1)} %',
                        Icons.water_drop,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _reportMetricCard(
                        'Rata-rata Asap',
                        '${averageSmoke.toStringAsFixed(1)} ppm',
                        Icons.air,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Grafik Sensor',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (filtered.length < 2)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Minimal dua data diperlukan untuk menampilkan grafik.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : isNarrow
                      ? 1
                      : 2;
                  const gap = 12.0;
                  final width =
                      (constraints.maxWidth - gap * (columns - 1)) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: width,
                        child: _reportChartCard(
                          'Suhu (°C)',
                          chartPoints.map((r) => r.temperature).toList(),
                          _accent,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _reportChartCard(
                          'Kelembapan (%)',
                          chartPoints.map((r) => r.humidity).toList(),
                          Colors.blue,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _reportChartCard(
                          'Asap (ppm)',
                          chartPoints.map((r) => r.smoke).toList(),
                          Colors.deepOrange,
                        ),
                      ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 20),
            Text(
              'Detail Data (${filtered.length} data)',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Tidak ada data untuk filter yang dipilih.',
                  textAlign: TextAlign.center,
                ),
              )
            else if (MediaQuery.sizeOf(context).width < 600)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < visibleMobileCount; i++)
                    _mobileReportDataCard(filtered[i], i + 1),
                  if (visibleMobileCount < filtered.length) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() {
                          _reportVisibleCount = (_reportVisibleCount + 40).clamp(
                            0,
                            filtered.length,
                          );
                        }),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(
                          'Tampilkan 40 data lagi (${filtered.length - visibleMobileCount} tersisa)',
                        ),
                      ),
                    ),
                  ],
                ],
              )
            else ...[
              _desktopHistoryTable(filtered.take(visibleMobileCount).toList()),
              if (visibleMobileCount < filtered.length) ...[
                const SizedBox(height: 8),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _reportVisibleCount = (_reportVisibleCount + 40).clamp(
                        0,
                        filtered.length,
                      );
                    }),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text(
                      'Tampilkan 40 data lagi (${filtered.length - visibleMobileCount} tersisa)',
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _mobileReportDataCard(Reading reading, int number) {
    final status = reading.status.toUpperCase();
    final color = _statusColor(status);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Data #$number',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel(status),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatDateTime(reading.timestamp),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const Divider(height: 18),
          _reportDataRow(
            'Temperature',
            '${reading.temperature.toStringAsFixed(1)} °C',
            Icons.thermostat,
          ),
          const SizedBox(height: 8),
          _reportDataRow(
            'Humidity',
            '${reading.humidity.toStringAsFixed(1)} %',
            Icons.water_drop,
          ),
          const SizedBox(height: 8),
          _reportDataRow(
            'Smoke 💨',
            '${reading.smoke.toStringAsFixed(0)} ppm',
            Icons.air,
          ),
        ],
      ),
    );
  }

  Widget _reportDataRow(String label, String value, IconData icon) => Row(
    children: [
      Icon(icon, size: 17, color: _accent),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      Text(
        value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ],
  );

  Widget _reportSummaryCard(
    String title,
    String count,
    IconData icon,
    Color color,
  ) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _borderWarm),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 4),
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _reportMetricCard(String title, String value, IconData icon) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderWarm),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _reportChartCard(String title, List<double> values, Color color) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderWarm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 160,
              width: double.infinity,
              child: CustomPaint(painter: _ReportLinePainter(values, color)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Urutan waktu: data lama ke terbaru',
              style: TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      );

  Future<void> _exportReportPdf(List<Reading> readings) async {
    final pdf = pw.Document();
    final normal = readings
        .where((r) => r.status.toLowerCase() == 'normal')
        .length;
    final warning = readings
        .where((r) => r.status.toLowerCase() == 'warning')
        .length;
    final danger = readings
        .where((r) => r.status.toLowerCase() == 'danger')
        .length;
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
          pw.SizedBox(height: 12),
          pw.Text(
            'Ringkasan: ${readings.length} data | Normal: $normal | Warning: $warning | Danger: $danger',
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: [
              'Waktu',
              'Suhu (°C)',
              'Kelembapan (%)',
              'Asap (ppm)',
              'Status',
            ],
            data: readings
                .map(
                  (r) => [
                    _formatDateTime(r.timestamp),
                    r.temperature.toStringAsFixed(1),
                    r.humidity.toStringAsFixed(1),
                    r.smoke.toStringAsFixed(1),
                    _statusLabel(r.status.toUpperCase()),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
            ),
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

String _dateOnly(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

class _ReportLinePainter extends CustomPainter {
  _ReportLinePainter(this.values, this.lineColor);
  final List<double> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    const pad = 10.0;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.0001
        ? 1.0
        : maxValue - minValue;
    final chartHeight = size.height - pad * 2;
    final gridPaint = Paint()
      ..color = const Color(0xFFE8DEDC)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = pad + chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = pad + chartHeight * (1 - (values[i] - minValue) / range);
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
      oldDelegate.values.asMap().entries.any(
        (entry) => entry.value != values[entry.key],
      );
}

class _ThresholdSettingsCard extends StatefulWidget {
  const _ThresholdSettingsCard();

  @override
  State<_ThresholdSettingsCard> createState() => _ThresholdSettingsCardState();
}

class _ThresholdSettingsCardState extends State<_ThresholdSettingsCard> {
  String _selectedDevice = 'ESP32_001';
  bool _saving = false;

  String get _documentId =>
      _selectedDevice == 'ESP32_001' ? 'esp32-lab-01' : 'esp32-lab-02';

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
                decoration: const InputDecoration(
                  labelText: 'Batas Warning (ppm)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dangerController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Batas Danger (ppm)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _accent),
              onPressed: () {
                final warning = int.tryParse(warningController.text.trim());
                final danger = int.tryParse(dangerController.text.trim());
                if (warning == null ||
                    danger == null ||
                    warning < 1 ||
                    danger > 4095) {
                  setDialogState(
                    () => errorText = 'Masukkan angka antara 1 sampai 4095.',
                  );
                  return;
                }
                if (warning >= danger) {
                  setDialogState(
                    () => errorText =
                        'Batas Warning harus lebih kecil dari Danger.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'warning': warning,
                  'danger': danger,
                });
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
      await FirebaseFirestore.instance
          .collection('alarm-control')
          .doc(_documentId)
          .set({
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
    final ref = FirebaseFirestore.instance
        .collection('alarm-control')
        .doc(_documentId);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pengaturan Threshold Sensor',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Atur batas Warning dan Danger untuk masing-masing perangkat.',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedDevice,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pilih perangkat',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'ESP32_001', child: Text('ESP32_001')),
              DropdownMenuItem(value: 'ESP32_002', child: Text('ESP32_002')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedDevice = value);
            },
          ),
          const SizedBox(height: 14),
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
                  _settingsInfoCard(
                    Icons.check_circle,
                    'Normal',
                    'Asap di bawah $shownWarning ppm',
                    Colors.green,
                  ),
                  _settingsInfoCard(
                    Icons.warning_amber_rounded,
                    'Warning',
                    'Asap mulai $shownWarning hingga ${shownDanger - 1} ppm',
                    Colors.orange,
                  ),
                  _settingsInfoCard(
                    Icons.warning_rounded,
                    'Danger',
                    'Asap $shownDanger ppm atau lebih',
                    Colors.red,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saving || snapshot.hasError
                          ? null
                          : () => _editThreshold(shownWarning, shownDanger),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.edit, color: Colors.white),
                      label: Text(
                        _saving ? 'Menyimpan...' : 'Ubah Nilai Threshold',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Dokumen: alarm-control/$_documentId',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ),
                  if (snapshot.hasError)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Gagal membaca konfigurasi threshold.',
                        style: TextStyle(fontSize: 11, color: Colors.red),
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

class MobileSettingsScreen extends StatelessWidget {
  const MobileSettingsScreen({super.key, this.embedded = false});
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: embedded
          ? null
          : AppBar(
              backgroundColor: _background,
              elevation: 0,
              centerTitle: true,
              automaticallyImplyLeading: !embedded,
              leading: embedded
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.black87),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
              title: const Text(
                'Pengaturan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Pengaturan Alarm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Kelola alarm dan lihat aturan kondisi sensor laboratorium.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            const _AlarmControlCard(),
            const SizedBox(height: 22),
            const _ThresholdSettingsCard(),
            const SizedBox(height: 22),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: _borderWarm),
              ),
              tileColor: Colors.white,
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              subtitle: const Text('Keluar dari akun Fire Smart Alarm'),
              onTap: () async {
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text(
                      'Apakah kamu yakin ingin keluar dari akun?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Batal'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (shouldLogout == true) {
                  await FirebaseAuth.instance.signOut();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

Widget _settingsInfoCard(
  IconData icon,
  String title,
  String description,
  Color color,
) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: _borderWarm),
  ),
  child: Row(
    children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              description,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    ],
  ),
);

Widget _sideItem(
  IconData icon,
  String label,
  bool selected,
  VoidCallback onTap,
) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
  child: Material(
    color: selected ? Colors.white.withValues(alpha: 0.20) : Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      selected: selected,
      selectedTileColor: Colors.transparent,
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    ),
  ),
);

Widget _desktopHistoryTable(List<Reading> readings) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8DEDC)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: DataTable(
            columnSpacing: 18,
            headingRowColor: WidgetStateProperty.all(Colors.white),
            headingTextStyle: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
            dataTextStyle: const TextStyle(fontSize: 11, color: Colors.black87),
            dataRowMinHeight: 36,
            dataRowMaxHeight: 40,
            headingRowHeight: 38,
            columns: const [
              DataColumn(label: Text('Waktu')),
              DataColumn(label: Text('Suhu (°C)')),
              DataColumn(label: Text('Kelembapan (%)')),
              DataColumn(label: Text('Asap (ppm)')),
              DataColumn(label: Text('Status')),
            ],
            rows: readings.map((r) {
              final status = r.status.toUpperCase();
              final color = _statusColor(status);
              return DataRow(
                cells: [
                  DataCell(Text(_formatDateTime(r.timestamp))),
                  DataCell(Text(r.temperature.toStringAsFixed(1))),
                  DataCell(Text(r.humidity.toStringAsFixed(1))),
                  DataCell(Text(r.smoke.toStringAsFixed(0))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    ),
  );
}

class _AlarmControlCard extends StatefulWidget {
  const _AlarmControlCard();

  @override
  State<_AlarmControlCard> createState() => _AlarmControlCardState();
}

class _AlarmControlCardState extends State<_AlarmControlCard> {
  String _selectedDevice = 'ESP32_001';
  bool _sending = false;

  String get _documentId =>
      _selectedDevice == 'ESP32_001' ? 'esp32-lab-01' : 'esp32-lab-02';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Perintah gagal dikirim: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('alarm-control')
        .doc(_documentId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kontrol Alarm',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _selectedDevice,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pilih perangkat',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 'ESP32_001', child: Text('ESP32_001')),
              DropdownMenuItem(value: 'ESP32_002', child: Text('ESP32_002')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _selectedDevice = value);
            },
          ),
          const SizedBox(height: 10),
          StreamBuilder<DocumentSnapshot>>(
            stream: ref.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Gagal membaca kontrol: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _accent),
                );
              }

              final data = snapshot.data!.data() ?? <String, dynamic>{};
              final enabled = data['alarmEnabled'] as bool? ?? true;
              final commandStatus = data['commandStatus'] as String? ?? 'unknown';
              final buzzerStatus = data['buzzerStatus'] as bool?;
              final lastSeen = data['lastSeen'];
              final lastSeenDate = lastSeen is Timestamp
                  ? lastSeen.toDate()
                  : null;
              final online =
                  lastSeenDate != null &&
                  DateTime.now().difference(lastSeenDate).inSeconds <= 30;

              String feedbackText;
              Color feedbackColor;
              if (!online) {
                feedbackText =
                    'ESP32 tidak merespons / belum mengirim heartbeat';
                feedbackColor = Colors.red;
              } else if (commandStatus == 'pending' ||
                  commandStatus == 'received') {
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
                        enabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: enabled ? _accent : Colors.red,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              enabled
                                  ? 'Alarm diaktifkan'
                                  : 'Alarm dinonaktifkan',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Pengaturan buzzer saat kondisi Danger',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _sending
                          ? null
                          : () => _sendCommand(ref, !enabled),
                      icon: Icon(
                        enabled
                            ? Icons.notifications_off
                            : Icons.notifications_active,
                      ),
                      label: Text(
                        _sending
                            ? 'Mengirim perintah...'
                            : enabled
                            ? 'Matikan Buzzer'
                            : 'Aktifkan Buzzer',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 9, color: feedbackColor),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          feedbackText,
                          style: TextStyle(fontSize: 11, color: feedbackColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    buzzerStatus == null
                        ? 'Output buzzer: belum ada konfirmasi'
                        : 'Output buzzer ESP32: ${buzzerStatus ? "AKTIF" : "MATI"}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Dokumen: alarm-control/$_documentId',
                    style: const TextStyle(fontSize: 9, color: Colors.black45),
                  ),
                  const Text(
                    'Status Danger dan LED merah tetap mengikuti sensor meskipun buzzer dimatikan.',
                    style: TextStyle(fontSize: 9, color: Colors.red),
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

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.repository});
  final ReadingRepository repository;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _selectedCount = 20;
  String _selectedHistoryDevice = 'Semua perangkat';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Riwayat Suhu',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: StreamBuilder<List<Reading>>(
        stream: widget.repository.getReadings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: _accent),
            );
          }
          if (snapshot.hasError) {
            return _message(
              'Riwayat tidak dapat dibaca',
              'Periksa koneksi internet dan pengaturan Firebase.\n${snapshot.error}',
            );
          }
          final allReadings = snapshot.data ?? [];
          if (allReadings.isEmpty) {
            return _message(
              'Belum ada riwayat',
              'Data sensor akan tampil setelah tersedia di Firebase.',
            );
          }
          final deviceIds =
              allReadings
                  .map(
                    (reading) => reading.deviceId.trim().isEmpty
                        ? 'Perangkat tanpa ID'
                        : reading.deviceId.trim(),
                  )
                  .toSet()
                  .toList()
                ..sort();
          final selectedDevice =
              _selectedHistoryDevice == 'Semua perangkat' ||
                  deviceIds.contains(_selectedHistoryDevice)
              ? _selectedHistoryDevice
              : 'Semua perangkat';
          final filteredReadings = selectedDevice == 'Semua perangkat'
              ? allReadings
              : allReadings
                    .where(
                      (reading) =>
                          (reading.deviceId.trim().isEmpty
                              ? 'Perangkat tanpa ID'
                              : reading.deviceId.trim()) ==
                          selectedDevice,
                    )
                    .toList();
          final readings = filteredReadings.take(_selectedCount).toList();
          final chartReadings = readings.reversed.toList();
          return SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width >= 900
                      ? 1400
                      : 560,
                ),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  children: [
                    _sectionTitle('Pilih perangkat'),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedDevice,
                        isExpanded: true,
                        style: const TextStyle(fontSize: 12, color: _textDark),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _accent),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: _accent),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem(
                            value: 'Semua perangkat',
                            child: Text(
                              'Semua perangkat',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          ...deviceIds.map(
                            (id) => DropdownMenuItem(
                              value: id,
                              child: Text(
                                id,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedHistoryDevice = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    _sectionTitle('Pilih jumlah data'),
                    const SizedBox(height: 12),
                    Row(
                      children: [20, 50, 100].map((dataCount) {
                        final selected = _selectedCount == dataCount;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: dataCount == 100 ? 0 : 10,
                            ),
                            child: ChoiceChip(
                              label: Center(child: Text('$dataCount')),
                              selected: selected,
                              showCheckmark: false,
                              selectedColor: _accent,
                              backgroundColor: _cardColor,
                              labelStyle: TextStyle(
                                color: selected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide.none,
                              ),
                              onSelected: (_) {
                                setState(() => _selectedCount = dataCount);
                              },
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    _buildChartCard(chartReadings, height: 220),
                    const SizedBox(height: 24),
                    _sectionTitle('Daftar riwayat (${readings.length} data)'),
                    const SizedBox(height: 12),
                    if (MediaQuery.sizeOf(context).width >= 900)
                      _desktopHistoryTable(readings)
                    else
                      ...readings.asMap().entries.map(
                        (entry) =>
                            _buildHistoryCard(entry.value, entry.key + 1),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _sectionTitle(String title) {
  return Text(
    title,
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    ),
  );
}

Widget _message(String title, String subtitle) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sensors, size: 48, color: _accent),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Widget _buildStatusCard(Reading reading) {
  final status = reading.status.toUpperCase();
  final statusColor = _statusColor(status);
  final statusIcon = status == 'DANGER'
      ? Icons.warning_rounded
      : status == 'WARNING'
      ? Icons.warning_amber_rounded
      : Icons.check_circle;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
    decoration: BoxDecoration(
      color: _statusCardColor,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 5,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        const Icon(
          Icons.local_fire_department,
          size: 34,
          color: Color(0xFFF44336),
        ),
        const SizedBox(height: 4),
        const Text(
          'STATUS SISTEM',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 4),
        Icon(statusIcon, size: 24, color: statusColor),
        const SizedBox(height: 2),
        Text(
          _statusLabel(status),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: statusColor,
          ),
        ),
      ],
    ),
  );
}

Widget _buildSensorCard({
  required IconData icon,
  required String title,
  required String value,
}) {
  return Container(
    constraints: const BoxConstraints(minHeight: 94),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _borderWarm),
      boxShadow: [
        BoxShadow(
          color: _accent.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 25, color: _accent),
        const SizedBox(height: 5),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: _textDark,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSmokeCard(Reading reading) {
  return Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 94),
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _borderWarm),
      boxShadow: [
        BoxShadow(
          color: _accent.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(Icons.air, size: 25, color: _accent),
        const SizedBox(height: 5),
        const Text(
          'Smoke 💨',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _textDark,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${reading.smoke.toStringAsFixed(0)} ppm',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
      ],
    ),
  );
}

Widget _buildChartCard(List<Reading> readings, {required double height}) {
  final labels = readings.isEmpty
      ? <String>[]
      : <String>[
          _formatTime(readings.first.timestamp),
          if (readings.length > 2)
            _formatTime(readings[readings.length ~/ 2].timestamp),
          if (readings.length > 1) _formatTime(readings.last.timestamp),
        ];
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _borderWarm),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Suhu (°C)',
          style: TextStyle(
            fontSize: 11,
            color: _textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: height,
          width: double.infinity,
          child: readings.length < 2
              ? const Center(
                  child: Text(
                    'Grafik memerlukan minimal 2 data.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                )
              : CustomPaint(
                  painter: _TemperatureChartPainter(
                    readings.map((r) => r.temperature).toList(),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map(
                (label) => Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

class _TemperatureChartPainter extends CustomPainter {
  _TemperatureChartPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || size.isEmpty) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = (maxValue - minValue).abs() < 0.1 ? 1.0 : maxValue - minValue;
    const padding = 12.0;
    final chartHeight = size.height - padding * 2;
    final gridPaint = Paint()
      ..color = const Color(0xFFD8C9C6)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = padding + chartHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = padding + chartHeight * (1 - (values[i] - minValue) / range);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final linePaint = Paint()
      ..color = _accent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TemperatureChartPainter oldDelegate) {
    if (oldDelegate.values.length != values.length) return true;
    for (var i = 0; i < values.length; i++) {
      if (oldDelegate.values[i] != values[i]) return true;
    }
    return false;
  }
}

Widget _buildHistoryCard(Reading reading, int number) {
  final status = reading.status.toUpperCase();
  final statusColor = _statusColor(status);
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: _borderWarm),
      boxShadow: [
        BoxShadow(
          color: _accent.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Data #$number',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _textDark,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(status),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _borderWarm),
        const SizedBox(height: 12),
        _historyRow(
          icon: Icons.thermostat,
          title: 'Temperature:',
          value: '${reading.temperature.toStringAsFixed(1)} °C',
        ),
        const SizedBox(height: 10),
        _historyRow(
          icon: Icons.water_drop,
          title: 'Humidity:',
          value: '${reading.humidity.toStringAsFixed(1)} %',
        ),
        const SizedBox(height: 10),
        _historyRow(
          icon: Icons.air,
          title: 'Smoke 💨:',
          value: '${reading.smoke.toStringAsFixed(0)} ppm',
        ),
        const SizedBox(height: 10),
        _historyRow(
          icon: Icons.access_time,
          title: 'Waktu:',
          value: _formatDateTime(reading.timestamp),
        ),
      ],
    ),
  );
}

Widget _historyRow({
  required IconData icon,
  required String title,
  required String value,
}) {
  return Row(
    children: [
      Icon(icon, size: 17, color: _accent),
      const SizedBox(width: 10),
      SizedBox(
        width: 110,
        child: Text(
          title,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          value,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: _textDark,
          ),
        ),
      ),
    ],
  );
}

Color _statusColor(String status) {
  if (status == 'DANGER') return Colors.red;
  if (status == 'WARNING') return Colors.orange;
  return const Color(0xFF4CAF50);
}

String _statusLabel(String status) {
  if (status == 'DANGER') return 'Danger';
  if (status == 'WARNING') return 'Warning';
  return 'Normal';
}

String _formatDateTime(DateTime dateTime) {
  return '${dateTime.day.toString().padLeft(2, '0')}/'
      '${dateTime.month.toString().padLeft(2, '0')}/'
      '${dateTime.year} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}:'
      '${dateTime.second.toString().padLeft(2, '0')}';
}

String _formatTime(DateTime dateTime) {
  return '${dateTime.hour.toString().padLeft(2, '0')}.'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}