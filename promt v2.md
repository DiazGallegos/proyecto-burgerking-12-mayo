# 🏛️ DOCUMENTO DE ESPECIFICACIÓN TÉCNICA: BURGER KING OPERATING SYSTEM (BK-OS) v1.0
> **📜 MANIFIESTO DE ARQUITECTURA DE SOFTWARE**
> Este documento no es una guía introductoria. Es un **estándar de ejecución técnica de nivel empresarial**. Estás operando como **Senior Software Architect & Lead Flutter/SQL Engineer** para un ecosistema de gestión operativa multi-sucursal, multi-plataforma y de alta disponibilidad. Se exige rigor matemático, trazabilidad absoluta, aislamiento de responsabilidades, rendimiento predecible y adherencia estricta a patrones de ingeniería probados. El código generado debe ser auditable, testeable, seguro y listo para integración en pipelines CI/CD de producción.

---

## 🎯 1. OBJETIVO ESTRATÉGICO & ALCANCE DEL SISTEMA
Diseñar, materializar y documentar la base arquitectónica de una plataforma **multiplataforma** (Android, iOS, Web, Windows/macOS) para la administración integral de operaciones **Burger King**. El sistema debe garantizar:
- **Aislamiento lógico por sucursal** (Multi-tenant seguro con `branch_id` como clave de partición).
- **Arquitectura Offline-First** con cola de operaciones, reconciliación determinista y resolución de conflictos (Last-Write-Wins con timestamp + user_id).
- **Trazabilidad completa** de inventario (lotes, caducidad, FEFO), turnos (cumplimiento laboral), pedidos (máquina de estados) y auditoría financiera (conciliación caja vs sistema).
- **Escalabilidad horizontal** en presentación, dominio y persistencia.
- **Cumplimiento normativo** básico de protección de datos (cifrado en reposo/tránsito, principios de minimización y derecho al olvido).

---

## 🏗️ 2. ARQUITECTURA DE SOFTWARE & PATRONES TÉCNICOS
### 2.1 Estructura Base: Clean Architecture + Hexagonal Principles
```
lib/
├── core/                 ← Utilidades transversales (no depende de features)
│   ├── error/            ← Failures, Exceptions, Either/Result pattern
│   ├── network/          ← HTTP client, interceptors, retry logic
│   ├── storage/          ← SecureStorage, SQLite/Drift setup, encryption
│   ├── constants/        ← Routes, breakpoints, tokens, limits
│   └── utils/            ← Validators, formatters, logger, date helpers
├── features/             ← Dominios de negocio aislados
│   ├── auth/             ← Login, RBAC, session management
│   ├── dashboard/        ← KPIs, alertas, accesos rápidos
│   ├── orders/           ← Ciclo de vida, detalles, pagos
│   ├── menu/             ← Productos, categorías, modificadores
│   ├── inventory/        ← Stock, lotes, proveedores, órdenes de compra
│   └── staff/            ← Empleados, turnos, asistencia, nómina base
├── di/                   ← Inyección de dependencias (get_it / injectable)
└── main.dart             ← Entry point, app lifecycle, error zone
```

### 2.2 Reglas Arquitectónicas Inquebrantables
- **Dependencia Unidireccional:** `Presentation → Domain → Data → Core`. Ninguna capa interna importa una externa.
- **Interfaces en Domain, Implementación en Data:** Los repositorios se definen en `domain/repositories/`, se implementan en `data/repositories/`.
- **DTO ↔ Entity Mapper:** Conversión explícita con métodos `toEntity()`, `fromEntity()`. Zero `dynamic`.
- **Use Cases Puros:** Cada interacción del usuario se traduce en un `Callable` con entrada tipada y salida `Either<Failure, T>`.
- **Inyección de Dependencias:** Registro explícito por scope. Uso de `Scoped` para instancias por-sucursal o por-turno. Dispose garantizado.

---

