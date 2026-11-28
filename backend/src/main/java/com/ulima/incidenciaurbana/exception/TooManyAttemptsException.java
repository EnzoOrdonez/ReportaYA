package com.ulima.incidenciaurbana.exception;

/** Demasiados intentos de inicio de sesión fallidos seguidos: la API responde 429. */
public class TooManyAttemptsException extends RuntimeException {
    public TooManyAttemptsException(long minutos) {
        super("Demasiados intentos fallidos. Espera " + minutos + " minutos e inténtalo de nuevo.");
    }
}
