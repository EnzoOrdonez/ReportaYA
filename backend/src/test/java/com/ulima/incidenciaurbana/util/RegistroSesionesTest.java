package com.ulima.incidenciaurbana.util;

import com.ulima.incidenciaurbana.model.Ciudadano;
import com.ulima.incidenciaurbana.model.Persona;
import com.ulima.incidenciaurbana.repository.CuentaRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.Date;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.*;

class RegistroSesionesTest {

    private static Date en(LocalDateTime t) {
        return Date.from(t.atZone(ZoneId.systemDefault()).toInstant());
    }

    @Test
    @DisplayName("HU-02/HU-05: tras revocar, los tokens anteriores dejan de valer y los nuevos sí; la base se consulta una sola vez")
    void revocacion() {
        CuentaRepository repo = mock(CuentaRepository.class);
        Ciudadano ana = new Ciudadano("ana", "hash", new Persona("Ana", "Quispe", "45781230", "987654321", "ana@mail.com"));
        when(repo.findById(7L)).thenReturn(Optional.of(ana));
        RegistroSesiones r = new RegistroSesiones(repo);

        long antes = System.currentTimeMillis() - 1;
        assertThat(r.vigente(7L, antes, null)).isTrue();                 // nunca se revocó

        LocalDateTime corte = ana.revocarSesiones();
        r.revocadas(7L, corte);
        long ms = en(corte).getTime();
        assertThat(r.vigente(7L, antes, null)).isFalse();                // token viejo
        assertThat(r.vigente(7L, ms - 1, null)).isFalse();               // 1 ms antes del corte, mismo segundo
        assertThat(r.vigente(7L, ms, null)).isTrue();
        assertThat(r.vigente(7L, ms + 2000, null)).isTrue();
        // Token anterior a la 1.1.4 (solo "iat" en segundos, truncado hacia abajo).
        assertThat(r.vigente(7L, null, en(corte.minusSeconds(1)))).isFalse();
        verify(repo, times(1)).findById(7L);
    }

    @Test
    @DisplayName("Al reiniciar el servidor la fecha de corte se lee de la cuenta; una cuenta inexistente no tiene tokens válidos")
    void leeDeLaBase() {
        CuentaRepository repo = mock(CuentaRepository.class);
        Ciudadano ana = new Ciudadano("ana", "hash", new Persona("Ana", "Quispe", "45781230", "987654321", "ana@mail.com"));
        LocalDateTime corte = ana.revocarSesiones();
        when(repo.findById(7L)).thenReturn(Optional.of(ana));
        when(repo.findById(8L)).thenReturn(Optional.empty());
        RegistroSesiones r = new RegistroSesiones(repo);
        long ms = en(corte).getTime();
        assertThat(r.vigente(7L, ms - 1, null)).isFalse();
        assertThat(r.vigente(7L, ms, null)).isTrue();
        assertThat(r.vigente(8L, ms, null)).isFalse();
        assertThat(r.vigente(null, ms, null)).isFalse();
        assertThat(r.vigente(7L, null, null)).isFalse();
    }
}
