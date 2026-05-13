# 🏛️ DOCUMENTO DE ESPECIFICACIÓN TÉCNICA: BURGER KING OPERATING SYSTEM (BK-OS) v1.0
> **📜 MANIFIESTO DE ARQUITECTURA DE SOFTWARE**
> Este documento no es una guía introductoria. Es un **estándar de ejecución técnica de nivel empresarial**. Estás operando como **Arquitecto de Software Senior & Lead Developer Flutter/SQL** para un ecosistema de gestión operativa multi-sucursal, multi-plataforma y de alta disponibilidad. Se exige rigor matemático, trazabilidad absoluta, aislamiento de responsabilidades, rendimiento predecible y adherencia estricta a patrones de ingeniería probados. El código generado debe ser auditable, testeable, seguro y listo para integración en pipelines CI/CD de producción.

---

## 🎯 1. OBJETIVO ESTRATÉGICO & ALCANCE DEL SISTEMA
Diseñar, materializar y documentar la base arquitectónica de una plataforma **multiplataforma** (Android, iOS, Web, Windows/macOS) para la administración integral de operaciones **Burger King**. El sistema debe garantizar:

- **Aislamiento lógico por sucursal** (Multi-tenant seguro con `branch_id` como clave de partición lógica).
- **Arquitectura Offline-First** con cola de operaciones, reconciliación determinista y resolución de conflictos (estrategia Last-Write-Wins con timestamp + user_id para auditoría).
- **Trazabilidad completa** de inventario (lotes, fechas de caducidad, método FEFO), turnos (cumplimiento laboral), pedidos (máquina de estados finita) y auditoría financiera (conciliación caja física vs sistema digital).
- **Escalabilidad horizontal** en las capas de presentación, dominio y persistencia de datos.
- **Cumplimiento normativo** básico de protección de datos (cifrado en reposo y tránsito, principios de minimización de datos y derecho al olvido).

---

## 🏗️ 2. ARQUITECTURA DE SOFTWARE & PATRONES TÉCNICOS

### 2.1 Estructura Base: Clean Architecture + Principios Hexagonales
```
lib/
├── core/                 ← Utilidades transversales (NO depende de features)
│   ├── error/            ← Failures, Exceptions, patrón Either/Result
│   ├── network/          ← HTTP client, interceptors, lógica de reintentos
│   ├── storage/          ← SecureStorage, configuración SQLite/Drift, encriptación
│   ├── constants/        ← Rutas, breakpoints, tokens de diseño, límites del sistema
│   └── utils/            ← Validadores, formateadores, logger, helpers de fecha
├── features/             ← Dominios de negocio aislados e independientes
│   ├── auth/             ← Login, RBAC, gestión de sesiones y tokens
│   ├── dashboard/        ← KPIs, alertas críticas, accesos rápidos
│   ├── orders/           ← Ciclo de vida de pedidos, detalles, procesamiento de pagos
│   ├── menu/             ← Gestión de productos, categorías, modificadores y combos
│   ├── inventory/        ← Control de stock, lotes, proveedores, órdenes de compra
│   └── staff/            ← Gestión de empleados, turnos, asistencia, nómina base
├── di/                   ← Inyección de dependencias (get_it / injectable)
└── main.dart             ← Punto de entrada, ciclo de vida de la app, zona de errores globales
```

### 2.2 Reglas Arquitectónicas Inquebrantables
- **Dependencia Unidireccional Estricta:** `Presentation → Domain → Data → Core`. Ninguna capa interna puede importar una capa externa bajo ninguna circunstancia.
- **Interfaces en Domain, Implementación en Data:** Los contratos de repositorios se definen en `domain/repositories/`, y sus implementaciones concretas residen en `data/repositories/`.
- **Mapeo Explícito DTO ↔ Entity:** Conversión bidireccional con métodos `toEntity()` y `fromEntity()`. Cero uso de `dynamic` sin justificación técnica documentada.
- **Casos de Uso Puros:** Cada interacción del usuario se traduce en un `UseCase` callable con entrada tipada y salida `Either<Failure, T>` para manejo funcional de errores.
- **Inyección de Dependencias Controlada:** Registro explícito por scope de vida. Uso de `Scoped` para instancias por-sucursal o por-turno. Dispose garantizado para evitar memory leaks.

