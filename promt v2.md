# 🏛️ DOCUMENTO DE ESPECIFICACIÓN TÉCNICA: SISTEMA OPERATIVO BURGER KING (BK-OS) v1.0
> **📜 MANIFIESTO DE ARQUITECTURA DE SOFTWARE**
> Este documento no es una guía introductoria. Es un **estándar de ejecución técnica de nivel empresarial**. Estás operando como **Arquitecto de Software Senior y Desarrollador Líder en Flutter y SQL** para un ecosistema de gestión operativa multi-sucursal, multi-plataforma y de alta disponibilidad. Se exige rigor matemático, trazabilidad absoluta, aislamiento estricto de responsabilidades, rendimiento predecible y adherencia total a patrones de ingeniería probados. El código generado debe ser auditable, testeable, seguro y listo para integración en canalizaciones de despliegue continuo de producción.

---

## 🎯 1. OBJETIVO ESTRATÉGICO Y ALCANCE DEL SISTEMA
Diseñar, materializar y documentar la base arquitectónica de una plataforma **multiplataforma** (Android, iOS, Web, Windows y macOS) para la administración integral de operaciones **Burger King**. El sistema debe garantizar:

- **Aislamiento lógico por sucursal**: Modelo multi-inquilino seguro con `identificador_sucursal` como clave de partición en todas las consultas y caches locales.
- **Arquitectura de funcionamiento sin conexión**: Cola de operaciones pendientes, reconciliación determinista y resolución de conflictos mediante estrategia de "última escritura válida" con marca de tiempo y `identificador_usuario` para auditoría.
- **Trazabilidad completa**: Control absoluto de inventario (lotes, fechas de vencimiento, método primero en expirar primero en salir), turnos (cumplimiento de horarios), pedidos (máquina de estados finita) y conciliación financiera (caja física vs sistema digital).
- **Escalabilidad horizontal**: Capas de presentación, dominio y persistencia diseñadas para crecer sin reescrituras estructurales.
- **Cumplimiento normativo base**: Cifrado en reposo y en tránsito, principio de minimización de datos y derecho a la eliminación segura.

---

## 🏗️ 2. ARQUITECTURA DE SOFTWARE Y PATRONES TÉCNICOS

### 2.1 Estructura Base: Arquitectura Limpia + Principios Hexagonales
```
lib/
├── nucleo/                 ← Utilidades transversales (NO depende de funcionalidades)
│   ├── errores/            ← Fallos, excepciones, patrón Resultado o Unión
│   ├── red/                ← Cliente HTTP, interceptores, lógica de reintentos
│   ├── almacenamiento/     ← Almacenamiento seguro, configuración SQLite/Drift, cifrado
│   ├── constantes/         ← Rutas, puntos de quiebre, tokens de diseño, límites del sistema
│   └── utilidades/         ← Validadores, formateadores, registrador, auxiliares de fecha
├── funcionalidades/        ← Dominios de negocio aislados e independientes
│   ├── autenticacion/      ← Inicio de sesión, control de roles, gestión de sesiones
│   ├── tablero/            ← Indicadores clave, alertas críticas, accesos rápidos
│   ├── pedidos/            ← Ciclo de vida, detalles, procesamiento de pagos
│   ├── menu/               ← Gestión de productos, categorías, modificadores y combos
│   ├── inventario/         ← Control de existencias, lotes, proveedores, órdenes de compra
│   └── personal/           ← Empleados, turnos, asistencia, nómina base
├── inyeccion/              ← Configuración de inyección de dependencias (get_it / injectable)
└── principal.dart          ← Punto de entrada, ciclo de vida de la aplicación, zona de errores globales
```

