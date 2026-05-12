# 🍔 Plan de Implementación: Aplicación "Burger King" (Demo Flutter + Firebase)

> ⚠️ **Nota preliminar:** Este plan asume un proyecto de aprendizaje/demo. El nombre y marca "Burger King" están registrados. Para distribución pública, se recomienda usar un nombre genérico o obtener licencia.

---

## 🛠️ 1. Herramientas y Entorno de Desarrollo
| Herramienta | Propósito |
|-------------|-----------|
| **Flutter SDK + Dart** | Framework y lenguaje principal |
| **VS Code** | IDE principal (recomendado) |
| **Extensiones VS Code** | Flutter, Dart, Firebase, Error Lens, Flutter Tree, Pubspec Assist |
| **FlutterFire CLI** | Automatización de configuración Firebase |
| **Firebase Console & CLI** | Gestión de proyectos, Auth, Firestore, Reglas |
| **Figma / Penpot** | Diseño UI/UX, prototipado interactivo |
| **Git + GitHub/GitLab** | Control de versiones y CI/CD |
| **Emuladores / Dispositivos físicos** | Android Studio AVD, iOS Simulator, teléfonos reales |

> 📌 *Sobre "Antigravity":* No es un IDE estándar para Flutter. Si te refieres a un editor específico, verifica compatibilidad con Dart/Flutter. VS Code + extensiones oficiales es la combinación más estable y documentada.

---

## 🎨 2. Diseño UI/UX
1. **Identidad visual:** Paleta de colores corporativos, tipografía legible, iconografía de comida rápida, estados de carga/error consistentes.
2. **Wireframes de baja fidelidad:** Definir flujo de navegación sin distracciones visuales.
3. **Prototipo interactivo:** Validar usabilidad antes de escribir lógica.
4. **Pantallas clave a diseñar:**
   - Onboarding / Bienvenida
   - Login & Registro (email/contraseña)
   - Recuperación de contraseña
   - Home (menú principal, categorías, destacados)
   - Detalle de producto
   - Carrito / Checkout
   - Historial de pedidos
   - Perfil de usuario
   - Configuración / Soporte
5. **Principios UX aplicados:**
   - Feedback inmediato (snackbars, loaders, validaciones en tiempo real)
   - Navegación predecible (barra inferior o drawer)
   - Accesibilidad (contrastes, tamaños de texto ajustables, etiquetas semánticas)
   - Offline-first básico (cache visual, reintentos automáticos)

---

## 📐 3. Arquitectura y Estructura del Proyecto
```
lib/
├── main.dart
├── core/
│   ├── constants/       (rutas, colores, strings, validadores)
│   ├── services/        (config Firebase, logger, router)
│   └── utils/           (formateadores, helpers)
├── features/
│   ├── auth/            (pantallas, controladores, validaciones)
│   ├── menu/            (catálogo, búsqueda, filtros)
│   ├── cart/            (carrito, cálculo totales)
│   └── profile/         (datos usuario, historial, ajustes)
└── shared/
    ├── widgets/         (componentes reutilizables)
    ├── providers/       (estado global con Provider)
    └── models/          (clases de datos mapeadas a Firestore)
```
- **Patrón:** Feature-first + separación por responsabilidades
- **Navegación:** `GoRouter` o `Navigator 2.0` con guards de autenticación
- **Inmutabilidad:** Modelos con `copyWith` o `freezed` (opcional)

---

## 🔥 4. Configuración de Firebase
1. Crear proyecto en Firebase Console
2. Registrar apps: Android (package name), iOS (bundle ID), Web
3. Descargar y ubicar archivos de configuración (`google-services.json`, `GoogleService-Info.plist`)
4. Habilitar **Authentication** → método Email/Password
5. Crear base de datos **Firestore** (modo prueba inicial, luego endurecer reglas)
6. Instalar `flutterfire_cli` y ejecutar `flutterfire configure`
7. Verificar que `firebase_core` se inicialice correctamente en `main.dart`

---

## 🔐 5. Módulo de Autenticación (Email/Password)
1. Validación de formularios (formato email, longitud/máscara contraseña)
2. Flujo de registro: crear usuario → guardar perfil básico en Firestore → redirigir a Home
3. Flujo de login: validar credenciales → manejar sesión persistente → actualizar estado global
4. Recuperación de contraseña: envío de email → validación de token → restablecimiento
5. Cierre de sesión: limpiar estado local, borrar tokens, navegar a Login
6. Manejo de errores de Firebase: traducción a mensajes UX-friendly

---

