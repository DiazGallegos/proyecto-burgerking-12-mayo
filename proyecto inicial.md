actúa como un administrador  de base de datos :proyecto burger king que entidades se necesitan para su gestion
<img width="580" height="805" alt="image" src="https://github.com/user-attachments/assets/c60836b6-11ff-45e1-8f41-1328d073ba2d" />



¡Excelente estructura! Se nota que has pensado en la escalabilidad, especialmente con la separación de **Inventario** y **Auditoría**.

Para avanzar, he diseñado el **Diagrama Entidad-Relación (ERD)** del dominio más crítico: **Ventas y Pedidos**, integrando sus conexiones naturales con **Productos** y **Clientes**. Este es el motor transaccional que permite que el resto del sistema tenga sentido.

---

## 📊 Modelo ERD: Dominio de Ventas y Transacciones

Este esquema utiliza la notación de "Pata de Gallo" (Crow's Foot) para representar las relaciones.

### 1. Diccionario de Entidades y Atributos

| Entidad | Atributos Principales (PK / FK) | Descripción |
| --- | --- | --- |
| **Pedido** | `ID_Pedido` (PK), `ID_Cliente` (FK), `ID_Sucursal` (FK), `Fecha`, `Canal`, `Total` | El encabezado de la venta. El "Canal" distingue si es App, Drive-thru, etc. |
| **Detalle_Pedido** | `ID_Detalle` (PK), `ID_Pedido` (FK), `ID_Producto` (FK), `Cantidad`, `Precio_Unitario` | Tabla intermedia que rompe la relación N:M entre Pedidos y Productos. |
| **Producto** | `ID_Producto` (PK), `ID_Categoria` (FK), `Nombre`, `Precio_Base`, `Calorias` | El catálogo de lo que se vende. |
| **Pago** | `ID_Pago` (PK), `ID_Pedido` (FK), `Metodo_Pago`, `Monto`, `Estado_Transaccion` | Registra si el pago fue aprobado, pendiente o rechazado. |
| **Promocion** | `ID_Promo` (PK), `Codigo`, `Descuento_Porcentaje`, `Fecha_Expiracion` | Se vincula al Pedido para aplicar reglas de negocio. |

---

### 2. Relaciones Lógicas (Cardinaridad)

1. **Cliente a Pedido (1:N):** Un cliente puede realizar muchos pedidos a lo largo del tiempo, pero un pedido pertenece a un solo cliente (o puede ser anónimo).
2. **Pedido a Detalle_Pedido (1:N):** Un pedido contiene múltiples líneas de detalle (varios productos).
3. **Producto a Detalle_Pedido (1:N):** Un producto puede aparecer en los detalles de muchos pedidos diferentes.
4. **Pedido a Pago (1:1 o 1:N):** Normalmente un pedido tiene un pago, pero el modelo permite "pagos divididos" si se requiere.
5. **Sucursal a Pedido (1:N):** Cada pedido se origina y procesa en una sucursal específica.

---

### 3. Consideraciones Técnicas

* **Precio en Detalle_Pedido:** Es vital duplicar el precio en la tabla `Detalle_Pedido`. Si el precio del `Producto` cambia mañana, los registros históricos de ventas no deben alterarse.
* **Trazabilidad:** El campo `Canal` en la entidad **Pedido** es el que te permitirá hacer analítica tipo: *"¿Cuál es el ticket promedio en Drive-thru vs. App?"*.

¿Te gustaría que desarrolle ahora el dominio de **Inventario y Operaciones** para ver cómo se descuentan los ingredientes automáticamente cuando se vende un producto?


las entidades con sus atributos y tipo en forma de tabla para cada una de las entidades
<img width="626" height="748" alt="image" src="https://github.com/user-attachments/assets/619aafff-a6e9-4e47-b192-6bdab5a08afd" />
<img width="592" height="742" alt="image" src="https://github.com/user-attachments/assets/815dffcb-d179-4e96-9502-4bcf5f332d0d" />
<img width="670" height="627" alt="image" src="https://github.com/user-attachments/assets/ab7af06b-f3f2-4f92-905e-1b8c20600395" />
<img width="591" height="589" alt="image" src="https://github.com/user-attachments/assets/469befbb-1e0e-4fbe-b9c6-d43221279588" />
<img width="682" height="614" alt="image" src="https://github.com/user-attachments/assets/310530ab-240c-4e13-95b6-0113e7f28aee" />
<img width="679" height="677" alt="image" src="https://github.com/user-attachments/assets/15642317-df67-4000-9868-643c19e8441e" />
<img width="651" height="278" alt="image" src="https://github.com/user-attachments/assets/a5eb0269-56d8-4c2b-bb66-143cdca92b7f" />


