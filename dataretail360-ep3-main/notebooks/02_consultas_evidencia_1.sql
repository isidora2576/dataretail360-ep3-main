/* =====================================================================
   DataRetail 360 · EP3 IDY1102
   02 · Consultas de evidencia para las capturas del informe (SSMS)
   Ejecutar DESPUÉS del notebook 02. Cada bloque indica su captura.
   ===================================================================== 
   tratando de conectar al sql server*/
USE DataRetail360;
GO

/* ---- Captura 04 · SCD 2 de precio (NB-001) ------------------------- */
SELECT producto_key, sku, producto, precio_lista, fecha_inicio, fecha_fin, es_actual
FROM gold.dim_producto
WHERE sku = 'NB-001'
ORDER BY fecha_inicio;

/* ---- Captura 05 · SCD 2 de categoría (SW-011) ---------------------- */
SELECT producto_key, sku, producto, categoria, fecha_inicio, fecha_fin, es_actual
FROM gold.dim_producto
WHERE sku = 'SW-011'
ORDER BY fecha_inicio;

/* ---- Captura 06 · SCD 1 de marca (MS-008) -------------------------- */
SELECT producto_key, sku, producto, marca, fecha_inicio, fecha_fin, es_actual
FROM gold.dim_producto
WHERE sku = 'MS-008';
-- Comparar con el valor original que llegó en Bronze:
SELECT version, sku, '[' + marca + ']' AS marca_tal_cual_llego
FROM bronze.productos_raw
WHERE sku = 'MS-008';

/* ---- Captura 07 · SCD 2 de cliente --------------------------------- */
-- Un cliente que cambió de segmento: dos versiones consecutivas
SELECT TOP 2 c.cliente_key, LEFT(c.id_cliente, 16) + '…' AS id_cliente, c.segmento,
       g.comuna, g.region, c.fecha_inicio, c.fecha_fin, c.es_actual
FROM gold.dim_cliente c
JOIN gold.dim_geografia g ON c.geografia_key = g.geografia_key
WHERE c.id_cliente = (SELECT TOP 1 id_cliente FROM gold.dim_cliente
                      GROUP BY id_cliente HAVING COUNT(*) > 1 ORDER BY id_cliente)
ORDER BY c.fecha_inicio;

-- Cuántos clientes tienen más de una versión
SELECT COUNT(*) AS clientes_con_historial
FROM (SELECT id_cliente FROM gold.dim_cliente GROUP BY id_cliente HAVING COUNT(*) > 1) t;

/* ---- Captura 08 · SCD 3 de sucursal -------------------------------- */
SELECT sucursal_key, cod_sucursal, sucursal, formato_actual, formato_anterior, fecha_cambio_formato
FROM gold.dim_sucursal
ORDER BY sucursal_key;

/* ---- Captura 09 · SCD 2 aplicado en los hechos (NB-001 por mes) ---- */
SELECT f.nombre_mes, v.producto_key, p.precio_lista,
       MIN(v.precio_unitario) AS precio_unitario_venta, COUNT(*) AS lineas
FROM gold.fact_ventas v
JOIN gold.dim_producto p ON v.producto_key = p.producto_key
JOIN gold.dim_fecha f    ON v.fecha_key = f.fecha_key
WHERE p.sku = 'NB-001'
GROUP BY f.mes, f.nombre_mes, v.producto_key, p.precio_lista
ORDER BY f.mes;

/* ---- Captura 24 · Cuarentena por motivo ---------------------------- */
SELECT motivo, COUNT(*) AS filas, MIN(archivo_origen) AS primer_archivo, MAX(archivo_origen) AS ultimo_archivo
FROM silver.cuarentena_ventas
GROUP BY motivo;

SELECT TOP 5 id_venta, fecha, monto, motivo, archivo_origen
FROM silver.cuarentena_ventas;

-- Reglas de calidad aplicadas en la última ejecución
SELECT regla, dimension_dama, filas, accion FROM silver.reglas_calidad WHERE filas > 0;

