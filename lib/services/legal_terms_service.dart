import '../models/legal_acceptance.dart';
import 'audit_service.dart';
import 'database_helper.dart';
import 'sync_service.dart';

/// Cada vez que se cambia el texto de los términos (kLegalTermsText),
/// hay que subir esta versión: eso hace que TODOS los usuarios, aunque
/// ya hubieran aceptado antes, tengan que volver a aceptar la vez
/// siguiente que entren.
const String kLegalTermsVersion = '1.0';

const String kLegalTermsText = '''
TÉRMINOS DE USO Y CONFIDENCIALIDAD DE LA INFORMACIÓN

Sistema "Parque Automotor" — gestión y control de flota de vehículos y choferes.

1. CARÁCTER DE LA INFORMACIÓN
Los datos a los que se accede a través de esta aplicación (vehículos, choferes, documentación, kilometrajes, mantenimiento, combustible y cualquier otro dato cargado) son información interna de uso exclusivamente laboral/administrativo. No constituyen información de acceso público.

2. USO PERMITIDO
El acceso a esta aplicación se otorga de forma individual, mediante usuario y contraseña personales e intransferibles, exclusivamente para el desempeño de las tareas asignadas. Cada usuario es responsable de todo lo realizado bajo sus credenciales.

3. PROHIBICIÓN DE DIVULGACIÓN
Queda expresamente prohibido, salvo autorización expresa de la autoridad competente:
  • Extraer, copiar, fotografiar, capturar pantalla o reproducir por cualquier medio la información contenida en esta aplicación con fines ajenos a las tareas asignadas.
  • Compartir, enviar, publicar o divulgar total o parcialmente esa información a terceros ajenos a la organización, por cualquier vía (mensajería, redes sociales, correo electrónico u otra).
  • Compartir las credenciales de acceso (usuario y contraseña) con terceros, incluso otros empleados.
  • Utilizar la información para fines distintos a los estrictamente laborales.

4. TRAZABILIDAD
El sistema registra qué usuario realiza cada carga, modificación, archivado o eliminación, junto con la fecha y hora correspondiente. Este registro puede utilizarse como respaldo ante cualquier uso indebido detectado.

5. CONSECUENCIAS DEL INCUMPLIMIENTO
El incumplimiento de lo aquí establecido puede dar lugar a las sanciones disciplinarias, administrativas, civiles y/o penales que correspondan según la normativa vigente aplicable al organismo y a la relación laboral del usuario.

6. ACEPTACIÓN
Al presionar "Leí y acepto" se deja constancia de que el usuario identificado con sus credenciales ha leído, comprendido y aceptado los términos aquí expuestos, quedando dicha aceptación registrada con usuario, fecha y hora.
''';

class LegalTermsService {
  LegalTermsService._internal();
  static final LegalTermsService instance = LegalTermsService._internal();

  /// true si este usuario ya aceptó la versión vigente de los términos.
  Future<bool> hasAccepted(String username) async {
    final acceptance =
        await DatabaseHelper.instance.getLegalAcceptance(username);
    return acceptance != null && acceptance.version == kLegalTermsVersion;
  }

  /// Registra la aceptación: local, en la nube (si está disponible) y
  /// en el historial de auditoría, con usuario, fecha y hora.
  Future<void> accept(String username) async {
    final acceptance = LegalAcceptance(
      username: username,
      version: kLegalTermsVersion,
      acceptedAt: DateTime.now(),
    );
    await DatabaseHelper.instance.upsertLegalAcceptance(acceptance);
    await SyncService.instance.pushLegalAcceptance(acceptance);
    await AuditService.log(
      action: 'Aceptó los Términos de Uso y Confidencialidad',
      entityType: 'legal',
      entityLabel: 'Versión $kLegalTermsVersion',
    );
  }
}
