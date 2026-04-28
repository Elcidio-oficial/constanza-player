import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Página de saída de áudio.
///
/// Usa MethodChannel para consultar os dispositivos de áudio disponíveis
/// via Android AudioManager. Fallback: mostra apenas as opções padrão.
class AudioOutputPage extends StatefulWidget {
  const AudioOutputPage({super.key});

  @override
  State<AudioOutputPage> createState() => _AudioOutputPageState();
}

class _AudioOutputPageState extends State<AudioOutputPage> {
  static const _channel = MethodChannel('com.constanza.audio_output');

  List<_AudioDevice> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    // Fallback devices — sempre presentes
    final devices = <_AudioDevice>[
      _AudioDevice(
        name: 'Alto-falante',
        type: _DeviceType.speaker,
        connected: true,
      ),
    ];

    try {
      // Tenta obter dispositivos reais via platform channel
      final result = await _channel.invokeMethod<List<dynamic>>('getDevices');
      if (result != null) {
        devices.clear();
        for (final item in result) {
          final map = item as Map<dynamic, dynamic>;
          devices.add(
            _AudioDevice(
              name: map['name'] as String? ?? 'Dispositivo',
              type: _typeFromString(map['type'] as String? ?? 'speaker'),
              connected: map['connected'] as bool? ?? false,
            ),
          );
        }
      }
    } on MissingPluginException {
      // Platform channel não implementado — usa fallback
    } catch (e) {
      debugPrint('[AudioOutput] getDevices error: $e');
    }

    if (mounted) {
      setState(() {
        _devices = devices;
        _loading = false;
      });
    }
  }

  static _DeviceType _typeFromString(String type) => switch (type) {
    'bluetooth' || 'bluetooth_a2dp' => _DeviceType.bluetooth,
    'wired' || 'wired_headset' || 'wired_headphones' => _DeviceType.wired,
    'usb' => _DeviceType.usb,
    'hdmi' => _DeviceType.hdmi,
    _ => _DeviceType.speaker,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Saída de Áudio'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _devices.length + 1, // +1 for info card
              itemBuilder: (context, index) {
                if (index == _devices.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.3,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: colors.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'A seleção do dispositivo de saída é gerida pelo '
                              'sistema Android. Conecte fones ou colunas Bluetooth '
                              'para alternar automaticamente.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurface.withValues(alpha: 0.45),
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final device = _devices[index];
                final isBt = device.type == _DeviceType.bluetooth;
                final isActive = device.connected;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: colors.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    border: Border.all(
                      color: isActive
                          ? colors.primary.withValues(alpha: 0.3)
                          : colors.outline.withValues(alpha: 0.06),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: isActive
                            ? colors.primary.withValues(alpha: 0.12)
                            : colors.onSurface.withValues(alpha: 0.06),
                      ),
                      child: Icon(
                        device.type.icon,
                        color: isActive
                            ? colors.primary
                            : colors.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    title: Text(
                      device.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      device.type.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    trailing: isActive
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: colors.primary.withValues(alpha: 0.1),
                            ),
                            child: Text(
                              isBt ? 'Conectado' : 'Ativo',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () {
          setState(() => _loading = true);
          _loadDevices();
        },
        backgroundColor: colors.primaryContainer,
        child: Icon(Icons.refresh_rounded, color: colors.onPrimaryContainer),
      ),
    );
  }
}

enum _DeviceType {
  speaker(Icons.phone_android_rounded, 'Alto-falante do dispositivo'),
  bluetooth(Icons.bluetooth_audio_rounded, 'Bluetooth'),
  wired(Icons.headphones_rounded, 'Conectado via cabo'),
  usb(Icons.usb_rounded, 'USB Audio'),
  hdmi(Icons.tv_rounded, 'HDMI');

  const _DeviceType(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _AudioDevice {
  const _AudioDevice({
    required this.name,
    required this.type,
    required this.connected,
  });

  final String name;
  final _DeviceType type;
  final bool connected;
}
