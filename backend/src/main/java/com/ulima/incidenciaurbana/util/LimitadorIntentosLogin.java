package com.ulima.incidenciaurbana.util;

import org.springframework.stereotype.Component;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Bloqueo temporal por usuario tras varios inicios de sesión fallidos seguidos
 * (OWASP: protección contra fuerza bruta). Se guarda en memoria porque la API corre
 * en una sola instancia; un reinicio limpia los contadores.
 */
@Component
public class LimitadorIntentosLogin {

    public static final int MAX_FALLOS = 5;
    public static final Duration BLOQUEO = Duration.ofMinutes(5);
    /** Fallos más antiguos que esta ventana ya no cuentan. */
    public static final Duration VENTANA = Duration.ofMinutes(15);

    private record Estado(int fallos, Instant primerFallo, Instant bloqueadoHasta) {}

    private final Map<String, Estado> estados = new ConcurrentHashMap<>();
    private final Clock reloj;

    public LimitadorIntentosLogin() {
        this(Clock.systemUTC());
    }

    LimitadorIntentosLogin(Clock reloj) {
        this.reloj = reloj;
    }

    private static String clave(String usuario) {
        return usuario == null ? "" : usuario.trim().toLowerCase(Locale.ROOT);
    }

    /** true si el usuario está bloqueado en este momento. */
    public boolean bloqueado(String usuario) {
        Estado e = estados.get(clave(usuario));
        return e != null && e.bloqueadoHasta() != null && reloj.instant().isBefore(e.bloqueadoHasta());
    }

    public void registrarFallo(String usuario) {
        Instant ahora = reloj.instant();
        estados.compute(clave(usuario), (k, e) -> {
            if (e == null || e.primerFallo().plus(VENTANA).isBefore(ahora)
                    || (e.bloqueadoHasta() != null && !ahora.isBefore(e.bloqueadoHasta()))) {
                e = new Estado(0, ahora, null);
            }
            int fallos = e.fallos() + 1;
            Instant hasta = fallos >= MAX_FALLOS ? ahora.plus(BLOQUEO) : null;
            return new Estado(fallos, e.primerFallo(), hasta);
        });
        if (estados.size() > 10_000) {
            estados.entrySet().removeIf(x -> x.getValue().primerFallo().plus(VENTANA).isBefore(ahora)
                    && (x.getValue().bloqueadoHasta() == null || x.getValue().bloqueadoHasta().isBefore(ahora)));
        }
    }

    public void registrarExito(String usuario) {
        estados.remove(clave(usuario));
    }
}
