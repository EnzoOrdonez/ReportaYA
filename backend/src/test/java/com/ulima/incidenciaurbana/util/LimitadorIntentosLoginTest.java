package com.ulima.incidenciaurbana.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import static org.assertj.core.api.Assertions.assertThat;

class LimitadorIntentosLoginTest {

    /** Reloj que se adelanta a mano para probar los tiempos sin esperar. */
    static class RelojManual extends Clock {
        Instant ahora = Instant.parse("2026-11-27T15:00:00Z");
        void avanzar(Duration d) { ahora = ahora.plus(d); }
        @Override public java.time.ZoneId getZone() { return ZoneOffset.UTC; }
        @Override public Clock withZone(java.time.ZoneId zone) { return this; }
        @Override public Instant instant() { return ahora; }
    }

    @Test
    @DisplayName("Bloquea al quinto fallo, ignora mayúsculas y libera a los 5 minutos")
    void bloqueoYLiberacion() {
        RelojManual reloj = new RelojManual();
        LimitadorIntentosLogin l = new LimitadorIntentosLogin(reloj);
        for (int i = 0; i < 4; i++) l.registrarFallo("Ana");
        assertThat(l.bloqueado("ana")).isFalse();
        l.registrarFallo("ANA");
        assertThat(l.bloqueado("ana")).isTrue();
        reloj.avanzar(Duration.ofMinutes(4));
        assertThat(l.bloqueado("ana")).isTrue();
        reloj.avanzar(Duration.ofMinutes(1));
        assertThat(l.bloqueado("ana")).isFalse();
        // Tras el bloqueo el contador vuelve a empezar: un fallo más no bloquea.
        l.registrarFallo("ana");
        assertThat(l.bloqueado("ana")).isFalse();
    }

    @Test
    @DisplayName("Un inicio correcto reinicia el contador y los fallos viejos caducan a los 15 minutos")
    void exitoYVentana() {
        RelojManual reloj = new RelojManual();
        LimitadorIntentosLogin l = new LimitadorIntentosLogin(reloj);
        for (int i = 0; i < 4; i++) l.registrarFallo("beto");
        l.registrarExito("beto");
        l.registrarFallo("beto");
        assertThat(l.bloqueado("beto")).isFalse();

        for (int i = 0; i < 3; i++) l.registrarFallo("caro");
        reloj.avanzar(Duration.ofMinutes(16));
        l.registrarFallo("caro");
        l.registrarFallo("caro");
        assertThat(l.bloqueado("caro")).isFalse();
    }
}