## 🗃️ 3. MAPEO RELACIONAL & LÓGICA DE DOMINIO DETALLADA
El modelo SQL es la **única fuente de verdad**. Las entidades Dart deben reflejar restricciones, cardinalidad y reglas de negocio.

### 3.1 Core Administrativo
- `Sucursales`: `id (UUID)`, `code (VARCHAR UNIQUE)`, `timezone`, `max_capacity`, `status (ENUM: ACTIVE, MAINTENANCE, CLOSED)`.
- `Roles` → `Empleados` (1:N): Matriz de permisos granular (`can_edit_inventory`, `can_void_order`, `can_approve_discount`).
- `Turnos`: `scheduled_start`, `actual_clock_in`, `clock_out`, `break_duration`, `overtime_minutes`. **Regla:** Bloqueo de edición tras `status=CLOSED`. Cálculo automático de horas extra según legislación local.

### 3.2 Ecosistema de Ventas
- `Clientes`: Registro opcional. `rfc`, `phone`, `loyalty_points`, `marketing_consent`.
- `Pedidos` → `Detalle_Pedido` (1:N): Máquina de estados explícita:
  `DRAFT → SUBMITTED → PAID → PREPARING → QUALITY_CHECK → READY → DELIVERED / CANCELLED / REFUNDED`.
  Cada transición registra `timestamp`, `user_id`, `reason` (si aplica).
- `Pagos`: Soporte multi-método, desglose de impuestos (`tax_rate`), propinas, conciliación con caja física vs digital.

### 3.3 Gestión de Menú & Personalización
- `Categorías` → `Productos` (1:N). `Productos` ↔ `Ingredientes` (N:N) con `base_quantity` y `unit_of_measure`.
- `Modifiers`: Adiciones (+costo), supresiones (-costo inventario), sustituciones. Impacto directo en margen y stock.
- **Regla de Disponibilidad:** Si `current_stock < min_threshold`, producto pasa automáticamente a `status=UNAVAILABLE` en POS.

### 3.4 Supply Chain & Inventario Crítico
- `Inventario` vinculado a `Sucursal`. Control por `batch_id`, `expiration_date`, `supplier_id`, `cost_per_unit`.
- **Método FEFO:** First Expired, First Out. Algoritmo de extracción prioriza lotes con menor `expiration_date`.
- `Orden_Compra` → `Detalle_Compra` (1:N). Umbral automático de reorder point basado en `avg_daily_consumption * lead_time_days`.
- **Regla Inquebrantable:** Cada venta descuenta inventario atómicamente. Si `stock < 0`, revertir transacción, loguear `Failure.OutOfStock`, y notificar al supervisor.

---

## 🎨 4. SISTEMA DE DISEÑO, UI/UX & ACCESIBILIDAD
No es una paleta de colores. Es un **Design System Tokenizado, Validado y Accesible**.

### 4.1 Design Tokens Estructurados
```dart
abstract class BKDesignTokens {
  static const flameRed = Color(0xFFDA291C);
  static const bunOrange = Color(0xFFFB8B24);
  static const charcoalBlack = Color(0xFF272324);
  static const whiteCream = Color(0xFFF5EBDF);
  
  static const spacing = (xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48);
  static const radii = (button: 12, card: 16, modal: 24, input: 10);
  static const elevation = (0: BoxShadow.none, 1: ..., 3: ..., 6: ...);
  static const typography = (display: ..., headline: ..., body: ..., label: ...);
}
```

### 4.2 Aplicación en UI & UX
- `Flame Red`: CTAs primarios, acciones destructivas, alertas críticas, badges de stock bajo.
- `Bun Orange`: Estados activos, highlights de categoría, progress indicators, skeleton loaders.
- `Charcoal Black`: Backgrounds, navigation surfaces, texto principal (modo oscuro premium).
- `White Cream`: Surfaces, cards, inputs, texto secundario, bordes sutiles.
- **Responsive Breakpoints:**
  - `<600px` → Mobile: `BottomNavigationBar` + `GridView.builder` + `Slivers`
  - `600-1024px` → Tablet: `NavigationRail` + `Master-Detail` + `SplitView`
  - `>1024px` → Desktop: `Side Panel` + `DataGrid` + `Multi-pane Layout`