/* ---- Captura 30 · Conteos por capa --------------------------------- */
SELECT 'bronze.ventas_raw'       AS tabla, COUNT(*) AS filas FROM bronze.ventas_raw
UNION ALL SELECT 'silver.ventas',            COUNT(*) FROM silver.ventas
UNION ALL SELECT 'silver.cuarentena_ventas', COUNT(*) FROM silver.cuarentena_ventas
UNION ALL SELECT 'gold.fact_ventas',         COUNT(*) FROM gold.fact_ventas
UNION ALL SELECT 'gold.fact_campana_diaria', COUNT(*) FROM gold.fact_campana_diaria
UNION ALL SELECT 'gold.fact_resultado_mensual', COUNT(*) FROM gold.fact_resultado_mensual;

-- Historial de ejecuciones
SELECT * FROM audit.log_ejecuciones ORDER BY inicio DESC;

/* ---- Captura 31 · Consulta analítica sobre la estrella ------------- */
SELECT f.nombre_mes, g.region, p.categoria,
       SUM(v.monto_neto) AS monto_neto, SUM(v.margen) AS margen
FROM gold.fact_ventas v
JOIN gold.dim_fecha f     ON v.fecha_key = f.fecha_key
JOIN gold.dim_sucursal s  ON v.sucursal_key = s.sucursal_key
JOIN gold.dim_geografia g ON s.geografia_key = g.geografia_key
JOIN gold.dim_producto p  ON v.producto_key = p.producto_key
GROUP BY f.mes, f.nombre_mes, g.region, p.categoria
ORDER BY f.mes, monto_neto DESC;

/* ---- Captura 32 · Trazabilidad de una línea (Gold ← Bronze) -------- */
DECLARE @id INT = (SELECT TOP 1 TRY_CAST(id_venta AS INT)
                   FROM bronze.ventas_raw
                   WHERE sku COLLATE Latin1_General_CS_AS <> UPPER(sku)   -- SKU que llegó en minúsculas
                   ORDER BY TRY_CAST(id_venta AS INT));
SELECT 'gold' AS capa, CAST(v.id_venta AS NVARCHAR(20)) AS id_venta, p.sku, v.archivo_origen, v.run_id, v.fecha_carga
FROM gold.fact_ventas v JOIN gold.dim_producto p ON v.producto_key = p.producto_key
WHERE v.id_venta = @id
UNION ALL
SELECT 'bronze', b.id_venta, '[' + b.sku + ']', b.archivo_origen, b.run_id, b.fecha_carga
FROM bronze.ventas_raw b
WHERE TRY_CAST(b.id_venta AS INT) = @id;

/* ---- Captura 33 · Ausencia de datos personales --------------------- */
SELECT TOP 5 cliente_key, id_cliente, segmento, geografia_key, fecha_inicio, fecha_fin, es_actual
FROM gold.dim_cliente
WHERE cliente_key > 0;

-- Columnas de dim_cliente (no existe rut, nombre, email ni teléfono)
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'gold' AND TABLE_NAME = 'dim_cliente';

/* ---- Captura 34 · Data marts de Marketing y Finanzas --------------- */
SELECT TOP 10 f.fecha, c.campana, cn.canal, s.sucursal, m.lineas_vendidas, m.unidades,
       m.descuento_total, m.monto_neto
FROM gold.fact_campana_diaria m
JOIN gold.dim_fecha f    ON m.fecha_key = f.fecha_key
JOIN gold.dim_campana c  ON m.campana_key = c.campana_key
JOIN gold.dim_canal cn   ON m.canal_key = cn.canal_key
JOIN gold.dim_sucursal s ON m.sucursal_key = s.sucursal_key
WHERE m.campana_key > 0
ORDER BY m.monto_neto DESC;

SELECT TOP 10 f.nombre_mes, p.categoria, s.sucursal, r.ingreso_neto, r.costo_total, r.margen,
       r.cantidad_devuelta, r.monto_devuelto
