import 'package:flutter/material.dart';

import '../services/legal_terms_service.dart';

/// Pantalla obligatoria que se muestra la primera vez que cada
/// usuario entra (o de nuevo si el texto de los términos cambió de
/// versión). No se puede saltear ni cerrar con el botón atrás: hay
/// que leer y aceptar para continuar.
class LegalTermsScreen extends StatefulWidget {
  final String username;
  final VoidCallback onAccepted;

  const LegalTermsScreen({
    super.key,
    required this.username,
    required this.onAccepted,
  });

  @override
  State<LegalTermsScreen> createState() => _LegalTermsScreenState();
}

class _LegalTermsScreenState extends State<LegalTermsScreen> {
  bool _checked = false;
  bool _accepting = false;
  bool _reachedEnd = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Términos de uso y confidencialidad'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.metrics.pixels >=
                      notification.metrics.maxScrollExtent - 24) {
                    if (!_reachedEnd) setState(() => _reachedEnd = true);
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kLegalTermsText,
                        style: const TextStyle(fontSize: 13.5, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_reachedEnd)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Deslizá hasta el final del texto para poder aceptar.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    CheckboxListTile(
                      value: _checked,
                      onChanged: _reachedEnd
                          ? (v) => setState(() => _checked = v ?? false)
                          : null,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Leí y acepto los términos de uso y confidencialidad.',
                        style: TextStyle(fontSize: 13.5),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (_checked && !_accepting)
                            ? () async {
                                setState(() => _accepting = true);
                                await LegalTermsService.instance
                                    .accept(widget.username);
                                widget.onAccepted();
                              }
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _accepting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Aceptar y continuar'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