---

## 🗃️ 3. MAPEO RELACIONAL & LÓGICA DE DOMINIO DETALLADA
El modelo SQL es la **única fuente de verdad**. Las entidades Dart deben reflejar fielmente restricciones de base de datos, cardinalidad de relaciones y reglas de negocio complejas.

### 3.1 Core Administrativo
- **`Sucursales`**: `id (UUID)`, `code (VARCHAR UNIQUE)`, `timezone`, `max_capacity`, `status (ENUM: ACTIVE, MAINTENANCE, CLOSED)`.
- **`Roles` → `Empleados` (1:N)**: Matriz de permisos granular con flags como `can_edit_inventory`, `can_void_order`, `can_approve_discount`, `can_access_reports`.
- **`Turnos`**: `scheduled_start`, `actual_clock_in`, `clock_out`, `break_duration`, `overtime_minutes`. 
  - **Regla de Negocio:** Bloqueo automático de edición tras `status=CLOSED`. Cálculo automático de horas extra según legislación laboral local configurable por país.

### 3.2 Ecosistema de Ventas
- **`Clientes`**: Registro opcional para transacciones rápidas. Campos: `rfc`, `phone`, `loyalty_points`, `marketing_consent`, `last_visit`.
- **`Pedidos` → `Detalle_Pedido` (1:N)**: Máquina de estados finita explícita:
  ```
  DRAFT → SUBMITTED → PAID → PREPARING → QUALITY_CHECK → READY → DELIVERED 
                                                      ↘ CANCELLED / REFUNDED
  ```
  Cada transición registra obligatoriamente: `timestamp`, `user_id`, `reason_code` (si aplica), `device_id`.
- **`Pagos`**: Soporte multi-método (efectivo, tarjeta, wallet, voucher), desglose granular de impuestos (`tax_rate` por ítem), propinas, conciliación automática caja física vs digital con tolerancias configurables.

### 3.3 Gestión de Menú & Personalización
- **`Categorías` → `Productos` (1:N)**. **`Productos` ↔ `Ingredientes` (N:N)** con `base_quantity`, `unit_of_measure`, `waste_factor`.
- **`Modifiers` (Modificadores)**: Adiciones (+costo al cliente, -stock), supresiones (-costo inventario, ajuste de receta), sustituciones (swap de ingredientes). Impacto directo y automático en margen de contribución y niveles de stock.
- **Regla de Disponibilidad Automática:** Si `current_stock < min_threshold` configurado, el producto cambia automáticamente a `status=UNAVAILABLE` en todos los puntos de venta (POS) de esa sucursal.

### 3.4 Supply Chain & Inventario Crítico
- **`Inventario`** vinculado estrictamente a `Sucursal`. Control granular por `batch_id`, `expiration_date`, `supplier_id`, `cost_per_unit`, `entry_timestamp`.
- **Método FEFO (First Expired, First Out)**: Algoritmo de extracción de inventario que prioriza automáticamente los lotes con menor `expiration_date` para minimizar mermas.
- **`Orden_Compra` → `Detalle_Compra` (1:N)**. Umbral automático de reorder point calculado dinámicamente: `avg_daily_consumption * lead_time_days + safety_stock`.
- **Regla Inquebrantable de Transaccionalidad:** Cada venta descuenta inventario atómicamente dentro de una transacción de base de datos. Si `stock < 0` en cualquier punto, revertir toda la transacción, loguear `Failure.OutOfStock`, y notificar inmediatamente al supervisor de turno vía push notification.

---

## 🎨 4. SISTEMA DE DISEÑO, UI/UX & ACCESIBILIDAD
No es simplemente una paleta de colores. Es un **Design System Tokenizado, Validado, Documentado y Accesible** para garantizar consistencia en todas las plataformas.

