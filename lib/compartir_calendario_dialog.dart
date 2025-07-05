import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'calendario_compartido_service.dart';
import 'contacto_model.dart';

class CompartirCalendarioDialog extends StatefulWidget {
  const CompartirCalendarioDialog({super.key});

  @override
  State<CompartirCalendarioDialog> createState() => _CompartirCalendarioDialogState();
}

class _CompartirCalendarioDialogState extends State<CompartirCalendarioDialog> {
  final _service = CalendarioCompartidoService();
  final _nombreController = TextEditingController();
  int _diasValidez = 30;
  bool _isLoading = false;
  CalendarioCompartido? _calendarioCreado;

  @override
  void dispose() {
    _nombreController.dispose();
    super.dispose();
  }

  Future<void> _crearCalendario() async {
    if (_nombreController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa un nombre para el calendario'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final calendario = await _service.crearCalendarioCompartido(
        nombre: _nombreController.text.trim(),
        diasValidez: _diasValidez,
      );

      setState(() {
        _calendarioCreado = calendario;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calendario compartido creado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _copiarCodigo() {
    if (_calendarioCreado != null) {
      Clipboard.setData(ClipboardData(text: _calendarioCreado!.codigoAcceso));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Código copiado al portapapeles'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Compartir Calendario'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_calendarioCreado == null) ...[
              const Text(
                'Crea un código de acceso para compartir tu calendario con otros usuarios.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del calendario*',
                  hintText: 'Ej: Salón de María',
                  border: OutlineInputBorder(),
                ),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),
              const Text('Validez del código:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _diasValidez,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 7, child: Text('7 días')),
                  DropdownMenuItem(value: 15, child: Text('15 días')),
                  DropdownMenuItem(value: 30, child: Text('30 días')),
                  DropdownMenuItem(value: 60, child: Text('60 días')),
                  DropdownMenuItem(value: 90, child: Text('90 días')),
                ],
                onChanged: _isLoading ? null : (value) {
                  setState(() => _diasValidez = value!);
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[600]),
                        const SizedBox(width: 8),
                        const Text(
                          '¡Calendario creado!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Nombre: ${_calendarioCreado!.nombre}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Código: '),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            _calendarioCreado!.codigoAcceso,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _copiarCodigo,
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copiar código',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Válido hasta: ${_calendarioCreado!.fechaExpiracionFormateada}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
                        Icon(Icons.info, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text(
                          'Cómo compartir:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Comparte este código con otros usuarios'),
                    const Text('2. Ellos deben ir a "Unirse a Calendario"'),
                    const Text('3. Ingresar el código para ver tus citas'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_calendarioCreado == null) ...[
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: _isLoading ? null : _crearCalendario,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[600],
              foregroundColor: Colors.white,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Crear Código'),
          ),
        ] else ...[
          TextButton(
            onPressed: _copiarCodigo,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.copy),
                SizedBox(width: 4),
                Text('Copiar'),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ],
    );
  }
}