FROM gold.fact_resultado_mensual r
JOIN gold.dim_fecha f    ON r.fecha_key = f.fecha_key
JOIN gold.dim_producto p ON r.producto_key = p.producto_key
JOIN gold.dim_sucursal s ON r.sucursal_key = s.sucursal_key
ORDER BY r.margen DESC;

-- Los tres hechos cuadran en monto neto
SELECT (SELECT SUM(monto_neto)   FROM gold.fact_ventas)            AS ventas_monto_neto,
       (SELECT SUM(monto_neto)   FROM gold.fact_campana_diaria)    AS marketing_monto_neto,
       (SELECT SUM(ingreso_neto) FROM gold.fact_resultado_mensual) AS finanzas_ingreso_neto;

/* ---- Captura 26 (complemento) · Integridad referencial ------------- */
SELECT fk.name AS foreign_key, OBJECT_NAME(fk.parent_object_id) AS tabla,
       OBJECT_NAME(fk.referenced_object_id) AS referencia
FROM sys.foreign_keys fk
ORDER BY tabla;

/* =====================================================================
   INVENTARIO DIARIO (FACT_INVENTARIO_DIARIO)
   ===================================================================== */

/* ---- Captura 37 · Inventario por capa y cuarentena ----------------- */
SELECT 'bronze.inventario_raw'        AS tabla, COUNT(*) AS filas FROM bronze.inventario_raw
UNION ALL SELECT 'silver.inventario',            COUNT(*) FROM silver.inventario
UNION ALL SELECT 'silver.cuarentena_inventario', COUNT(*) FROM silver.cuarentena_inventario
UNION ALL SELECT 'gold.fact_inventario_diario',  COUNT(*) FROM gold.fact_inventario_diario;

SELECT motivo, COUNT(*) AS filas FROM silver.cuarentena_inventario GROUP BY motivo;

SELECT regla, dimension_dama, filas, accion
FROM silver.reglas_calidad
WHERE tabla = 'inventario' AND filas > 0;

/* ---- Captura 38 · Medida semi-aditiva: stock promedio por mes ------ */
-- El stock NO se suma entre días: se promedia (o se toma el último día del mes).
SELECT f.nombre_mes, t.categoria,
       AVG(CAST(t.stock_dia AS DECIMAL(18,2)))  AS stock_promedio_diario,
       AVG(t.valor_dia)                         AS valor_inventario_promedio
FROM (SELECT i.fecha_key, p.categoria,
             SUM(i.cantidad_stock)   AS stock_dia,      -- se suma entre sucursales y productos del mismo día
             SUM(i.valor_inventario) AS valor_dia
      FROM gold.fact_inventario_diario i
      JOIN gold.dim_producto p ON i.producto_key = p.producto_key
      GROUP BY i.fecha_key, p.categoria) t
JOIN gold.dim_fecha f ON t.fecha_key = f.fecha_key
GROUP BY f.mes, f.nombre_mes, t.categoria
ORDER BY f.mes, t.categoria;

/* ---- Captura 39 · Productos bajo stock mínimo y cruce con ventas --- */
SELECT TOP 15 f.fecha, s.sucursal, p.sku, p.producto,
       i.cantidad_stock, i.stock_minimo,
       ISNULL(v.unidades_vendidas, 0) AS unidades_vendidas_ese_dia
FROM gold.fact_inventario_diario i
JOIN gold.dim_fecha f    ON i.fecha_key = f.fecha_key
JOIN gold.dim_sucursal s ON i.sucursal_key = s.sucursal_key
JOIN gold.dim_producto p ON i.producto_key = p.producto_key
LEFT JOIN (SELECT fecha_key, sucursal_key, producto_key, SUM(cantidad) AS unidades_vendidas
           FROM gold.fact_ventas
           GROUP BY fecha_key, sucursal_key, producto_key) v
       ON v.fecha_key = i.fecha_key AND v.sucursal_key = i.sucursal_key AND v.producto_key = i.producto_key
WHERE i.cantidad_stock < i.stock_minimo
ORDER BY f.fecha, s.sucursal;
