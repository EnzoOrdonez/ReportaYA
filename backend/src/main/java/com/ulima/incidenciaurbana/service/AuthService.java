package com.ulima.incidenciaurbana.service;

import com.ulima.incidenciaurbana.dto.LoginRequest;
import com.ulima.incidenciaurbana.dto.LoginResponse;

public interface AuthService {
    LoginResponse login(LoginRequest request);

    void solicitarRecuperacion(String correo);

    /** Invalida los tokens emitidos hasta ahora para la cuenta (HU-02 CA2). */
    void cerrarSesion(Long cuentaId);

    /** El código solo vale junto con el correo de la cuenta que lo pidió. */
    void restablecerContrasena(String correo, String token, String nuevaContrasena);
}
