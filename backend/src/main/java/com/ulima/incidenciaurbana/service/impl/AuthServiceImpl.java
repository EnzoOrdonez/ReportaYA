package com.ulima.incidenciaurbana.service.impl;

import com.ulima.incidenciaurbana.exception.TooManyAttemptsException;
import com.ulima.incidenciaurbana.util.LimitadorIntentosLogin;
import com.ulima.incidenciaurbana.util.RegistroSesiones;

import com.ulima.incidenciaurbana.dto.LoginRequest;
import com.ulima.incidenciaurbana.dto.LoginResponse;
import com.ulima.incidenciaurbana.exception.EmailNotVerifiedException;
import com.ulima.incidenciaurbana.exception.InvalidCredentialsException;
import com.ulima.incidenciaurbana.model.Cuenta;
import com.ulima.incidenciaurbana.repository.CuentaRepository;
import com.ulima.incidenciaurbana.service.AuthService;
import com.ulima.incidenciaurbana.service.IEmailService;
import com.ulima.incidenciaurbana.util.JwtUtil;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.UUID;

@Service
public class AuthServiceImpl implements AuthService {

    private static final int MINUTOS_VALIDEZ_RECUPERACION = 30;
    // Codigo corto de recuperacion (Opcion B): el usuario lo escribe en la app.
    // Alfabeto sin caracteres ambiguos (0/O, 1/I/L) para que sea facil de leer.
    private static final String ALFABETO_CODIGO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private static final int LONGITUD_CODIGO = 6;
    /** HU-01: contraseña de al menos 8 caracteres. */
    public static final int MIN_CONTRASENA = 8;
    private static final SecureRandom RANDOM = new SecureRandom();

    private final CuentaRepository cuentaRepository;
    private final BCryptPasswordEncoder passwordEncoder;
    private final JwtUtil jwtUtil;
    private final IEmailService emailService;
    private final String hashFicticio;
    private final LimitadorIntentosLogin limitador;
    private final RegistroSesiones registroSesiones;
    /** Contador aparte para los códigos de recuperación (clave = correo). */
    private final LimitadorIntentosLogin limitadorRecuperacion = new LimitadorIntentosLogin();

    public AuthServiceImpl(CuentaRepository cuentaRepository,
                           BCryptPasswordEncoder passwordEncoder,
                           JwtUtil jwtUtil,
                           IEmailService emailService,
                           LimitadorIntentosLogin limitador,
                           RegistroSesiones registroSesiones) {
        this.limitador = limitador;
        this.registroSesiones = registroSesiones;
        this.cuentaRepository = cuentaRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtUtil = jwtUtil;
        this.emailService = emailService;
        this.hashFicticio = passwordEncoder.encode("usuario-inexistente");
    }

    @Override
    @Transactional
    public LoginResponse login(LoginRequest request) {
        // Tras 5 fallos seguidos el usuario queda bloqueado 5 minutos (exista o no,
        // para no revelar qué cuentas existen).
        if (limitador.bloqueado(request.getUsuario())) {
            throw new TooManyAttemptsException(LimitadorIntentosLogin.BLOQUEO.toMinutes());
        }
        Cuenta c = cuentaRepository.findByUsuario(request.getUsuario()).orElse(null);
        if (c == null) {
            // Mismo costo que una contrasena incorrecta: no revela si el usuario existe.
            passwordEncoder.matches(request.getPassword(), hashFicticio);
            limitador.registrarFallo(request.getUsuario());
            throw new InvalidCredentialsException();
        }

        // Solo se aceptan hashes BCrypt. Las contrasenas en texto plano heredadas
        // (datos semilla antiguos) las convierte PasswordMigration al arrancar.
        String stored = c.getContrasenaHash();
        if (stored == null || !isBcryptHash(stored)
                || !passwordEncoder.matches(request.getPassword(), stored)) {
            limitador.registrarFallo(request.getUsuario());
            throw new InvalidCredentialsException();
        }
        limitador.registrarExito(request.getUsuario());

        // Credenciales correctas pero la cuenta aún no verificó su correo.
        // Se comprueba DESPUÉS del password para no revelar cuentas por el usuario.
        if (!c.isActivo()) {
            throw new EmailNotVerifiedException();
        }

        String nombre = (c.getPersona() != null) ? c.getPersona().getNombreCompleto() : "";
        String token = jwtUtil.generateToken(c.getId(), c.getUsuario(), c.getTipoCuenta());
        return new LoginResponse(c.getId(), c.getUsuario(), nombre, "Login exitoso", c.getTipoCuenta(), token);
    }

