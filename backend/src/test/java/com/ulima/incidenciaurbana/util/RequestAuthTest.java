package com.ulima.incidenciaurbana.util;

import com.ulima.incidenciaurbana.exception.ForbiddenException;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

import static org.assertj.core.api.Assertions.*;

/** Tabla de decision de permisos: rol x duenio del recurso. */
class RequestAuthTest {

    private MockHttpServletRequest como(long cuentaId, String rol) {
        MockHttpServletRequest r = new MockHttpServletRequest();
        r.setAttribute("cuentaId", cuentaId);
        r.setAttribute("tipoCuenta", rol);
        return r;
    }

    @Test
    @DisplayName("requireRole deja pasar solo a los roles indicados")
    void requireRole() {
        assertThatCode(() -> RequestAuth.requireRole(como(3, RequestAuth.OPERADOR), RequestAuth.OPERADOR)).doesNotThrowAnyException();
        assertThatThrownBy(() -> RequestAuth.requireRole(como(1, RequestAuth.CIUDADANO), RequestAuth.OPERADOR))
                .isInstanceOf(ForbiddenException.class);
        assertThatThrownBy(() -> RequestAuth.requireRole(new MockHttpServletRequest(), RequestAuth.CIUDADANO))
                .isInstanceOf(ForbiddenException.class);
    }

    @Test
    @DisplayName("requireSelfOrRole: el duenio y el operador pasan; otro ciudadano no")
    void requireSelfOrRole() {
        assertThatCode(() -> RequestAuth.requireSelfOrRole(como(1, RequestAuth.CIUDADANO), 1L, RequestAuth.OPERADOR)).doesNotThrowAnyException();
        assertThatCode(() -> RequestAuth.requireSelfOrRole(como(3, RequestAuth.OPERADOR), 1L, RequestAuth.OPERADOR)).doesNotThrowAnyException();
        assertThatThrownBy(() -> RequestAuth.requireSelfOrRole(como(2, RequestAuth.CIUDADANO), 1L, RequestAuth.OPERADOR))
                .isInstanceOf(ForbiddenException.class);
        assertThatThrownBy(() -> RequestAuth.requireSelfOrRole(como(4, RequestAuth.TECNICO), 1L, RequestAuth.OPERADOR))
                .isInstanceOf(ForbiddenException.class);
    }
}