### 2.2 Reglas Arquitectónicas Inquebrantables
- **Dependencia Unidireccional Estricta**: `Presentación → Dominio → Datos → Núcleo`. Ninguna capa interna puede importar una capa externa bajo ninguna circunstancia.
- **Contratos en Dominio, Implementación en Datos**: Las interfaces de repositorios se definen en `dominio/repositorios/`, y sus implementaciones concretas residen en `datos/repositorios/`.
- **Mapeo Explícito Modelo de Datos ↔ Entidad**: Conversión bidireccional con métodos `a_entidad()` y `desde_entidad()`. Cero uso de `dinámico` sin justificación técnica documentada.
- **Casos de Uso Puros**: Cada interacción del usuario se traduce en un `CasoDeUso` ejecutable con entrada tipada y salida `Resultado<Fallo, T>` para manejo funcional de errores.
- **Inyección de Dependencias Controlada**: Registro explícito por alcance de vida. Uso de `Alcance` para instancias por-sucursal o por-turno. Liberación de recursos garantizada para evitar fugas de memoria.

---

## 🗃️ 3. MAPEO RELACIONAL Y LÓGICA DE NEGOCIO DETALLADA
El modelo relacional es la **única fuente de verdad**. Las entidades en Dart deben reflejar fielmente restricciones de base de datos, cardinalidad de relaciones y reglas de negocio complejas.

### 3.1 Núcleo Administrativo
- **`Sucursales`**: `id (identificador universal único)`, `codigo (texto único)`, `zona_horaria`, `capacidad_maxima`, `estado (enumerado: ACTIVA, MANTENIMIENTO, CERRADA)`.
- **`Roles` → `Empleados` (1:N)**: Matriz de permisos granular con indicadores como `puede_editar_inventario`, `puede_anular_pedido`, `puede_aprobar_descuento`, `puede_ver_reportes`.
- **`Turnos`**: `inicio_programado`, `entrada_real`, `salida`, `duracion_descanso`, `minutos_extra`. 
  - **Regla de Negocio**: Bloqueo automático de edición tras `estado=CERRADO`. Cálculo automático de horas extra según legislación laboral local configurable por región.

### 3.2 Ecosistema de Ventas
- **`Clientes`**: Registro opcional para transacciones rápidas. Campos: `registro_fiscal`, `telefono`, `puntos_fidelidad`, `consentimiento_marketing`, `ultima_visita`.
- **`Pedidos` → `Detalle_Pedido` (1:N)**: Máquina de estados finita explícita:
  ```
  BORRADOR → ENVIADO → PAGADO → EN_PREPARACION → CONTROL_CALIDAD → LISTO → ENTREGADO 
                                                              ↘ CANCELADO / REEMBOLSADO
  ```
  Cada transición registra obligatoriamente: `marca_tiempo`, `usuario_id`, `codigo_motivo` (si aplica), `identificador_dispositivo`.
- **`Pagos`**: Soporte multi-método (efectivo, tarjeta, monedero digital, vale), desglose granular de impuestos (`tasa_impuesto` por ítem), propinas, conciliación automática caja física vs digital con tolerancias configurables.

### 3.3 Gestión de Menú y Personalización
- **`Categorías` → `Productos` (1:N)**. **`Productos` ↔ `Ingredientes` (N:N)** con `cantidad_base`, `unidad_medida`, `factor_merma`.
- **`Modificadores`**: Adiciones (+costo al cliente, -existencias), supresiones (-costo inventario, ajuste de receta), sustituciones (intercambio de ingredientes). Impacto directo y automático en margen de contribución y niveles de stock.
- **Regla de Disponibilidad Automática**: Si `existencia_actual < umbral_minimo` configurado, el producto cambia automáticamente a `estado=NO_DISPONIBLE` en todos los puntos de venta de esa sucursal.

### 3.4 Cadena de Suministro e Inventario Crítico
- **`Inventario`** vinculado estrictamente a `Sucursal`. Control granular por `identificador_lote`, `fecha_vencimiento`, `proveedor_id`, `costo_por_unidad`, `marca_tiempo_entrada`.
- **Método PEPS (Primero en Expirar, Primero en Salir)**: Algoritmo de extracción de inventario que prioriza automáticamente los lotes con menor `fecha_vencimiento` para minimizar mermas.
- **`Orden_Compra` → `Detalle_Compra` (1:N)**. Umbral automático de punto de reorden calculado dinámicamente: `consumo_promedio_diario * dias_plazo_entrega + stock_seguridad`.
- **Regla Inquebrantable de Transaccionalidad**: Cada venta descuenta inventario atómicamente dentro de una transacción de base de datos. Si `existencia < 0` en cualquier punto, revertir toda la transacción, registrar `Fallo.SinExistencias`, y notificar inmediatamente al supervisor de turno.

