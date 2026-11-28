package com.ulima.incidenciaurbana.util;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Ventana deslizante: como máximo {@code maximo} solicitudes por clave dentro de
 * {@code ventana}. HU-05 CA1 limita la recuperación a 5 solicitudes por hora por
 * IP y por correo. En memoria, porque la API corre en una sola instancia.
 */
public class LimitadorSolicitudes {

    private final int maximo;
    private final Duration ventana;
    private final Clock reloj;
    private final Map<String, Deque<Instant>> registros = new ConcurrentHashMap<>();

    public LimitadorSolicitudes(int maximo, Duration ventana) {
        this(maximo, ventana, Clock.systemUTC());
    }

    LimitadorSolicitudes(int maximo, Duration ventana, Clock reloj) {
        this.maximo = maximo;
        this.ventana = ventana;
        this.reloj = reloj;
    }

    /**
     * Registra la solicitud y devuelve true si está dentro del límite. Con
     * {@code maximo <= 0} el límite está desactivado.
     */
    public boolean permitir(String clave) {
        if (maximo <= 0) return true;
        Instant ahora = reloj.instant();
        Instant desde = ahora.minus(ventana);
        String k = clave == null ? "" : clave.trim().toLowerCase(Locale.ROOT);
        boolean[] ok = {false};
        registros.compute(k, (key, cola) -> {
            Deque<Instant> c = cola == null ? new ArrayDeque<>() : cola;
            while (!c.isEmpty() && !c.peekFirst().isAfter(desde)) c.pollFirst();
            if (c.size() < maximo) {
                c.addLast(ahora);
                ok[0] = true;
            }
            return c;
        });
        if (registros.size() > 10_000) {
            registros.entrySet().removeIf(e -> e.getValue().isEmpty()
                    || !e.getValue().peekLast().isAfter(desde));
        }
        return ok[0];
    }
}