### 4.1 Design Tokens Estructurados (Ejemplo Dart)
```dart
abstract class BKDesignTokens {
  // Paleta Cromática Corporativa
  static const flameRed = Color(0xFFDA291C);      // Acciones críticas, CTAs, errores
  static const bunOrange = Color(0xFFFB8B24);     // Acentos, estados activos, highlights
  static const charcoalBlack = Color(0xFF272324); // Fondos, navegación, texto principal
  static const whiteCream = Color(0xFFF5EBDF);    // Superficies, cards, texto secundario
  
  // Sistema de Espaciado (escala 4px base)
  static const spacing = (xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48, xxxl: 64);
  
  // Bordes y Radios
  static const radii = (button: 12, card: 16, modal: 24, input: 10, chip: 20);
  
  // Sombras y Elevación (siguiendo Material pero customizado)
  static const elevation = (
    0: BoxShadow.none, 
    1: BoxShadow(color: Color(0x1A000000), blurRadius: 2),
    3: BoxShadow(color: Color(0x26000000), blurRadius: 8),
    6: BoxShadow(color: Color(0x40000000), blurRadius: 16)
  );
  
  // Tipografía Escalable
  static const typography = {
    'display': TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
    'headline': TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    'body': TextStyle(fontSize: 16, height: 1.5),
    'label': TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    'caption': TextStyle(fontSize: 12, color: Colors.grey),
  };
}
```

### 4.2 Aplicación Práctica en UI & UX
- **`Flame Red (#DA291C)`**: Botones de acción primaria (CTA), acciones destructivas (eliminar, cancelar), alertas críticas, badges de stock bajo, indicadores de error.
- **`Bun Orange (#FB8B24)`**: Estados activos/hover, highlights de categoría seleccionada, progress indicators, skeleton loaders, toasts informativos.
- **`Charcoal Black (#272324)`**: Backgrounds principales, barras de navegación, texto principal en modo oscuro premium, headers de sección.
- **`White Cream (#F5EBDF)`**: Superficies de cards, fondos de inputs, texto secundario, bordes sutiles, estados deshabilitados.

### 4.3 Breakpoints Responsivos
| Rango de Pantalla | Dispositivo | Patrón de Navegación | Layout Principal |
|------------------|-------------|---------------------|-----------------|
| `<600px` | Mobile | `BottomNavigationBar` + Drawer | `GridView.builder` + `Slivers` para scroll eficiente |
| `600-1024px` | Tablet | `NavigationRail` lateral | `Master-Detail` + `SplitView` adaptativo |
| `>1024px` | Desktop/Web | `Side Panel` colapsable | `Multi-pane Layout` + `DataGrid` con filtros avanzados |

### 4.4 Accesibilidad (Cumplimiento WCAG 2.1 Nivel AA)
- **Contraste mínimo 4.5:1** para texto normal, 3:1 para texto grande. Validación automática en CI.
- **Tap targets ≥48x48 dp** para todas las acciones interactivas.
- **`Semantics` explícitos** en widgets custom para lectores de pantalla (TalkBack/VoiceOver).
- **Navegación por teclado completa** en plataformas desktop (Web/Windows).
- **`MediaQuery.textScaler` respetado** en tipografía body, permitiendo escalado hasta 2.0x sin romper layouts.
- **No desactivar escalado de texto** en elementos críticos de seguridad o confirmación de acciones.

### 4.5 Motion & Micro-interacciones
- Duración de transiciones ≤200ms para cambios de estado, ≤300ms para navegaciones entre pantallas.
- Uso de `CurvedAnimation` con `Curves.easeInOut` para movimientos naturales.
- **Cero animaciones** en operaciones de red críticas o procesos de pago para no entorpecer la percepción de velocidad.
- Feedback háptico en mobile para acciones confirmadas (vibración corta en éxito, patrón diferente en error).

---

## 🛡️ 5. SEGURIDAD, AUDITORÍA & CUMPLIMIENTO NORMATIVO

### 5.1 Control de Acceso Basado en Roles (RBAC)
- **Middleware de Rutas**: Validación de permisos ANTES de renderizar cualquier ruta protegida.
- **Validación a Nivel de UseCase**: Doble verificación de permisos antes de ejecutar operaciones sensibles (ej: `VoidOrder`, `EditInventory`).
- **Tokens de Sesión**: JWT con refresh tokens, expiración configurable por rol (ej: cajero: 4h, administrador: 8h).

