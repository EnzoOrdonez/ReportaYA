# Pruebas de sistema ReportaYA

Backend: http://127.0.0.1:8081
Fecha: 2026-11-27 00:17

Aprobados 57 de 57

| ID | Requisito | Tecnica | Caso | Esperado | Obtenido | Resultado |
|---|---|---|---|---|---|---|
| CP-01 | RF-02 / HU-02 | PE | Inicio de sesion con credenciales validas de cada rol | 200 y token con el rol correcto | 200 {'ciudadano': 'CIUDADANO', 'op.maria': 'OPERADOR_MUNICIPAL', 'tec.carlos': 'TECNICO'} | Aprobado |
| CP-02 | RF-02 / HU-02 | PE | Contrasena incorrecta | 401 con mensaje en espanol | 401 {"error":"Usuario o contraseña inválidos"} | Aprobado |
| CP-03 | RF-02 / RNF-03 | EG | Usuario inexistente responde igual que clave incorrecta | 401 con el mismo mensaje que CP-02 | 401 {"error":"Usuario o contraseña inválidos"} | Aprobado |
| CP-04 | RF-02 | PE | Usuario o contrasena vacios | 400 | 400 {"error":"must not be blank"} | Aprobado |
| CP-05 | RNF-03 | PE | Ruta protegida sin token | 401 | 401 {"error":"Token no proporcionado"} | Aprobado |
| CP-06 | RNF-03 | EG | Token alterado (firma invalida) | 401 | 401 {"error":"Token invalido o expirado"} | Aprobado |
| CP-07 | RNF-03 | VL | Token vencido (exp un segundo en el pasado) | 401 | 401 {"error":"Token invalido o expirado"} | Aprobado |
| CP-08 | RF-01 / HU-01 | PE | Registro de ciudadano con datos validos | 201, cuenta CIUDADANO activa y puede iniciar sesion | 201 {"tipoCuenta":"CIUDADANO","usuario":"u894luk","contrasena":null,"nombres":"Prueba","apelli | Aprobado |
| CP-09 | RF-01 | PE | Usuario, DNI o correo ya registrados | 400 con mensaje claro en los tres casos | [('usuario', 400, 'El usuario ya esta en uso. Elige otro.'), ('dni', 400, 'Ya existe una cuenta con ese DNI.'), ('correo', 400, 'Ya existe una cuenta con ese correo.')] | Aprobado |
| CP-10 | RF-01 | VL | DNI de 7, 8 y 9 digitos | 400, 201, 400 | [400, 201, 400] | Aprobado |
| CP-11 | RF-01 | PE | DNI de 8 caracteres no numericos | 400 | 400 {"error":"El DNI debe tener 8 dígitos numéricos"} | Aprobado |
| CP-12 | RF-01 | VL | Contrasena de 5 y de 6 caracteres | 400 y 201 | [400, 201] | Aprobado |
| CP-13 | RF-01 | VL | Usuario de 2, 3, 50 y 51 caracteres | 400, 201, 201, 400 | [400, 201, 201, 400] | Aprobado |
| CP-14 | RF-01 | PE | Correo con formato invalido | 400 | 400 {"error":"El correo debe ser válido"} | Aprobado |
| CP-15 | RF-01 / RF-17 | TD | Registro publico pidiendo rol OPERADOR_MUNICIPAL o TECNICO | 400 en ambos (sin elevacion de privilegios) | [400, 400] | Aprobado |
| CP-16 | RF-03 / HU-05 | EG | Solicitud con correo registrado y no registrado | 200 con el mismo mensaje (no revela cuentas) | 200/200 mismo cuerpo=True | Aprobado |
| CP-17 | RF-03 / HU-05 | TE | Restablecer con codigo valido, luego reutilizarlo | 200, login con la nueva clave, 400 al reutilizar | 200, login 200, reuso 400 | Aprobado |
| CP-18 | RF-03 | VL | Codigo vencido (31 min) y clave nueva de 5 caracteres | 400 en ambos | clave corta 400, vencido 400 | Aprobado |
| CP-19 | RF-19 / HU-03 | PE | Crear reporte con datos validos | 201, estado PENDIENTE, codigo asignado e historial inicial | 201 {"id":1043,"titulo":"Poste caido en la vereda","descripcion":"Poste de alumbrado inclinado | Aprobado |
| CP-20 | RF-19 | PE | Una clase valida por cada tipo de problema | 201 en los 5 tipos | {'INFRAESTRUCTURA': 201, 'RESIDUOS': 201, 'SEGURIDAD': 201, 'ALUMBRADO': 201, 'OTRO': 201} | Aprobado |
| CP-21 | RF-19 | VL | Titulo vacio, de 255 y de 256 caracteres | 400, 201, 400 | [400, 201, 400] | Aprobado |
| CP-22 | RF-19 | VL | Descripcion de 1000 y de 1001 caracteres | 201 y 400 | [201, 400] | Aprobado |
| CP-23 | RF-05 / HU-17 | PE | Reporte sin ubicacion y sin latitud | 400 en ambos | 400, 400 | Aprobado |
| CP-24 | RF-05 | EG | Punto marcado en el mapa sin direccion geocodificada | 201 y direccion con las coordenadas | 201 {"id":1051,"titulo":"Poste caido en la vereda","descripcion":"Poste de alumbrado inclinado | Aprobado |
| CP-25 | RF-02 / RNF-03 | TD | Operador y tecnico intentan crear un reporte | 403 en ambos | [403, 403] | Aprobado |
| CP-26 | RNF-03 | EG | El cuerpo indica la cuenta de otro ciudadano | 201 y el reporte queda a nombre de la cuenta del token | 201 {"id":1052,"titulo":"Poste caido en la vereda","descripcion":"Poste de alumbrado inclinado | Aprobado |
| CP-27 | RF-06 | PE | Adjuntar foto PNG valida y descargarla | 201 y la descarga devuelve los mismos bytes | 201, descarga 200 identica=True | Aprobado |
| CP-28 | RF-06 | VL | Foto de 5 MB exactos y de 5 MB + 1 byte | 201 y 400 | [201, 400] | Aprobado |
| CP-29 | RF-06 | PE | Foto con base64 invalido y con tipo inexistente | 400 en ambos | 400, 400 | Aprobado |
| CP-30 | RF-06 / RNF-03 | TD | Foto en reporte ajeno y foto FINAL por el ciudadano duenio | 403 en ambos | 403, 403 | Aprobado |
| CP-31 | RF-13 / HU-07 | TD | Listar los reportes propios y los de otro ciudadano | 200 solo con reportes propios y 403 para los ajenos | 200 total=2 duenos={29}; ajeno 403 | Aprobado |
| CP-32 | RF-16 / HU-09 | TD | Ficha del reporte: duenio, otro ciudadano, operador, tecnico no asignado | 200, 403, 200, 403 | [200, 403, 200, 403] | Aprobado |
| CP-33 | RF-15 / HU-08 | PE | Mapa filtrado por estado y por tipo | 200 y todos los puntos cumplen el filtro | estado=20 tipo=3 ambos=3 | Aprobado |
| CP-34 | RF-15 | PE | Filtro de estado inexistente | 400 con mensaje | 400 {"error":"Valor invalido para 'estado': PERDIDO"} | Aprobado |
| CP-35 | RF-16 | PE | Reporte inexistente | 404 | 404 {"error":"Reporte no encontrado con id: 999999999"} | Aprobado |
| CP-36 | RF-07 / RNF-03 | TD | Bandeja general de reportes: ciudadano y operador | 403 y 200 | 403, 200 | Aprobado |
| CP-37 | RF-07 / HU-04 | TE | Operador acepta un reporte PENDIENTE | 200, estado REVISION e historial PENDIENTE -> REVISION | 200 {"id":1061,"titulo":"Poste caido en la vereda","descripcion":"Poste de alumbrado inclinado | Aprobado |
| CP-38 | RF-07 | TD | Ciudadano y tecnico intentan aceptar | 403 en ambos | [403, 403] | Aprobado |
| CP-39 | RF-07 / HU-04 | TE | Rechazar con motivo y rechazar sin motivo | 200 RECHAZADO con el motivo guardado; 400 sin motivo | 200 RECHAZADO motivo='Duplicado del reporte 1042'; sin motivo 400 | Aprobado |
| CP-40 | RF-07 / RF-24 | TE | Transiciones no permitidas: PENDIENTE -> FINALIZADO y salir de RECHAZADO | 400 en ambas | 400, 400 | Aprobado |
| CP-41 | RF-08 / HU-10 | TE | Asignar tecnico a reporte en REVISION y a reporte PENDIENTE | 201 y 400 | 201, 400 | Aprobado |
| CP-42 | RF-08 | PE | Asignar un tecnico inexistente y un ciudadano como tecnico | 4xx en ambos, sin cambios en el reporte | 400, 400, tecnico=None | Aprobado |
| CP-43 | RF-08 | TD | Ciudadano intenta asignar un tecnico | 403 | 403 {"error":"No tienes permiso para realizar esta accion."} | Aprobado |
| CP-44 | RF-09 / HU-11 | TD | Bandeja Mis tareas propia y de otro tecnico | 200 con el reporte asignado y 403 para la ajena | 200 contiene=True; ajena 403 | Aprobado |
| CP-45 | RF-11 / HU-12 | VL | Comentario de cierre de 9 y de 10 caracteres | 400 y 200 | 400, 200 | Aprobado |
| CP-46 | RF-06 / RF-11 | VL | Cierre con 4 fotos (maximo 3) | 400 y el reporte sigue en REVISION | 400, estado REVISION | Aprobado |
| CP-47 | RF-11 / HU-12 | PE | Cierre sin ninguna foto final | 400 (se exige al menos una fotografia) | 400 {"error":"Adjunta entre 1 y 3 fotos de la solución"} | Aprobado |
| CP-48 | RF-11 | EG | Cierre con una foto corrupta | 400 y el reporte sigue en REVISION sin fotos FINAL | 400 {"error":"La foto no es un base64 valido"}; estado REVISION, fotos FINAL 0 | Aprobado |
| CP-49 | RF-11 / RNF-03 | TD | Otro tecnico intenta cerrar el reporte (con su id y con el id del asignado) | 403 en ambos | 400, 403 | Aprobado |
| CP-50 | RF-11 / RF-13 / HU-07 | TE | Flujo completo PENDIENTE -> REVISION -> FINALIZADO visto por el ciudadano | 200; FINALIZADO con comentario, foto FINAL e historial de 3 estados | 200; FINALIZADO; fotos FINAL 1; historial ['FINALIZADO', 'PENDIENTE', 'REVISION'] | Aprobado |
| CP-51 | RF-11 | TE | Cerrar dos veces el mismo reporte y rechazar uno FINALIZADO | 400 en ambos (estado terminal) | 400, 400 | Aprobado |
| CP-52 | RNF-03 | EG | Las contrasenas se guardan con BCrypt | Ningun hash en texto plano | 50 cuentas, 0 sin BCrypt | Aprobado |
| CP-53 | RNF-03 | TD | CORS: origen de la version web y origen desconocido | Cabecera permitida para localhost y 403 para el desconocido | 200 http://localhost:8080; 403 | Aprobado |
| CP-54 | RNF-03 | EG | Errores de validacion y de base sin trazas internas | Mensajes sin SQL, clases Java ni stack trace | 0 respuestas con detalles internos | Aprobado |
| CP-55 | RNF-03 | PE | Chequeo de salud del servicio | 200 con estado ok y base ok | 200 {"base":"ok","estado":"ok"} | Aprobado |
| CP-56 | RF-06 / HU-03 | VL | Tercera y cuarta foto INICIAL del mismo reporte | 201 y 400 (de una a tres fotos) | [201, 201, 201, 400] | Aprobado |
| CP-57 | RF-01 | PE | Telefono de 8 digitos y con letras | 400 en ambos | [400, 400] | Aprobado |