---

## 🎨 4. SISTEMA DE DISEÑO, INTERFAZ DE USUARIO Y ACCESIBILIDAD
No es simplemente una paleta de colores. Es un **Sistema de Diseño Tokenizado, Validado, Documentado y Accesible** para garantizar consistencia en todas las plataformas.

### 4.1 Tokens de Diseño Estructurados (Ejemplo Dart)
```dart
// Paleta Cromática Corporativa
abstract class TokensDisenoBK {
  static const colorRojoLlama = Color(0xFFDA291C);      // Acciones críticas, botones principales, errores
  static const colorPanNaranja = Color(0xFFFB8B24);     // Acentos, estados activos, resaltados
  static const colorCarbonNegro = Color(0xFF272324);    // Fondos, navegación, texto principal
  static const colorCremaBlanco = Color(0xFFF5EBDF);    // Superficies, tarjetas, texto secundario
  
  // Sistema de Espaciado (escala base 4px)
  static const espaciado = (xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48, xxxl: 64);
  
  // Bordes y Radios
  static const radios = (boton: 12, tarjeta: 16, modal: 24, entrada: 10, etiqueta: 20);
  
  // Sombras y Elevación
  static const sombras = (
    0: BoxShadow.none, 
    1: BoxShadow(color: Color(0x1A000000), blurRadius: 2),
    3: BoxShadow(color: Color(0x26000000), blurRadius: 8),
    6: BoxShadow(color: Color(0x40000000), blurRadius: 16)
  );
}
```

### 4.2 Aplicación Práctica en Interfaz y Experiencia de Usuario
- **`Rojo Llama (#DA291C)`**: Botones de acción principal, acciones destructivas (eliminar, cancelar), alertas críticas, insignias de stock bajo, indicadores de error.
- **`Pan Naranja (#FB8B24)`**: Estados activos/paso, resaltados de categoría seleccionada, indicadores de progreso, cargadores visuales, mensajes informativos.
- **`Carbon Negro (#272324)`**: Fondos principales, barras de navegación, texto principal en modo oscuro premium, encabezados de sección.
- **`Crema Blanco (#F5EBDF)`**: Superficies de tarjetas, fondos de campos de texto, texto secundario, bordes sutiles, estados deshabilitados.

### 4.3 Puntos de Quiebre Responsivos
| Rango de Pantalla | Dispositivo | Patrón de Navegación | Diseño Principal |
|------------------|-------------|---------------------|-----------------|
| `<600px` | Móvil | `BarraNavegacionInferior` + Menú lateral | `Cuadricula.constructura` + `EstructurasDeslizables` |
| `600-1024px` | Tableta | `RielNavegacion` lateral | `Maestro-Detalle` + `VistaDividida` adaptativa |
| `>1024px` | Escritorio/Web | `PanelLateral` colapsable | `DiseñoMultiPanel` + `RejillaDatos` con filtros avanzados |

### 4.4 Accesibilidad (Cumplimiento Normativo WCAG 2.1 Nivel AA)
- **Contraste mínimo 4.5:1** para texto normal, 3:1 para texto grande. Validación automática en pipeline.
- **Áreas táctiles ≥48x48 píxeles independientes de densidad** para todas las acciones interactivas.
- **Semántica explícita** en componentes personalizados para lectores de pantalla (TalkBack/VoiceOver).
- **Navegación por teclado completa** en plataformas de escritorio (Web/Windows).
- **Escalador de texto respetado** en tipografía de cuerpo, permitiendo ampliación hasta 2.0x sin romper maquetaciones.
- **No desactivar escalado** en elementos críticos de seguridad o confirmación de acciones.