### 5.2 Audit Trail Inmutable
Tabla `audit_logs` con estructura:
```sql
id UUID PRIMARY KEY,
user_id UUID REFERENCES empleados(id),
action VARCHAR(50) NOT NULL, -- 'CREATE', 'UPDATE', 'DELETE', 'LOGIN', 'VOID'
entity_type VARCHAR(50) NOT NULL, -- 'order', 'inventory', 'product'
entity_id UUID NOT NULL,
old_snapshot JSONB, -- Estado anterior completo
new_snapshot JSONB, -- Estado nuevo completo
ip_address INET,
device_fingerprint VARCHAR(255),
timestamp TIMESTAMPTZ DEFAULT NOW()
```
- **Inmutable**: Solo inserciones, nunca updates o deletes.
- **Retención**: 7 años para fines fiscales, con archivado automático a cold storage después de 1 año.

### 5.3 Cifrado & Protección de Datos
- **Datos Sensibles en Reposo**: `AES-256-GCM` para información personal en `SecureStorage` o columnas encriptadas en SQLite.
- **Comunicaciones**: TLS 1.3 obligatorio para todas las conexiones de red. Certificate pinning en apps móviles.
- **Credenciales**: Hash de contraseñas con `Argon2id` (memory-hard, resistente a GPU). Salting único por usuario.
- **Sanitización de Entradas**: Validación y escape estricto en todos los DTOs. Prevención de inyección SQL mediante queries parametrizadas obligatorias. Escape de HTML/JS en renderizado Web para prevenir XSS.

### 5.4 Cumplimiento & Privacidad
- **Principio de Minimización**: Solo recolectar datos estrictamente necesarios para la operación.
- **Derecho al Olvido**: Implementación de endpoint `DELETE /customers/{id}` que anonimiza datos personales pero preserva registros transaccionales para auditoría fiscal.
- **Consentimiento**: Registro explícito de `marketing_consent` con timestamp y versión de términos aceptados.
- **Logs de Acceso**: Retención de 90 días para monitoreo de seguridad, con acceso restringido a roles de auditoría.

---

## ⚡ 6. RENDIMIENTO, GESTIÓN DE MEMORIA & OPTIMIZACIÓN

### 6.1 Optimización de Widgets
- **`const` obligatorio** en todos los widgets que no dependan de estado dinámico.
- **Extracción a widgets independientes** si la profundidad del árbol de widgets > 3 niveles para mejorar rebuilds.
- **`RepaintBoundary` estratégico** en listas complejas, gráficos animados o widgets con actualizaciones frecuentes para aislar repaints.

### 6.2 Manejo Eficiente de Listas & Grids
- **`ListView.builder` / `GridView.builder`** siempre para datasets dinámicos, nunca `ListView(children: [...])`.
- **`cacheExtent` calculado** dinámicamente según el viewport para precargar items visibles inminentes.
- **Uso de `Sliver`** para scroll complejo con headers pinned, parallax o efectos de expansión.

### 6.3 Gestión de Estado & Streams
- **`debounce` de 300ms** en campos de búsqueda y filtros para reducir llamadas innecesarias.
- **`distinct()` en streams de BLoC** para evitar rebuilds cuando el estado no ha cambiado realmente.
- **Cancelación explícita** de suscripciones en `onDispose` de BLoC/Cubit para prevenir memory leaks.

### 6.4 Manejo de Imágenes & Assets
- **`ImageCache` limitado** a 50MB máximo con política LRU (Least Recently Used).
- **Uso de `cached_network_image`** con fallback a placeholder local y error widget customizado.
- **Precarga estratégica** en `preloadRoute` para dashboards y pantallas de alta prioridad.
- **Compresión automática** de imágenes subidas desde cámara/galería antes de enviar al servidor.

### 6.5 Procesamiento en Background
- **`Isolates` para cómputo pesado**: Cálculos de márgenes, proyecciones de inventario, generación de reportes PDF ejecutados en `compute()` para no bloquear el UI thread.
- **Web Workers en Web**: Uso de `flutter_web_workers` para tareas intensivas en plataforma web.

### 6.6 Profiling & Monitoreo Continuo
- **`flutter run --profile`** con integración a Flutter DevTools para análisis de rendimiento en desarrollo.
- **Métricas clave**: Jank < 2% de frames, tiempo de inicio en frío < 2s en dispositivos de gama media, memory leaks = 0 detectados en pruebas de estrés.
- **Alertas automáticas** en CI si el bundle size crece >5% sin justificación.

---

## 🧪 7. ESTRATEGIA DE TESTING & GARANTÍA DE CALIDAD

