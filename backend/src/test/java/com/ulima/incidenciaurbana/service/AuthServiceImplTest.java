package com.ulima.incidenciaurbana.service;

import com.ulima.incidenciaurbana.dto.LoginRequest;
import com.ulima.incidenciaurbana.dto.LoginResponse;
import com.ulima.incidenciaurbana.exception.EmailNotVerifiedException;
import com.ulima.incidenciaurbana.exception.InvalidCredentialsException;
import com.ulima.incidenciaurbana.model.Ciudadano;
import com.ulima.incidenciaurbana.model.Cuenta;
import com.ulima.incidenciaurbana.model.Persona;
import com.ulima.incidenciaurbana.repository.CuentaRepository;
import com.ulima.incidenciaurbana.service.impl.AuthServiceImpl;
import com.ulima.incidenciaurbana.util.JwtUtil;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class AuthServiceImplTest {

    CuentaRepository cuentas = mock(CuentaRepository.class);
    IEmailService correo = mock(IEmailService.class);
    BCryptPasswordEncoder bcrypt = new BCryptPasswordEncoder(4);
    AuthServiceImpl servicio;
    Cuenta ana;

    @BeforeEach
    void preparar() {
        servicio = new AuthServiceImpl(cuentas, bcrypt, new JwtUtil("clave-de-pruebas-unitarias-con-mas-de-32-bytes", 60_000), correo,
                new com.ulima.incidenciaurbana.util.LimitadorIntentosLogin(),
                mock(com.ulima.incidenciaurbana.util.RegistroSesiones.class));
        ana = new Ciudadano("ana", bcrypt.encode("Clave123"), new Persona("Ana", "Quispe", "45781230", "9", "ana@mail.com"));
        ana.setId(1L);
        ana.setActivo(true);
        when(cuentas.findByUsuario("ana")).thenReturn(Optional.of(ana));
    }

    private LoginRequest req(String u, String p) {
        LoginRequest r = new LoginRequest();
        r.setUsuario(u);
        r.setPassword(p);
        return r;
    }

    @Test
    @DisplayName("Login correcto devuelve token y rol")
    void loginCorrecto() {
        LoginResponse r = servicio.login(req("ana", "Clave123"));
        assertThat(r.getToken()).isNotBlank();
        assertThat(r.getTipoCuenta()).isEqualTo("CIUDADANO");
    }

    @Test
    @DisplayName("Clave incorrecta, usuario inexistente y hash no BCrypt dan el mismo error")
    void loginIncorrecto() {
        assertThatThrownBy(() -> servicio.login(req("ana", "otra"))).isInstanceOf(InvalidCredentialsException.class);
        assertThatThrownBy(() -> servicio.login(req("nadie", "Clave123"))).isInstanceOf(InvalidCredentialsException.class);
        ana.setContrasenaHash("Clave123");
        assertThatThrownBy(() -> servicio.login(req("ana", "Clave123"))).isInstanceOf(InvalidCredentialsException.class);
    }

    @Test
    @DisplayName("Una cuenta inactiva con la clave correcta recibe el aviso de correo sin verificar")
    void inactiva() {
        ana.setActivo(false);
        assertThatThrownBy(() -> servicio.login(req("ana", "Clave123"))).isInstanceOf(EmailNotVerifiedException.class);
    }

    @Test
    @DisplayName("Recuperacion: codigo de 6 caracteres valido 30 minutos; correo desconocido no envia nada")
    void recuperacion() {
        when(cuentas.findByCorreoAndActivoTrue("ana@mail.com")).thenReturn(Optional.of(ana));
        servicio.solicitarRecuperacion("ana@mail.com");
        assertThat(ana.getTokenRecuperacion()).matches("[A-HJ-KM-NP-Z2-9]{6}");
        assertThat(ana.getTokenRecuperacionExpiracion()).isBetween(LocalDateTime.now().plusMinutes(29), LocalDateTime.now().plusMinutes(31));
        verify(correo).enviarRecuperacionContrasena(eq("ana@mail.com"), anyString(), eq(ana.getTokenRecuperacion()));

        servicio.solicitarRecuperacion("desconocido@mail.com");
        verifyNoMoreInteractions(correo);
    }

    @Test
    @DisplayName("Restablecer: codigo ligado al correo; vencido, ajeno o clave corta se rechazan; el valido cambia la clave y se invalida")
    void restablecer() {
        ana.asignarTokenRecuperacion("ABC234", LocalDateTime.now().plusMinutes(10));
        when(cuentas.findByTokenRecuperacion("ABC234")).thenReturn(Optional.of(ana));
        assertThatThrownBy(() -> servicio.restablecerContrasena("ana@mail.com", "ABC234", "1234567")).hasMessageContaining("8");
        assertThatThrownBy(() -> servicio.restablecerContrasena(null, "ABC234", "Nueva4567")).hasMessageContaining("correo");
        // El codigo de Ana no sirve con otro correo.
        assertThatThrownBy(() -> servicio.restablecerContrasena("otro@mail.com", "ABC234", "Nueva4567")).hasMessageContaining("inválido");
        assertThat(ana.getTokenRecuperacion()).isEqualTo("ABC234");
        // Se acepta en minusculas y con espacios alrededor.
        servicio.restablecerContrasena(" ANA@mail.com ", "abc234", "Nueva4567");
        assertThat(bcrypt.matches("Nueva4567", ana.getContrasenaHash())).isTrue();
        assertThat(ana.getTokenRecuperacion()).isNull();

        ana.asignarTokenRecuperacion("XYZ789", LocalDateTime.now().minusMinutes(1));
        when(cuentas.findByTokenRecuperacion("XYZ789")).thenReturn(Optional.of(ana));
        assertThatThrownBy(() -> servicio.restablecerContrasena("ana@mail.com", "XYZ789", "Nueva4567")).hasMessageContaining("expirado");
    }

    @Test
    @DisplayName("Restablecer: tras 5 codigos errados el correo queda bloqueado (429) aunque luego use el codigo correcto")
    void restablecerFuerzaBruta() {
        ana.asignarTokenRecuperacion("ABC234", LocalDateTime.now().plusMinutes(10));
        when(cuentas.findByTokenRecuperacion("ABC234")).thenReturn(Optional.of(ana));
        when(cuentas.findByTokenRecuperacion("ZZZ999")).thenReturn(Optional.empty());
        for (int i = 0; i < 5; i++) {
            assertThatThrownBy(() -> servicio.restablecerContrasena("ana@mail.com", "ZZZ999", "Nueva4567"))
                    .hasMessageContaining("inválido");
        }
        assertThatThrownBy(() -> servicio.restablecerContrasena("ana@mail.com", "ABC234", "Nueva4567"))
                .isInstanceOf(com.ulima.incidenciaurbana.exception.TooManyAttemptsException.class);
        assertThat(ana.getTokenRecuperacion()).isEqualTo("ABC234");
    }
}