### 4.5 Movimiento y Microinteracciones
- Duración de transiciones ≤200 milisegundos para cambios de estado, ≤300 milisegundos para navegaciones.
- Uso de `CurvaAnimacion` con `Curvas.EntradaSalidaSuave` para movimientos naturales.
- **Cero animaciones** en operaciones de red críticas o procesos de pago para no entorpecer la percepción de velocidad.
- Retroalimentación háptica en móvil para acciones confirmadas (vibración corta en éxito, patrón diferente en error).

---

## 🛡️ 5. SEGURIDAD, AUDITORÍA Y CUMPLIMIENTO NORMATIVO

### 5.1 Control de Acceso Basado en Roles
- **Intermediario de Rutas**: Validación de permisos ANTES de renderizar cualquier ruta protegida.
- **Validación a Nivel de Caso de Uso**: Doble verificación de permisos antes de ejecutar operaciones sensibles (ej: `AnularPedido`, `EditarInventario`).
- **Tokens de Sesión**: Identificadores con refresco, expiración configurable por rol (ej: cajero: 4h, administrador: 8h).

### 5.2 Trazabilidad de Auditoría Inmutable
Tabla `registro_auditoria` con estructura:
```
id IDENTIFICADOR_UNICO_CLAVE_PRIMARIA,
usuario_id IDENTIFICADOR_UNICO REFERENCIA empleados(id),
accion TEXTO(50) NO_NULO, -- 'CREAR', 'ACTUALIZAR', 'ELIMINAR', 'INICIAR_SESION', 'ANULAR'
tipo_entidad TEXTO(50) NO_NULO, -- 'pedido', 'inventario', 'producto'
identificador_entidad IDENTIFICADOR_UNICO NO_NULO,
estado_anterior DATOS_JSON, -- Estado anterior completo
estado_nuevo DATOS_JSON, -- Estado nuevo completo
direccion_ip INET,
huella_dispositivo TEXTO(255),
marca_tiempo FECHA_HORA_DEFECTO_AHORA
```
- **Inmutable**: Solo inserciones, nunca actualizaciones o eliminaciones.
- **Retención**: 7 años para fines fiscales, con archivado automático a almacenamiento frío después de 1 año.

### 5.3 Cifrado y Protección de Datos
- **Datos Sensibles en Reposo**: `AES-256-GCM` para información personal en almacenamiento seguro o columnas cifradas en base de datos local.
- **Comunicaciones**: TLS 1.3 obligatorio para todas las conexiones de red. Fijación de certificados en aplicaciones móviles.
- **Credenciales**: Hash de contraseñas con `Argon2id` (resistente a memoria y GPUs). Salting único por usuario.
- **Sanitización de Entradas**: Validación y escape estricto en todos los modelos de transferencia de datos. Prevención de inyección SQL mediante consultas parametrizadas obligatorias. Escape de contenido en renderizado Web para prevenir ataques de scripting.

### 5.4 Cumplimiento y Privacidad
- **Principio de Minimización**: Solo recolectar datos estrictamente necesarios para la operación.
- **Derecho a la Eliminación**: Implementación de punto final que anonimiza datos personales pero preserva registros transaccionales para auditoría fiscal.
- **Consentimiento**: Registro explícito de `consentimiento_marketing` con marca de tiempo y versión de términos aceptados.
- **Registros de Acceso**: Retención de 90 días para monitoreo de seguridad, con acceso restringido a roles de auditoría.

---

## ⚡ 6. RENDIMIENTO, GESTIÓN DE MEMORIA Y OPTIMIZACIÓN

### 6.1 Optimización de Componentes Visuales
- **`const` obligatorio** en todos los componentes que no dependan de estado dinámico.
- **Extracción a componentes independientes** si la profundidad del árbol visual > 3 niveles para mejorar reconstrucciones.
- **`LímiteRepintado` estratégico** en listas complejas, gráficos animados o componentes con actualizaciones frecuentes para aislar repintados.

