-- Creación de la base de datos
CREATE DATABASE bd_burgerking;
USE bd_burgerking;

-- 1. Entidad: ROL
CREATE TABLE ROL (
    id_rol INT PRIMARY KEY,
    nombre VARCHAR(100),
    descripcion VARCHAR(255)
);

-- 2. Entidad: SUCURSAL
CREATE TABLE SUCURSAL (
    id_sucursal INT PRIMARY KEY,
    nombre VARCHAR(100),
    direccion VARCHAR(255),
    ciudad VARCHAR(100),
    telefono VARCHAR(20),
    estatus VARCHAR(50)
);

-- 3. Entidad: EMPLEADO
CREATE TABLE EMPLEADO (
    id_empleado INT PRIMARY KEY,
    id_sucursal INT,
    id_rol INT,
    nombre VARCHAR(100),
    apellido VARCHAR(100),
    fecha_contratacion DATE,
    salario DECIMAL(10, 2),
    FOREIGN KEY (id_sucursal) REFERENCES SUCURSAL(id_sucursal),
    FOREIGN KEY (id_rol) REFERENCES ROL(id_rol)
);

-- 4. Entidad: CLIENTE
CREATE TABLE CLIENTE (
    id_cliente INT PRIMARY KEY,
    nombre VARCHAR(150),
    email VARCHAR(150),
    telefono VARCHAR(20),
    fecha_registro DATE
);

-- 5. Entidad: METODO_PAGO
CREATE TABLE METODO_PAGO (
    id_pago INT PRIMARY KEY,
    tipo VARCHAR(50),
    descripcion VARCHAR(255)
);

-- 6. Entidad: CAJA
CREATE TABLE CAJA (
    id_caja INT PRIMARY KEY,
    id_sucursal INT,
    numero VARCHAR(20),
    estatus VARCHAR(50),
    FOREIGN KEY (id_sucursal) REFERENCES SUCURSAL(id_sucursal)
);

-- 7. Entidad: CATEGORIA
CREATE TABLE CATEGORIA (
    id_categoria INT PRIMARY KEY,
    nombre VARCHAR(100),
    descripcion VARCHAR(255)
);

-- 8. Entidad: PRODUCTO
CREATE TABLE PRODUCTO (
    id_producto INT PRIMARY KEY,
    id_categoria INT,
    nombre VARCHAR(150),
    descripcion TEXT,
    precio DECIMAL(10, 2),
    disponible BOOLEAN,
    FOREIGN KEY (id_categoria) REFERENCES CATEGORIA(id_categoria)
);

-- 9. Entidad: PEDIDO
CREATE TABLE PEDIDO (
    id_pedido INT PRIMARY KEY,
    id_caja INT,
    id_cliente INT,
    id_pago INT,
    fecha_hora DATETIME,
    total DECIMAL(10, 2),
    tipo VARCHAR(50),
    estatus VARCHAR(50),
    FOREIGN KEY (id_caja) REFERENCES CAJA(id_caja),
    FOREIGN KEY (id_cliente) REFERENCES CLIENTE(id_cliente),
    FOREIGN KEY (id_pago) REFERENCES METODO_PAGO(id_pago)
);

-- 10. Entidad: DETALLE_PEDIDO
CREATE TABLE DETALLE_PEDIDO (
    id_detalle INT PRIMARY KEY,
    id_pedido INT,
    id_producto INT,
    cantidad INT,
    precio_unitario DECIMAL(10, 2),
    personalizacion VARCHAR(255),
    FOREIGN KEY (id_pedido) REFERENCES PEDIDO(id_pedido),
    FOREIGN KEY (id_producto) REFERENCES PRODUCTO(id_producto)
);