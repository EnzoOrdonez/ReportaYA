package com.ulima.incidenciaurbana.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneId;

import static org.assertj.core.api.Assertions.assertThat;

class LimitadorSolicitudesTest {

    static class RelojManual extends Clock {
        Instant ahora = Instant.parse("2026-11-27T10:00:00Z");
        @Override public ZoneId getZone() { return ZoneId.of("UTC"); }
        @Override public Clock withZone(ZoneId zone) { return this; }
        @Override public Instant instant() { return ahora; }
    }

    @Test
    @DisplayName("HU-05: 5 solicitudes por hora por clave; la sexta se rechaza y pasada la hora vuelve a permitirse")
    void cincoPorHora() {
        RelojManual reloj = new RelojManual();
        LimitadorSolicitudes l = new LimitadorSolicitudes(5, Duration.ofHours(1), reloj);
        for (int i = 0; i < 5; i++) assertThat(l.permitir("Ana@Mail.com")).isTrue();
        assertThat(l.permitir("ana@mail.com")).isFalse();      // misma clave sin importar mayúsculas
        assertThat(l.permitir("otro@mail.com")).isTrue();      // otra clave no se ve afectada
        reloj.ahora = reloj.ahora.plus(Duration.ofMinutes(61));
        assertThat(l.permitir("ana@mail.com")).isTrue();
    }

    @Test
    @DisplayName("Con máximo 0 el límite está desactivado")
    void desactivado() {
        LimitadorSolicitudes l = new LimitadorSolicitudes(0, Duration.ofHours(1));
        for (int i = 0; i < 50; i++) assertThat(l.permitir("x")).isTrue();
    }
}
