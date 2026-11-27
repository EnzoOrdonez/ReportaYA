package com.ulima.incidenciaurbana.util;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.ExpiredJwtException;
import io.jsonwebtoken.security.SignatureException;
import io.jsonwebtoken.security.WeakKeyException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.*;

class JwtUtilTest {

    private static final String SECRETO = "clave-de-pruebas-unitarias-con-mas-de-32-bytes";

    @Test
    @DisplayName("El token generado conserva cuenta, usuario y rol")
    void generaYLee() {
        JwtUtil jwt = new JwtUtil(SECRETO, 60_000);
        Claims c = jwt.parseClaims(jwt.generateToken(7L, "ana", "CIUDADANO"));
        assertThat(c.getSubject()).isEqualTo("7");
        assertThat(c.get("usuario", String.class)).isEqualTo("ana");
        assertThat(c.get("tipoCuenta", String.class)).isEqualTo("CIUDADANO");
    }

    @Test
    @DisplayName("Un token firmado con otra clave se rechaza")
    void otraClave() {
        String ajeno = new JwtUtil("otra-clave-distinta-tambien-de-mas-de-32-bytes", 60_000).generateToken(1L, "x", "OPERADOR_MUNICIPAL");
        assertThatThrownBy(() -> new JwtUtil(SECRETO, 60_000).parseClaims(ajeno)).isInstanceOf(SignatureException.class);
    }

    @Test
    @DisplayName("Un token vencido se rechaza")
    void vencido() {
        JwtUtil jwt = new JwtUtil(SECRETO, -1_000);
        String t = jwt.generateToken(1L, "ana", "CIUDADANO");
        assertThatThrownBy(() -> jwt.parseClaims(t)).isInstanceOf(ExpiredJwtException.class);
    }

    @Test
    @DisplayName("Una clave de menos de 256 bits no se acepta")
    void claveDebil() {
        assertThatThrownBy(() -> new JwtUtil("corta", 60_000)).isInstanceOf(WeakKeyException.class);
    }
}