    @Override
    @Transactional
    public void solicitarRecuperacion(String correo) {
        if (correo == null || correo.trim().isEmpty()) {
            throw new RuntimeException("El correo es obligatorio");
        }

        // Respuesta uniforme: si el correo no existe no se informa (anti-enumeracion),
        // igual que dice el mensaje del controlador.
        Cuenta cuenta = cuentaRepository.findByCorreoAndActivoTrue(correo.trim()).orElse(null);
        if (cuenta == null) return;

        String token = generarCodigoRecuperacion();
        cuenta.asignarTokenRecuperacion(token, LocalDateTime.now().plusMinutes(MINUTOS_VALIDEZ_RECUPERACION));
        cuentaRepository.save(cuenta);

        emailService.enviarRecuperacionContrasena(
                cuenta.getPersona().getCorreo(),
                cuenta.getPersona().getNombres(),
                token);
    }

    @Override
    @Transactional
    public void cerrarSesion(Long cuentaId) {
        cuentaRepository.findById(cuentaId).ifPresent(cuenta -> {
            java.time.LocalDateTime corte = cuenta.revocarSesiones();
            cuentaRepository.save(cuenta);
            registroSesiones.revocadas(cuenta.getId(), corte);
        });
    }

    @Override
    @Transactional
    public void restablecerContrasena(String correo, String token, String nuevaContrasena) {
        if (correo == null || correo.trim().isEmpty()) {
            throw new RuntimeException("El correo es obligatorio");
        }
        if (token == null || token.trim().isEmpty()) {
            throw new RuntimeException("El código de recuperación es obligatorio");
        }
        if (nuevaContrasena == null || nuevaContrasena.length() < MIN_CONTRASENA) {
            throw new RuntimeException("La contraseña debe tener al menos " + MIN_CONTRASENA + " caracteres");
        }
        // Fuerza bruta: el código está ligado al correo y tras 5 fallos seguidos
        // ese correo queda bloqueado 5 minutos (mismo criterio que el login).
        String correoLimpio = correo.trim();
        if (limitadorRecuperacion.bloqueado(correoLimpio)) {
            throw new TooManyAttemptsException(LimitadorIntentosLogin.BLOQUEO.toMinutes());
        }

        Cuenta cuenta = cuentaRepository.findByTokenRecuperacion(token.trim().toUpperCase(java.util.Locale.ROOT))
                .filter(c -> c.getPersona() != null && c.getPersona().getCorreo() != null
                        && c.getPersona().getCorreo().equalsIgnoreCase(correoLimpio))
                .orElse(null);
        if (cuenta == null) {
            limitadorRecuperacion.registrarFallo(correoLimpio);
            throw new RuntimeException("Código de recuperación inválido o ya utilizado");
        }
        limitadorRecuperacion.registrarExito(correoLimpio);

        if (cuenta.tokenRecuperacionExpirado()) {
            cuenta.limpiarTokenRecuperacion();
            cuentaRepository.save(cuenta);
            throw new RuntimeException("El código de recuperación ha expirado. Solicita uno nuevo.");
        }

        cuenta.cambiarContrasena(passwordEncoder.encode(nuevaContrasena));
        cuenta.limpiarTokenRecuperacion();
        // HU-05 CA2: la nueva contraseña revoca las sesiones abiertas.
        java.time.LocalDateTime corte = cuenta.revocarSesiones();
        cuentaRepository.save(cuenta);
        registroSesiones.revocadas(cuenta.getId(), corte);
    }

    // Codigo alfanumerico corto para el correo de recuperacion (Opcion B).
    private String generarCodigoRecuperacion() {
        StringBuilder sb = new StringBuilder(LONGITUD_CODIGO);
        for (int i = 0; i < LONGITUD_CODIGO; i++) {
            sb.append(ALFABETO_CODIGO.charAt(RANDOM.nextInt(ALFABETO_CODIGO.length())));
        }
        return sb.toString();
    }

    static boolean isBcryptHash(String value) {
        return value.startsWith("$2a$") || value.startsWith("$2b$") || value.startsWith("$2y$");
    }
}