### 6.2 Manejo Eficiente de Listas y Cuadrículas
- **`ListaVista.constructor` / `Cuadricula.constructor`** siempre para conjuntos de datos dinámicos, nunca listas estáticas con hijos fijos.
- **`alcance_cache` calculado** dinámicamente según el área visible para precargar elementos inminentes.
- **Uso de `EstructurasDeslizables`** para desplazamiento complejo con encabezados fijos, parallax o efectos de expansión.

### 6.3 Gestión de Estado y Flujos de Datos
- **`retraso` de 300 milisegundos** en campos de búsqueda y filtros para reducir llamadas innecesarias.
- **`distinto()` en flujos de componentes de lógica** para evitar reconstrucciones cuando el estado no ha cambiado realmente.
- **Cancelación explícita** de suscripciones en `al_liberar` para prevenir fugas de memoria.

### 6.4 Manejo de Imágenes y Recursos
- **`CacheImagen` limitado** a 50 megabytes máximo con política de reemplazo menos recientemente usado.
- **Uso de carga diferida en red** con respaldo a marcador local y componente de error personalizado.
- **Precarga estratégica** en rutas prioritarias para tableros y pantallas de alta importancia.
- **Compresión automática** de imágenes subidas desde cámara o galería antes de enviar al servidor.

### 6.5 Procesamiento en Segundo Plano
- **`HilosAislados` para cómputo pesado**: Cálculos de márgenes, proyecciones de inventario, generación de reportes ejecutados en `computar()` para no bloquear el hilo de interfaz.
- **Procesamiento paralelo en Web**: Uso de trabajadores web para tareas intensivas en plataforma de navegador.

### 6.6 Perfilado y Monitoreo Continuo
- **`ejecutar --perfil`** con integración a herramientas de desarrollo para análisis de rendimiento en desarrollo.
- **Métricas clave**: Tartamudeo < 2% de cuadros, tiempo de inicio en frío < 2 segundos en dispositivos de gama media, fugas de memoria = 0 detectadas en pruebas de estrés.
- **Alertas automáticas** en pipeline si el tamaño del paquete crece >5% sin justificación.

---

## 🧪 7. ESTRATEGIA DE PRUEBAS Y GARANTÍA DE CALIDAD

### 7.1 Pirámide de Pruebas
```
        Pruebas Integrales / Fin a Fin (10%)
              /    \
             /      \
    Pruebas de Componentes (20%)  Contratos de API (5%)
           \          /
            \        /
        Pruebas Unitarias - Dominio (65%)
```

### 7.2 Herramientas y Marcos de Trabajo
- **Pruebas Unitarias**: `prueba`, `prueba_bloc`, `simulacro` para objetos de prueba tipados y verificables.
- **Pruebas de Componentes**: `prueba_flutter`, `kit_dorado` para pruebas visuales con tolerancia de píxeles configurable.
- **Pruebas de Integración**: `prueba_integracion` para flujos críticos de extremo a extremo en dispositivo real o emulador.
- **Análisis Estático**: `muy_buen_analisis` o `lints_flutter` con reglas estrictas, tratadas como errores en pipeline.

### 7.3 Cobertura Mínima Obligatoria
- **80% en `dominio/`**: Reglas de negocio son el corazón del sistema, deben estar exhaustivamente probadas.
- **100% en `nucleo/errores/` y `nucleo/utilidades/`**: Utilidades base y manejo de errores no pueden tener puntos ciegos.
- **70% en `datos/`**: Mapeadores, repositorios y fuentes de datos con simulacros de API o base de datos.
- **50% en `presentacion/`**: Componentes críticos y bloques de lógica, con pruebas visuales para regresión.

### 7.4 Pruebas Visuales y Regresión
- Validación automática de `PantallaTablero`, `TarjetaPedido`, `FilaInventario`, `ProductoMiniatura` en puntos de quiebre móvil y escritorio.
- **Tolerancia de píxeles**: 0.01% para maquetaciones estáticas, 1% para componentes con animaciones o datos dinámicos.
- **Actualización controlada**: Los archivos de referencia solo se actualizan con aprobación explícita vía revisión de solicitud de extracción.

