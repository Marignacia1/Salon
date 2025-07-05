import 'package:flutter/material.dart';
import 'calendario_compartido_service.dart';
import 'notification_service.dart';

class UnirseCalendarioDialog extends StatefulWidget {
  const UnirseCalendarioDialog({super.key});

  @override
  State<UnirseCalendarioDialog> createState() => _UnirseCalendarioDialogState();
}

class _UnirseCalendarioDialogState extends State<UnirseCalendarioDialog> {
  final _service = CalendarioCompartidoService();
  final _notificationService = NotificationService();
  final _codigoController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _buscarYUnirse() async {
    final codigo = _codigoController.text.trim().toUpperCase();
    
    if (codigo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un código de acceso'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (codigo.length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El código debe tener 8 caracteres'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final calendario = await _service.buscarPorCodigo(codigo);
      
      if (calendario == null) {
        throw Exception('Código inválido o calendario no encontrado');
      }

      await _service.unirseACalendario(codigo);

      // Notificar al propietario del calendario
      await _notificationService.sendPushNotificationToUser(
        userId: calendario.propietarioId,
        title: 'Nuevo usuario en tu calendario',
        body: 'Alguien se ha unido a tu calendario "${calendario.nombre}"',
        data: {'route': '/calendario'},
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Te has unido al calendario "${calendario.nombre}"'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Unirse a Calendario'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingresa el código de acceso que te compartieron para ver el calendario de otro usuario.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codigoController,
            decoration: const InputDecoration(
              labelText: 'Código de acceso*',
              hintText: 'Ej: ABC123XY',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.vpn_key),
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            enabled: !_isLoading,
            onChanged: (value) {
              // Convertir a mayúsculas automáticamente
              if (value != value.toUpperCase()) {
                _codigoController.value = _codigoController.value.copyWith(
                  text: value.toUpperCase(),
                  selection: TextSelection.collapsed(offset: value.length),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue[600], size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'Información:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Solo podrás ver las citas, no editarlas\n'
                  '• El propietario puede revocar el acceso\n'
                  '• Los códigos tienen fecha de expiración',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _buscarYUnirse,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal[600],
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Unirse'),
        ),
      ],
    );
  }
}