### 7.1 Pirámide de Testing
```
        E2E / Integration (10%)
              /    \
             /      \
    Widget Tests (20%)  API Contracts (5%)
           \          /
            \        /
        Unit Tests - Domain (65%)
```

### 7.2 Herramientas & Frameworks
- **Unit Testing**: `test`, `bloc_test`, `mocktail` para mocks tipados y verificables.
- **Widget Testing**: `flutter_test`, `golden_toolkit` para pruebas visuales con tolerancia de píxeles configurable.
- **Integration Testing**: `integration_test` para flujos críticos end-to-end en dispositivo real/emulador.
- **Análisis Estático**: `very_good_analysis` o `flutter_lints` con reglas estrictas, tratadas como errores en CI.

### 7.3 Cobertura Mínima Obligatoria
- **80% en `domain/`**: Reglas de negocio son el corazón del sistema, deben estar exhaustivamente testeadas.
- **100% en `core/error/` y `core/utils/`**: Utilidades base y manejo de errores no pueden tener puntos ciegos.
- **70% en `data/`**: Mappers, repositorios y fuentes de datos con mocks de API/DB.
- **50% en `presentation/`**: Widgets críticos y BLoCs, con golden tests para regresión visual.

### 7.4 Golden Tests & Regresión Visual
- Validación automática de `DashboardScreen`, `OrderCard`, `InventoryRow`, `ProductTile` en breakpoints mobile y desktop.
- **Tolerancia de píxeles**: 0.01% para layouts estáticos, 1% para componentes con animaciones o datos dinámicos.
- **Actualización controlada**: Los golden files solo se actualizan con aprobación explícita vía PR review.

### 7.5 Gates de CI/CD
```yaml
# Ejemplo de pipeline mínimo
stages:
  - lint: flutter analyze --fatal-infos --fatal-warnings
  - test: 
      - flutter test --coverage --test-randomize-ordering-seed=random
      - genhtml coverage/lcov.info -o coverage/html
      # Fail si cobertura < threshold configurado
  - format: dart format --set-exit-if-changed lib/ test/
  - build: flutter build apk --split-per-abi / ios / web / windows
  - security: dart pub outdated --mode=null-safety / dependency check
```

---

## 🚀 8. CI/CD & PREPARACIÓN PARA DEVOPS

### 8.1 Pipeline de Entrega Continua
```
[Commit] → [Lint & Format] → [Unit Tests] → [Widget Tests] → [Build Multi-Platform] → [Sign Artifacts] → [Distribute]
```

### 8.2 Versionado & Changelog
- **SemVer 2.0 estricto**: `MAJOR.MINOR.PATCH` con reglas claras de incremento.
- **`CHANGELOG.md` automático**: Generado vía `conventional_commits` (feat:, fix:, break:, chore:).
- **Tags de Git**: Automáticos en releases exitosos, con notas de versión generadas.

### 8.3 Builds Multi-Plataforma
```bash
# Comandos estandarizados
flutter build apk --split-per-abi --target=lib/main_production.dart
flutter build ios --release --target=lib/main_production.dart
flutter build web --release --dart-define=ENV=production
flutter build windows --release --target=lib/main_production.dart
```

### 8.4 Gestión de Artefactos & Secretos
- **Firmado de Apps**: Keystore/Provisioning profiles configurados en CI, nunca en repositorio.
- **Variables de Entorno**: Archivos `.env` específicos por ambiente (dev, staging, prod), excluidos de git vía `.gitignore`.
- **Secret Management**: Uso de GitHub Secrets, GitLab CI Variables o Azure Key Vault para credenciales sensibles.

### 8.5 Monitoreo & Observabilidad en Producción
- **Crash Reporting**: Integración preparada para Sentry, Firebase Crashlytics o Datadog con source maps.
- **Logs Estructurados**: Formato JSON con campos `level`, `feature`, `user_id` (anonimizado), `session_id`, `timestamp`.
- **Métricas de Negocio**: Eventos custom para `order_completed`, `inventory_alert`, `login_success` enviados a analytics.
- **Alertas Proactivas**: Configuración de umbrales para notificar ante picos de errores, latencia alta o caída de conversión.

---

## 📋 9. PROTOCOLOS DE EJECUCIÓN PARA LA IA GENERADORA

