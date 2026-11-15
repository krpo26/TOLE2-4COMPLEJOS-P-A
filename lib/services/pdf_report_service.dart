import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/driver.dart';
import '../models/vehicle.dart';

/// Genera un reporte PDF con el estado general de la flota: listado
/// de vehículos y choferes con su estado de alerta. Disponible para
/// cualquier usuario logueado (god o común), ya que es solo lectura.
class PdfReportService {
  static Future<void> generateAndShare({
    required List<Vehicle> vehicles,
    required List<Driver> drivers,
    String complexName = 'PARQUE AUTOMOTOR BENJAMIN PAZ',
  }) async {
    final doc = pw.Document();
    final now = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    final logoBytes = await rootBundle.load('assets/images/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(logoImage, height: 50, width: 50),
                pw.SizedBox(width: 12),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('PARQUE AUTOMOTOR — $complexName',
                          style: pw.TextStyle(
                              fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Servicio Penitenciario de Tucumán',
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text('Reporte de estado de flota — generado $now',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Divider(),
          ],
        ),
        build: (context) => [
          pw.Text('Vehículos (${vehicles.length})',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Interno', 'Patente', 'Km actual', 'Próx. service', 'Estado'],
            data: vehicles.map((v) {
              final status = switch (v.maintenanceStatus) {
                MaintenanceStatus.ok => 'OK',
                MaintenanceStatus.warning => 'Próximo',
                MaintenanceStatus.overdue => 'VENCIDO',
              };
              return [
                v.internalNumber,
                v.plate,
                '${v.currentMileage}',
                '${v.nextServiceMileage}',
                status,
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Choferes (${drivers.length})',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
            cellAlignment: pw.Alignment.centerLeft,
            headers: ['Nombre', 'DNI', 'Categoría', 'Vence carnet', 'Estado'],
            data: drivers.map((d) {
              final status = switch (d.licenseStatus) {
                LicenseStatus.ok => 'OK',
                LicenseStatus.warning => 'Por vencer',
                LicenseStatus.expired => 'VENCIDO',
              };
              return [
                d.fullName,
                d.documentId,
                d.licenseCategory,
                DateFormat('dd/MM/yyyy').format(d.licenseExpiration),
                status,
              ];
            }).toList(),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename:
          'reporte_flota_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
    );
  }
}
