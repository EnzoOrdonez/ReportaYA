package com.ulima.incidenciaurbana.controller;

import com.ulima.incidenciaurbana.util.ApiErrores;
import com.ulima.incidenciaurbana.util.JwtUtil;
import com.ulima.incidenciaurbana.util.LimitadorSolicitudes;
import io.jsonwebtoken.Claims;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import java.time.Duration;
import com.ulima.incidenciaurbana.dto.LoginRequest;
import com.ulima.incidenciaurbana.dto.LoginResponse;
import com.ulima.incidenciaurbana.service.AuthService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;
    private final JwtUtil jwtUtil;
    /** HU-05 CA1: 5 solicitudes de recuperación por hora por correo y por IP. */
    private final LimitadorSolicitudes recuperacionPorCorreo;
    private final LimitadorSolicitudes recuperacionPorIp;

    public AuthController(AuthService authService,
                          JwtUtil jwtUtil,
                          @Value("${app.recuperacion.max-por-hora:5}") int maxPorCorreo,
                          @Value("${app.recuperacion.max-por-hora-ip:5}") int maxPorIp) {
        this.authService = authService;
        this.jwtUtil = jwtUtil;
        this.recuperacionPorCorreo = new LimitadorSolicitudes(maxPorCorreo, Duration.ofHours(1));
        this.recuperacionPorIp = new LimitadorSolicitudes(maxPorIp, Duration.ofHours(1));
    }

    /**
     * HU-02 CA2: cerrar sesión invalida en el servidor los tokens de la cuenta
     * emitidos hasta ahora (en todos los dispositivos). Responde 200 aunque el
     * token ya no sirva, para que el cierre en la app nunca falle.
     */
    @PostMapping("/logout")
    public ResponseEntity<?> logout(@RequestHeader(value = "Authorization", required = false) String auth) {
        if (auth != null && auth.startsWith("Bearer ")) {
            try {
                Claims claims = jwtUtil.parseClaims(auth.substring(7));
                authService.cerrarSesion(Long.valueOf(claims.getSubject()));
            } catch (RuntimeException ignorado) {
                // token vencido o alterado: no hay sesión que cerrar
            }
        }
        return ResponseEntity.ok(Map.of("message", "Sesión cerrada"));
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@Valid @RequestBody LoginRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @PostMapping("/recuperar-password")
    public ResponseEntity<?> recuperarPassword(@RequestBody Map<String, String> body, HttpServletRequest request) {
        // El límite se aplica igual exista o no la cuenta, así que no revela correos.
        boolean correoOk = recuperacionPorCorreo.permitir(String.valueOf(body.get("correo")));
        boolean ipOk = recuperacionPorIp.permitir(request.getRemoteAddr());
        if (!correoOk || !ipOk) {
            return ResponseEntity.status(429).body(Map.of("error",
                    "Demasiadas solicitudes de recuperación. Inténtalo de nuevo en una hora."));
        }
        try {
            authService.solicitarRecuperacion(body.get("correo"));
            return ResponseEntity.ok(Map.of("message", "Si el correo está registrado, te enviamos un código de recuperación"));
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", ApiErrores.mensaje(e)));
        }
    }

    @PostMapping("/restablecer-password")
    public ResponseEntity<?> restablecerPassword(@RequestBody Map<String, String> body) {
        try {
            String nuevaContrasena = body.get("nuevaContrasena");
            if (nuevaContrasena == null) {
                nuevaContrasena = body.get("password");
            }
            authService.restablecerContrasena(body.get("correo"), body.get("token"), nuevaContrasena);
            return ResponseEntity.ok(Map.of("message", "Contraseña restablecida exitosamente"));
        } catch (com.ulima.incidenciaurbana.exception.TooManyAttemptsException e) {
            throw e; // 429 desde GlobalExceptionHandler
        } catch (RuntimeException e) {
            return ResponseEntity.badRequest().body(Map.of("error", ApiErrores.mensaje(e)));
        }
    }
}