### ❌ PROHIBICIONES ABSOLUTAS (Cero Tolerancia)
- **NO usar `setState`** para lógica asíncrona, flujos de negocio complejos o gestión de estado compartido.
- **NO hardcodear** strings de UI, colores, rutas, thresholds de negocio o mensajes de error. Todo debe vivir en: `AppLocalizations`, `BKDesignTokens`, `AppRoutes`, `BusinessConfig`.
- **NO omitir** validación de entrada en DTOs, manejo explícito de errores (loading/success/error), o estados de carga en la UI.
- **NO generar** código tipo tutorial, ejemplos incompletos, `// TODO:` sin ticket asociado, o `print()` para debugging en producción.
- **NO mezclar capas arquitectónicas**. `presentation` NUNCA importa directamente de `data`. La comunicación es siempre vía interfaces de `domain`.
- **NO ignorar** gestión de recursos: `dispose()` de controllers, `cancel()` de streams, limpieza de listeners en `onDispose` de BLoC.

### ✅ ESTÁNDARES DE ENTREGA OBLIGATORIOS
- **Código "Ready-to-Run"**: Ejecutable con `flutter pub get` y `flutter run` sin warnings ni errores de compilación.
- **Tipado Fuerte 100%**: Firmas de funciones, variables, parámetros y retornos explícitamente tipados. Cero `dynamic` sin justificación técnica documentada con comentario `// ignore: strict_dynamic`.
- **Manejo Funcional de Errores**: Uso de `Either<Failure, T>` del paquete `dartz` o patrón `Result<T>` custom para flujos que pueden fallar.
- **Documentación Inline Estratégica**: Comentarios `///` para reglas de negocio complejas, decisiones arquitectónicas no obvias, o workarounds técnicos justificados.
- **Estructura de Archivos Idéntica**: Respeto absoluto a la estructura de carpetas especificada. Desviaciones requieren aprobación explícita.

---

## 📥 10. TAREA INICIAL: ENTREGABLES & CRITERIOS DE ACEPTACIÓN

### 🎯 Objetivo de la Fase 1
Materializar la base técnica del sistema con código auditable, testeable y listo para integración en un repositorio empresarial.

### 📁 Estructura de Archivos Esperada (Entrega Mínima)
```
lib/
├── core/
│   └── constants/bk_theme_tokens.dart      # Tokens de diseño centralizados
├── features/
│   ├── theme/
│   │   └── bk_theme_data.dart              # ThemeData completo con extensión BK
│   ├── inventory/
│   │   ├── domain/
│   │   │   └── entities/inventory.dart     # Entidad pura de dominio
│   │   └── data/
│   │       └── models/inventory_model.dart # Modelo con serialización JSON/SQL
│   ├── orders/
│   │   ├── domain/
│   │   │   ├── entities/order.dart
│   │   │   └── entities/order_detail.dart
│   │   └── data/
│   │       └── models/order_model.dart
│   └── dashboard/
│       ├── presentation/
│       │   ├── bloc/
│       │   │   ├── dashboard_bloc.dart
│       │   │   ├── dashboard_event.dart
│       │   │   └── dashboard_state.dart
│       │   └── screens/
│       │       └── dashboard_screen.dart   # UI responsiva principal
└── di/
    └── injection.dart                      # Configuración base de get_it/injectable
```

### ✅ Criterios de Aceptación Detallados

#### 1. `bk_theme_data.dart` - Sistema de Temas Completo
- [ ] `colorScheme` con `primary`, `secondary`, `error`, `surface`, `background` alineados a tokens BK.
- [ ] `textTheme` con estilos para `displayLarge`, `headlineMedium`, `bodyLarge`, `labelSmall` usando tipografía corporativa.
- [ ] `elevatedButtonTheme`, `textButtonTheme`, `outlinedButtonTheme` con estados (enabled, disabled, pressed, hovered).
- [ ] `cardTheme`, `inputDecorationTheme`, `snackBarTheme`, `dialogTheme` consistentes con la identidad visual.
- [ ] Soporte nativo para `ThemeMode.system` con definición explícita de modo claro y oscuro.
- [ ] Extensión `ThemeData` con helpers: `context.theme.isDark`, `context.colors.flameRed`.