### 7.5 Puertas de Pipeline
```yaml
# Ejemplo de canalización mínima
etapas:
  - linteo: flutter analyze --fatal-infos --fatal-warnings
  - pruebas: 
      - flutter test --coverage --aleatorizar-orden-semilla=random
      - genhtml cobertura/lcov.info -o cobertura/html
      # Fallo si cobertura < umbral configurado
  - formato: dart format --establecer-salida-si-cambia lib/ test/
  - construccion: flutter build apk --dividir-por-arquitectura / ios / web / windows
  - seguridad: dart pub outdated --modo=null-safety / verificación dependencias
```

---

## 🚀 8. AUTOMATIZACIÓN, ENTREGA CONTINUA Y DESPLIEGUE

### 8.1 Canalización de Entrega Continua
```
[Confirmación] → [Linteo y Formato] → [Pruebas Unitarias] → [Pruebas de Componentes] → [Construcción Multiplataforma] → [Firmado Artefactos] → [Distribución]
```

### 8.2 Versionado y Registro de Cambios
- **Versionado Semántico 2.0 estricto**: `MAYOR.MENOR.PARCHE` con reglas claras de incremento.
- **`CAMBIOS.md` automático**: Generado vía `compromisos_convencionales` (característica:, corrección:, ruptura:, mantenimiento:).
- **Etiquetas de Repositorio**: Automáticas en liberaciones exitosas, con notas de versión generadas.

### 8.3 Construcciones Multiplataforma
```bash
# Comandos estandarizados
flutter build apk --dividir-por-arquitectura --objetivo=lib/principal_produccion.dart
flutter build ios --liberacion --objetivo=lib/principal_produccion.dart
flutter build web --liberacion --definir-dart=ENTORNO=produccion
flutter build windows --liberacion --objetivo=lib/principal_produccion.dart
```

### 8.4 Gestión de Artefactos y Secretos
- **Firmado de Aplicaciones**: Almacenes de claves/perfiles de aprovisionamiento configurados en pipeline, nunca en repositorio.
- **Variables de Entorno**: Archivos `.env` específicos por ambiente (desarrollo, preparación, producción), excluidos de control de versiones.
- **Gestión de Secretos**: Uso de secretos de plataforma, variables de canalización o bóvedas de claves para credenciales sensibles.

### 8.5 Monitoreo y Observabilidad en Producción
- **Reporte de Fallos**: Integración preparada con plataformas de seguimiento con mapas de fuente.
- **Registros Estructurados**: Formato JSON con campos `nivel`, `funcionalidad`, `usuario_id` (anonimizado), `id_sesion`, `marca_tiempo`.
- **Métricas de Negocio**: Eventos personalizados para `pedido_completado`, `alerta_inventario`, `inicio_sesion_exitoso` enviados a analíticas.
- **Alertas Proactivas**: Configuración de umbrales para notificar ante picos de errores, latencia alta o caída de conversión.

---

## 📋 9. PROTOCOLOS DE EJECUCIÓN PARA LA INTELIGENCIA ARTIFICIAL

### ❌ PROHIBICIONES ABSOLUTAS (Cero Tolerancia)
- **NO usar `establecer_estado`** para lógica asíncrona, flujos de negocio complejos o gestión de estado compartido.
- **NO incrustar directamente** cadenas de interfaz, colores, rutas, umbrales de negocio o mensajes de error. Todo debe vivir en: `LocalizacionesAplicacion`, `TokensDisenoBK`, `RutasAplicacion`, `ConfiguracionNegocio`.
- **NO omitir** validación de entrada en modelos de transferencia, manejo explícito de errores (cargando/éxito/error), o estados de carga en la interfaz.
- **NO generar** código tipo tutorial, ejemplos incompletos, `// PENDIENTE:` sin ticket asociado, o `imprimir()` para depuración en producción.
- **NO mezclar capas arquitectónicas**. `presentacion` NUNCA importa directamente de `datos`. La comunicación es siempre vía interfaces de `dominio`.
- **NO ignorar** gestión de recursos: `liberar()` de controladores, `cancelar()` de flujos, limpieza de escuchas en `al_liberar` de componentes de lógica.