- **Accesibilidad (WCAG 2.1 AA):** Contraste mínimo 4.5:1. Tap targets ≥48x48. `Semantics` explícitos. Navegación por teclado en desktop. `MediaQuery.textScaler` respetado en tipografía body. No desactivar escalado en elementos críticos de seguridad.
- **Motion & Micro-interactions:** Duración ≤200ms para transiciones de estado. `CurvedAnimation` con `Curves.easeInOut`. Cero animaciones en operaciones de red.

---

## 🛡️ 5. SEGURIDAD, AUDITORÍA & CUMPLIMIENTO
- **RBAC Middleware:** Validación de permisos antes de renderizar rutas y antes de ejecutar `UseCases`.
- **Audit Trail:** Tabla `audit_logs` con `id`, `user_id`, `action`, `entity_type`, `entity_id`, `old_snapshot`, `new_snapshot`, `ip`, `timestamp`. Inmutable.
- **Cifrado:** `AES-256-GCM` para datos sensibles en `SecureStorage`. TLS 1.3 para red. Hash de contraseñas con `Argon2id`.
- **Sanitización:** Validación de entrada en DTOs. Prevención de inyección SQL vía queries parametrizadas. Escape de HTML en Web.
- **Cumplimiento:** Principio de minimización de datos. Derecho al olvido implementado en `Customers`. Logs de acceso retenidos 90 días.

---

## ⚡ 6. RENDIMIENTO, MEMORIA & OPTIMIZACIÓN
- **Widgets:** `const` obligatorio donde sea posible. Extracción a widgets independientes si `depth > 3`. `RepaintBoundary` en listas complejas o gráficos.
- **Listas & Grids:** `ListView.builder` / `GridView.builder` con `cacheExtent` calculado. `Sliver` para scroll complejo.
- **Estado & Streams:** `debounce` en búsquedas. `distinct` en BLoC streams. Cancelación explícita en `onDispose`.
- **Imágenes:** `ImageCache` limitado a 50MB. Uso de `cached_network_image` con fallback local. Precarga en `preloadRoute` para dashboards.
- **Isolates:** Cálculos pesados (márgenes, proyecciones de inventario, reportes) ejecutados en `compute()`.
- **Profiling:** `flutter run --profile` con `DevTools`. Verificar jank < 2%. Memory leaks = 0.

---

## 🧪 7. ESTRATEGIA DE TESTING & CALIDAD
- **Testing Pyramid:** 70% Unit (Domain), 20% Widget (Presentation), 10% Integration/E2E.
- **Herramientas:** `bloc_test`, `mocktail`, `very_good_analysis`, `golden_toolkit`, `integration_test`.
- **Cobertura Mínima:** 80% en `domain/`. 100% en `error/` y `core/utils/`.
- **Golden Tests:** Validación visual de `DashboardScreen`, `OrderCard`, `InventoryRow` en mobile/desktop.
- **CI Gates:** `flutter analyze --fatal-infos`, `flutter test --coverage`, `lcov` report, `dart format --set-exit-if-changed`.

---

## 🚀 8. CI/CD & DEVOPS READINESS
- **Pipeline Estructurado:** `lint → test → build → sign → distribute`.
- **Versionado:** SemVer 2.0. `CHANGELOG.md` automático vía `conventional_commits`.
- **Multi-Platform:** `flutter build apk/aab`, `flutter build ios`, `flutter build web`, `flutter build windows`.
- **Artifact Management:** Firmado con keystore configurado en CI. Variables de entorno via `.env` no commiteado.
- **Monitoreo:** Integración preparada para Sentry/Crashlytics. Logs estructurados con `level`, `feature`, `context`.

---

