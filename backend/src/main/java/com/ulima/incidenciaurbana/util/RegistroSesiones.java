package com.ulima.incidenciaurbana.util;

import com.ulima.incidenciaurbana.repository.CuentaRepository;
import org.springframework.stereotype.Component;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Date;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * HU-02 CA2 y HU-05 CA2: al cerrar sesión o restablecer la contraseña, los tokens
 * emitidos antes dejan de autorizar operaciones. La fecha vive en la cuenta
 * ({@code sesiones_validas_desde}) y aquí se guarda en caché para no consultar la
 * base en cada petición.
 */
@Component
public class RegistroSesiones {

    private static final long SIN_REVOCAR = Long.MIN_VALUE;

    private final CuentaRepository cuentas;
    private final Map<Long, Long> validasDesde = new ConcurrentHashMap<>();

    public RegistroSesiones(CuentaRepository cuentas) {
        this.cuentas = cuentas;
    }

    static long aMilis(LocalDateTime fecha) {
        return fecha.atZone(ZoneId.systemDefault()).toInstant().toEpochMilli();
    }

    /**
     * true si un token de la cuenta sigue siendo válido. {@code emitidoMs} es la
     * marca en milisegundos del token; los tokens anteriores a la 1.1.4 solo traen
     * {@code iat} (segundos) y se comparan con esa precisión.
     */
    public boolean vigente(Long cuentaId, Long emitidoMs, Date iat) {
        if (cuentaId == null) return false;
        long desde = validasDesde.computeIfAbsent(cuentaId, id -> cuentas.findById(id)
                .map(c -> c.getSesionesValidasDesde() == null ? SIN_REVOCAR : aMilis(c.getSesionesValidasDesde()))
                .orElse(Long.MAX_VALUE)); // cuenta borrada: ningún token vale
        if (desde == SIN_REVOCAR) return true;
        Long emitido = emitidoMs != null ? emitidoMs : (iat == null ? null : iat.getTime());
        return emitido != null && emitido >= desde;
    }

    /** Llamar después de guardar {@code sesiones_validas_desde} en la cuenta. */
    public void revocadas(Long cuentaId, LocalDateTime desde) {
        validasDesde.put(cuentaId, aMilis(desde));
    }
}