### ✅ ESTÁNDARES DE ENTREGA OBLIGATORIOS
- **Código "Listo para Ejecutar"**: Ejecutable con `flutter pub get` y `flutter run` sin advertencias ni errores de compilación.
- **Tipado Fuerte 100%**: Firmas de funciones, variables, parámetros y retornos explícitamente tipados. Cero `dinámico` sin justificación técnica documentada con comentario `// ignorar: tipado_estRICTo`.
- **Manejo Funcional de Errores**: Uso de `Union<Fallo, T>` o patrón `Resultado<T>` personalizado para flujos que pueden fallar.
- **Documentación Inline Estratégica**: Comentarios `///` para reglas de negocio complejas, decisiones arquitectónicas no obvias, o soluciones técnicas justificadas.
- **Estructura de Archivos Idéntica**: Respeto absoluto a la estructura de carpetas especificada. Desviaciones requieren aprobación explícita.

---

## 📥 10. TAREA INICIAL: ENTREGABLES Y CRITERIOS DE ACEPTACIÓN

### 🎯 Objetivo de la Fase 1
Materializar la base técnica del sistema con código auditable, testeable y listo para integración en un repositorio empresarial.

### 📁 Estructura de Archivos Esperada (Entrega Mínima)
```
lib/
├── nucleo/
│   └── constantes/tokens_diseno_bk.dart      # Tokens de diseño centralizados
├── funcionalidades/
│   ├── tema/
│   │   └── datos_tema_bk.dart                # Configuración completa de tema con extensión BK
│   ├── inventario/
│   │   ├── dominio/
│   │   │   └── entidades/inventario.dart     # Entidad pura de dominio
│   │   └── datos/
│   │       └── modelos/modelo_inventario.dart # Modelo con serialización JSON/SQL
│   ├── pedidos/
│   │   ├── dominio/
│   │   │   ├── entidades/pedido.dart
│   │   │   └── entidades/detalle_pedido.dart
│   │   └── datos/
│   │       └── modelos/modelo_pedido.dart
│   └── tablero/
│       ├── presentacion/
│       │   ├── bloc/
│       │   │   ├── bloque_tablero.dart
│       │   │   ├── evento_tablero.dart
│       │   │   └── estado_tablero.dart
│       │   └── pantallas/
│       │       └── pantalla_tablero.dart     # Interfaz responsiva principal
└── inyeccion/
    └── configuracion.dart                    # Configuración base de inyección de dependencias
```

### ✅ Criterios de Aceptación Detallados

#### 1. `datos_tema_bk.dart` - Sistema de Temas Completo
- [ ] `esquema_color` con `primario`, `secundario`, `error`, `superficie`, `fondo` alineados a tokens BK.
- [ ] `texto_tipo` con estilos para `pantalla_grande`, `titular_medio`, `cuerpo_grande`, `etiqueta_pequena` usando tipografía corporativa.
- [ ] `tema_boton_elevado`, `tema_boton_texto`, `tema_boton_contorno` con estados (habilitado, deshabilitado, presionado, sobre).
- [ ] `tema_tarjeta`, `tema_decoracion_entrada`, `tema_aviso_rapido`, `tema_dialogo` consistentes con la identidad visual.
- [ ] Soporte nativo para `ModoTema.sistema` con definición explícita de modo claro y oscuro.
- [ ] Extensión `Contexto` con accesores: `contexto.tema.es_oscuro`, `contexto.colores.rojoLlama`.

#### 2. Entidades + Modelos - Capa de Dominio y Datos
- [ ] Uso de `@congelado` con `serializable_json` para generación automática de `desde_json`/`a_json`.
- [ ] Validación de llaves foráneas: campos como `id_sucursal`, `id_producto`, `id_pedido` marcados como `obligatorio` y tipados como `IdentificadorUnico` o `entero`.
- [ ] Métodos de mapeo explícitos: `a_entidad()` en Modelos, `a_modelo()` en Entidades para conversión bidireccional.
- [ ] Inmutabilidad garantizada: todas las entidades son `@inmutable` o `congelado` sin establecedores públicos.
- [ ] Comentarios de documentación `///` explicando reglas de negocio asociadas a cada campo crítico.