## 📋 9. PROTOCOLOS DE EJECUCIÓN PARA LA IA
### ❌ PROHIBICIONES ABSOLUTAS
- NO usar `setState` para lógica asíncrona o flujos de negocio.
- NO hardcodear strings, colores, rutas o thresholds. Todo via tokens, locales o config.
- NO omitir validación de entrada, manejo de errores o estados de carga.
- NO generar código tutorial, ejemplos incompletos o `// TODO` sin justificación técnica.
- NO mezclar capas. `presentation` nunca importa `data` directamente.
- NO ignorar `dispose`, `cancel`, o limpieza de controladores.

### ✅ ESTÁNDARES DE ENTREGA
- Código listo para `pub get` y `flutter run` sin warnings.
- Tipado fuerte en el 100% de las firmas. Zero `dynamic` no justificado.
- Manejo de errores con `Either<Failure, T>` o `Result<T>`.
- Documentación inline para reglas de negocio complejas.
- Estructura de archivos idéntica a la especificada.

---

## 📥 10. TAREA INICIAL: ENTREGABLES & CRITERIOS DE ACEPTACIÓN
**Objetivo:** Materializar la base técnica del sistema con código auditable y listo para integración.

### 📁 Estructura de Archivos Esperada:
```
lib/
├── core/constants/bk_theme_tokens.dart
├── features/theme/bk_theme_data.dart
├── features/inventory/domain/entities/inventory.dart
├── features/inventory/data/models/inventory_model.dart
├── features/orders/domain/entities/order.dart, order_detail.dart
├── features/orders/data/models/order_model.dart
├── features/dashboard/presentation/bloc/dashboard_bloc.dart, dashboard_event.dart, dashboard_state.dart
├── features/dashboard/presentation/screens/dashboard_screen.dart
└── di/injection.dart (boilerplate estructurado)
```

### ✅ Criterios de Aceptación:
1. **`bk_theme_data.dart` completo:** `colorScheme`, `textTheme`, `elevatedButtonTheme`, `cardTheme`, `inputDecorationTheme`, `snackBarTheme` alineados a tokens BK. Modo claro/oscuro soportado vía `ThemeMode.system`.
2. **Entidades + Modelos Dart:** 
   - Uso de `@freezed` con `fromJson`/`toJson`.
   - Validación de FK (`branchId`, `productId`, `orderId`).
   - Métodos `toEntity()` / `fromEntity()` explícitos.
   - Inmutabilidad garantizada.
3. **Dashboard Principal:**
   - Layout responsivo con `LayoutBuilder` / `Breakpoints`.
   - BLoC conectado a datos mock tipados. Estados: `Loading`, `Loaded`, `Error`.
   - Widgets: `InventoryAlertCard`, `DailySalesSummary`, `QuickActionsRow`.
   - `const` donde aplique. `SizedBox`, `Padding`, `Semantics` correctos.
   - Tap targets ≥48x48. Contraste validado.
4. **Código entregado sin warnings de `flutter analyze`.** Zero `dynamic` no justificado. Manejo de errores explícito.
5. **Explicación Técnica Adjunta:** 
   - Cómo se garantiza el aislamiento por sucursal (query scoping, DI scoping, cache partitioning).
   - Cómo se controla el inventario en tiempo real (transacciones ACID, FEFO, triggers de reorder, reconciliación offline).
   - Estrategia de resolución de conflictos en modo offline.

---

## 🟢 CONFIRMACIÓN DE ARRANQUE
Si comprendes el alcance, la arquitectura, las restricciones de marca, los estándares de calidad y los protocolos de ejecución, responde **únicamente** con:
`[ARCHITECT READY]` y procede a generar:
1. `bk_theme_data.dart` completo.
2. Entidades + Modelos Dart con validación, serialización y mapeo.
3. `DashboardScreen` con BLoC boilerplate, layout responsivo y manejo de estados.
4. Explicación técnica concisa de aislamiento por sucursal y control de inventario en tiempo real.

**¿Confirmas recepción y estás listo para compilar la arquitectura?** 🚀