#### 2. Entidades + Modelos Dart - Capa de Dominio & Datos
- [ ] Uso de `@freezed` con `json_serializable` para generación automática de `fromJson`/`toJson`.
- [ ] Validación de llaves foráneas: campos como `branchId`, `productId`, `orderId` marcados como `required` y tipados como `UUID` o `int`.
- [ ] Métodos de mapeo explícitos: `toEntity()` en Models, `toModel()` en Entities para conversión bidireccional.
- [ ] Inmutabilidad garantizada: todas las entidades son `@immutable` o `freezed` sin setters públicos.
- [ ] Comentarios de documentación `///` explicando reglas de negocio asociadas a cada campo crítico.

#### 3. `DashboardScreen` - Interfaz Principal Responsiva
- [ ] Layout adaptativo con `LayoutBuilder` o paquete `responsive_builder` para switching mobile/tablet/desktop.
- [ ] BLoC conectado a repositorio mock con datos tipados, manejando estados: `DashboardLoading`, `DashboardLoaded`, `DashboardError`.
- [ ] Widgets reutilizables: `InventoryAlertCard` (con badge de urgencia), `DailySalesSummary` (gráfico simple), `QuickActionsRow` (botones de acceso rápido).
- [ ] Uso intensivo de `const` en widgets estáticos, `SizedBox` para espaciado, `Padding` temático vía `Theme.of(context).spacing`.
- [ ] Accesibilidad: `Semantics` en cards interactivas, contraste de colores validado, tap targets ≥48x48 dp.
- [ ] Manejo de errores: UI de fallback con botón de reintento, mensajes de error localizados, logging estructurado.

#### 4. Calidad de Código & Análisis Estático
- [ ] Cero warnings de `flutter analyze` con configuración `very_good_analysis`.
- [ ] Cero uso de `dynamic` no justificado. Si es absolutamente necesario, debe llevar `// ignore: strict_dynamic` con explicación.
- [ ] Manejo de errores explícito en todos los flujos asíncronos: try/catch con mapeo a `Failure` o uso de `Either`.
- [ ] Tests unitarios básicos para BLoC y UseCases generados junto con el código (aunque sea skeleton).

#### 5. Documentación Técnica Adjunta (README.md o comentario inicial)
- [ ] **Aislamiento por Sucursal**: Explicación de cómo se implementa el scoping de queries (`WHERE branch_id = ?`), inyección de dependencias por sucursal (`get_it.registerFactoryParam`), y particionamiento de caché local.
- [ ] **Control de Inventario en Tiempo Real**: Descripción de transacciones ACID en SQLite, implementación del algoritmo FEFO, triggers de reorder point automáticos, y estrategia de reconciliación offline-online.
- [ ] **Resolución de Conflictos Offline**: Estrategia elegida (Last-Write-Wins, merge automático, o conflicto manual), estructura de la cola de operaciones pendientes, y manejo de escenarios de red intermitente.

---

## 🟢 CONFIRMACIÓN DE ARRANQUE - PROTOCOLO DE RESPUESTA

Si has comprendido íntegramente:
- ✅ El alcance estratégico y las restricciones de negocio
- ✅ La arquitectura Clean + Hexagonal y sus reglas inquebrantables  
- ✅ El sistema de diseño tokenizado y los requisitos de accesibilidad
- ✅ Los estándares de calidad, testing y preparación para CI/CD
- ✅ Los protocolos de ejecución y las prohibiciones absolutas

**Responde ÚNICAMENTE con la siguiente línea para confirmar:**

```
[ARQUITECTO LISTO - BK-OS v1.0 - INICIANDO CONSTRUCCIÓN]
```

Y procede inmediatamente a generar en este orden:
1. 🎨 `bk_theme_data.dart` completo con temas claro/oscuro y extensiones de contexto.
2. 🗃️ Entidades + Modelos Dart para `Inventory`, `Order`, `OrderDetail` con validación, serialización y mapeo bidireccional.
3. 🖥️ `DashboardScreen` con BLoC boilerplate, layout responsivo, manejo de estados y widgets reutilizables.
4. 📝 Explicación técnica concisa (máx. 300 palabras) de: aislamiento por sucursal + control de inventario en tiempo real + estrategia offline.

**¿Confirmas recepción de especificaciones y estás listo para compilar la arquitectura empresarial?** 🚀👑