#### 3. `pantalla_tablero.dart` - Interfaz Principal Responsiva
- [ ] Maquetación adaptativa con `ConstructorDiseno` o paquete `constructor_responsivo` para cambio móvil/tableta/escritorio.
- [ ] Bloque de lógica conectado a repositorio simulado con datos tipados, manejando estados: `CargandoTablero`, `TableroCargado`, `ErrorTablero`.
- [ ] Componentes reutilizables: `TarjetaAlertaInventario` (con insignia de urgencia), `ResumenVentasDiarias` (gráfico simple), `FilaAccionesRapidas` (botones de acceso rápido).
- [ ] Uso intensivo de `const` en componentes estáticos, `CajaDimensionada` para espaciado, `Acolchado` temático vía `Tema.del(contexto).espaciado`.
- [ ] Accesibilidad: `Semantica` en tarjetas interactivas, contraste de colores validado, áreas táctiles ≥48x48 píxeles independientes de densidad.
- [ ] Manejo de errores: interfaz de respaldo con botón de reintento, mensajes de error localizados, registro estructurado.

#### 4. Calidad de Código y Análisis Estático
- [ ] Cero advertencias de `flutter analyze` con configuración `muy_buen_analisis`.
- [ ] Cero uso de `dinámico` no justificado. Si es absolutamente necesario, debe llevar `// ignorar: tipado_estRICTo` con explicación.
- [ ] Manejo de errores explícito en todos los flujos asíncronos: intentar/atrapar con mapeo a `Fallo` o uso de `Union`.
- [ ] Pruebas unitarias básicas para bloque de lógica y casos de uso generadas junto con el código (aunque sea esqueleto).

#### 5. Documentación Técnica Adjunta (archivo de lectura o comentario inicial)
- [ ] **Aislamiento por Sucursal**: Explicación de cómo se implementa el alcance de consultas (`DONDE id_sucursal = ?`), inyección de dependencias por sucursal (`registro_fabrica_parametro`), y particionamiento de caché local.
- [ ] **Control de Inventario en Tiempo Real**: Descripción de transacciones atómicas en base de datos local, implementación del algoritmo PEPS, disparadores de punto de reorden automáticos, y estrategia de reconciliación sin conexión-con conexión.
- [ ] **Resolución de Conflictos sin Conexión**: Estrategia elegida (última escritura válida, fusión automática, o conflicto manual), estructura de la cola de operaciones pendientes, y manejo de escenarios de red intermitente.

---

## 🟢 CONFIRMACIÓN DE ARRANQUE - PROTOCOLO DE RESPUESTA

Si has comprendido íntegramente:
- ✅ El alcance estratégico y las restricciones de negocio
- ✅ La arquitectura limpia y sus reglas inquebrantables  
- ✅ El sistema de diseño tokenizado y los requisitos de accesibilidad
- ✅ Los estándares de calidad, pruebas y preparación para automatización
- ✅ Los protocolos de ejecución y las prohibiciones absolutas

**Responde ÚNICAMENTE con la siguiente línea para confirmar:**

```
[ARQUITECTO LISTO - BK-OS v1.0 - INICIANDO CONSTRUCCIÓN]
```

Y procede inmediatamente a generar en este orden:
1. 🎨 `datos_tema_bk.dart` completo con temas claro/oscuro y extensiones de contexto.
2. 🗃️ Entidades + Modelos para `Inventario`, `Pedido`, `DetallePedido` con validación, serialización y mapeo bidireccional.
3. 🖥️ `pantalla_tablero.dart` con bloque de lógica, maquetación responsiva, manejo de estados y componentes reutilizables.
4. 📝 Explicación técnica concisa (máx. 300 palabras) de: aislamiento por sucursal + control de inventario en tiempo real + estrategia sin conexión.

**¿Confirmas recepción de especificaciones y estás listo para compilar la arquitectura empresarial?** 🚀👑