## 🗄️ 6. Base de Datos Firestore
| Colección | Documentos | Campos clave | Relaciones |
|-----------|------------|--------------|------------|
| `users` | ID del usuario autenticado | `email`, `displayName`, `createdAt`, `role`, `address` | 1 a N con `orders` |
| `products` | ID generado automáticamente | `name`, `description`, `price`, `category`, `imageUrl`, `isActive` | N a N con `orders` vía `cartItems` |
| `orders` | ID generado | `userId`, `items`, `total`, `status`, `createdAt` | Referencia a `products` |
| `cart` (opcional) | `userId` como ID | `items` (array de mapas), `updatedAt` | Sincronizado con sesión activa |

- **Reglas de seguridad iniciales:** Solo usuarios autenticados pueden leer/escribir sus propios documentos.
- **Índices compuestos:** Planear para consultas por categoría + precio + disponibilidad.
- **Paginación:** Implementar `limit()` + `startAfterDocument()` para listas largas.
- **Offline:** Activar persistencia local de Firestore para lecturas frecuentes.

---

## 🔄 7. Gestión de Estado con Provider
1. **AuthProvider:** Estado de sesión, usuario actual, métodos de login/logout/register
2. **MenuProvider:** Catálogo de productos, filtros, estado de carga, búsqueda
3. **CartProvider:** Agregar/eliminar ítems, calcular totales, sincronizar con Firestore
4. **UIProvider (opcional):** Tema claro/oscuro, idioma, estado de navegación
5. **Inyección:** Envolver `MaterialApp` con `MultiProvider` en `main.dart`
6. **Escucha en UI:** `Consumer`, `Selector`, `context.watch()` según granularidad necesaria
7. **Limpieza:** `dispose()` correcto, evitar memory leaks en streams de Firestore

---

## 📦 8. Dependencias Requeridas (`pubspec.yaml`)
| Paquete | Versión sugerida | Propósito |
|---------|------------------|-----------|
| `firebase_core` | ^3.x | Inicialización Firebase |
| `firebase_auth` | ^5.x | Autenticación email/password |
| `cloud_firestore` | ^5.x | Base de datos Firestore |
| `firebase_storage` | ^12.x | (Opcional) Imágenes de productos |
| `provider` | ^6.x | Gestión de estado |
| `go_router` | ^14.x | Navegación declarativa con guards |
| `cached_network_image` | ^3.x | Carga y caché de imágenes |
| `flutter_form_builder` + `validators` | ^9.x / ^10.x | Formularios seguros y validados |
| `intl` | ^0.20.x | Formato de moneda, fechas, localización |
| `flutter_lints` | ^5.x | Estándares de calidad de código |
| `equatable` | ^2.x | (Opcional) Comparación limpia de modelos |
| `shared_preferences` | ^2.x | Configuración local ligera |

> ✅ Ejecutar `flutter pub get` después de añadir dependencias. Mantener versiones actualizadas y compatibles entre sí.

---

## 🚀 9. Flujo de Desarrollo Paso a Paso
1. **Semana 1:** Configuración entorno, estructura de carpetas, inicialización FlutterFire, diseño Figma aprobado.
2. **Semana 2:** Implementación de navegación base, temas globales, widgets reutilizables (botones, inputs, cards).
3. **Semana 3:** Módulo de autenticación (UI + validaciones + conexión Firebase Auth + persistencia de sesión).
4. **Semana 4:** Integración de Firestore, estructura de colecciones, reglas de seguridad básicas, carga de catálogo.
5. **Semana 5:** Providers (`Auth`, `Menu`, `Cart`), sincronización UI-estado, manejo de errores y estados vacíos.
6. **Semana 6:** Carrito funcional, cálculo de totales, flujo de pedido simulado, historial de órdenes.
7. **Semana 7:** Optimización UX (animaciones, skeleton loaders, offline cache), pruebas en múltiples dispositivos.
8. **Semana 8:** Hardening de seguridad (reglas Firestore avanzadas, validación server-side), builds de prueba, documentación.
9. **Entrega:** APK/IPA de prueba, reporte de cobertura, plan de despliegue a stores.

---

## ⚠️ Notas Legales y Recomendaciones Finales
- **Marcas:** Evitar uso comercial de logos/nombres registrados sin autorización.
- **Seguridad:** Nunca exponer claves de Firebase en código cliente; usar reglas de Firestore y App Check en producción.
- **Escalabilidad:** Considerar migrar a Riverpod/Bloc si el proyecto crece, pero Provider es válido para alcance medio.
- **CI/CD:** Configurar GitHub Actions para build automático, linting y pruebas unitarias.
- **Analítica:** Añadir `firebase_analytics` para seguimiento de conversiones y errores en producción.

---

✅ **Siguiente paso:** Revisa este plan, ajusta fases o dependencias según tu alcance real, y confirma cuando estés listo para recibir el código estructurado por módulos (main, providers, auth service, firestore repo, UI screens).
