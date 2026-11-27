package com.ulima.incidenciaurbana.service.impl;

import com.ulima.incidenciaurbana.service.IEmailService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.BufferingClientHttpRequestFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.util.HtmlUtils;

import java.time.Duration;
import java.util.List;
import java.util.Map;

/**
 * Implementación de {@link IEmailService} por API HTTP (no SMTP: los servicios
 * gratis de Render bloquean los puertos SMTP 25, 465 y 587).
 *
 * <p>Proveedor según la configuración, en este orden:
 * <ol>
 *   <li>Brevo, si hay {@code BREVO_API_KEY} (300 correos/día gratis; admite un
 *       remitente verificado sin dominio propio).</li>
 *   <li>Resend, si hay {@code RESEND_API_KEY} (sin dominio verificado solo entrega
 *       al dueño de la cuenta de Resend).</li>
 *   <li>Ninguno: no falla; deja el enlace o el código en el log (modo desarrollo).</li>
 * </ol>
 */
@Service
public class ResendEmailServiceImpl implements IEmailService {

    private static final Logger log = LoggerFactory.getLogger(ResendEmailServiceImpl.class);
    private static final String RESEND_URL = "https://api.resend.com/emails";

    private final String apiKey;
    private final String from;
    private final String brevoApiKey;
    private final String brevoSenderEmail;
    private final String brevoSenderName;
    private final String brevoUrl;
    private final String baseUrl;
    private final RestClient restClient;

    public ResendEmailServiceImpl(
            @Value("${resend.api-key:}") String apiKey,
            @Value("${resend.from:onboarding@resend.dev}") String from,
            @Value("${app.base-url:http://localhost:8081}") String baseUrl,
            @Value("${brevo.api-key:}") String brevoApiKey,
            @Value("${brevo.sender-email:}") String brevoSenderEmail,
            @Value("${brevo.sender-name:ReportaYA}") String brevoSenderName,
            @Value("${brevo.api-url:https://api.brevo.com/v3/smtp/email}") String brevoUrl) {
        this.apiKey = apiKey;
        this.from = from;
        this.brevoApiKey = brevoApiKey == null ? "" : brevoApiKey.trim();
        this.brevoSenderEmail = brevoSenderEmail == null ? "" : brevoSenderEmail.trim();
        this.brevoSenderName = brevoSenderName;
        this.brevoUrl = brevoUrl;
        this.baseUrl = baseUrl;

        // Timeouts para no retener el hilo/recursos si Resend tarda o no responde.
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(Duration.ofSeconds(5));
        factory.setReadTimeout(Duration.ofSeconds(10));
        // Buffering: envia Content-Length en vez de cuerpo "chunked" (algunas APIs lo exigen).
        this.restClient = RestClient.builder()
                .requestFactory(new BufferingClientHttpRequestFactory(factory))
                .build();
    }

    @Override
    @Async
    public void enviarVerificacion(String correo, String nombre, String token) {
        String enlace = baseUrl + "/api/cuenta/verificar?token=" + token;
        enviarCorreo(
                correo,
                "Verifica tu cuenta de ReportaYA",
                construirHtmlVerificacion(nombre, enlace),
                construirTextoVerificacion(nombre, enlace),
                enlace,
                "verificacion");
    }

    @Override
    @Async
    public void enviarRecuperacionContrasena(String correo, String nombre, String token) {
        // Opcion B: "token" es un codigo corto que el usuario ingresa en la app.
        // No se envia enlace (no hay deep link configurado); el codigo va en el correo.
        // Si no hay RESEND_API_KEY (modo local), enviarCorreo deja el codigo en el log.
        // Con API key no se registra: quien lea los logs no debe poder cambiar contrasenas.
        enviarCorreo(
                correo,
                "Tu codigo para restablecer la contrasena de ReportaYA",
                construirHtmlRecuperacion(nombre, token),
                construirTextoRecuperacion(nombre, token),
                token,
                "recuperacion de contrasena");
    }

    private void enviarCorreo(String correo, String subject, String html, String text, String enlace, String tipo) {
        if (!brevoApiKey.isBlank()) {
            enviarConBrevo(correo, subject, html, text, enlace, tipo);
            return;
        }
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("[Resend] RESEND_API_KEY no configurada. Enlace de {} para {}: {}",
                    tipo, correo, enlace);
            return;
        }

        Map<String, Object> payload = Map.of(
                "from", from,
                "to", List.of(correo),
                "subject", subject,
                "html", html,
                "text", text);

        try {
            restClient.post()
                    .uri(RESEND_URL)
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(payload)
                    .retrieve()
                    .toBodilessEntity();
            log.info("[Resend] Correo de {} enviado a {}", tipo, correo);
        } catch (Exception e) {
            log.error("[Resend] Error enviando correo de {} a {}: {}. Enlace: {}",
                    tipo, correo, e.getMessage(), enlace);
        }
    }

    private void enviarConBrevo(String correo, String subject, String html, String text, String enlace, String tipo) {
        if (brevoSenderEmail.isBlank()) {
            log.error("[Brevo] Falta BREVO_SENDER_EMAIL (remitente verificado en Brevo). Enlace de {} para {}: {}",
                    tipo, correo, enlace);
            return;
        }
        Map<String, Object> payload = Map.of(
                "sender", Map.of("name", brevoSenderName, "email", brevoSenderEmail),
                "to", List.of(Map.of("email", correo)),
                "subject", subject,
                "htmlContent", html,
                "textContent", text);
        try {
            restClient.post()
                    .uri(brevoUrl)
                    .header("api-key", brevoApiKey)
                    .accept(MediaType.APPLICATION_JSON)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(payload)
                    .retrieve()
                    .toBodilessEntity();
            log.info("[Brevo] Correo de {} enviado a {}", tipo, correo);
        } catch (Exception e) {
            // Si el envio falla, el codigo queda en el log para que un administrador ayude.
            log.error("[Brevo] Error enviando correo de {} a {}: {}. Enlace: {}",
                    tipo, correo, e.getMessage(), enlace);
        }
    }

    private String construirHtmlVerificacion(String nombre, String enlace) {
        // Escapamos el nombre (dato del usuario) para evitar inyección de HTML en el correo.
        String saludo = (nombre != null && !nombre.isBlank()) ? HtmlUtils.htmlEscape(nombre) : "";
        String enlaceHtml = HtmlUtils.htmlEscape(enlace);
        return """
                <div style="font-family: system-ui, sans-serif; max-width:480px; margin:0 auto; padding:24px; color:#18181b;">
                  <h2 style="color:#7c3aed;">ReportaYA</h2>
                  <p>Hola %s, gracias por registrarte.</p>
                  <p>Para activar tu cuenta, confirma tu correo haciendo clic en el siguiente boton:</p>
                  <p style="text-align:center; margin:32px 0;">
                    <a href="%s" style="background:#7c3aed; color:#fff; padding:12px 28px; border-radius:8px; text-decoration:none; font-weight:600;">Verificar mi cuenta</a>
                  </p>
                  <p style="font-size:13px; color:#71717a;">Si el boton no funciona, copia y pega este enlace en tu navegador:<br>%s</p>
                  <p style="font-size:13px; color:#71717a;">Este enlace caduca en 24 horas. Si no creaste esta cuenta, ignora este correo.</p>
                </div>
                """.formatted(saludo, enlaceHtml, enlaceHtml);
    }

    private String construirHtmlRecuperacion(String nombre, String codigo) {
        String saludo = (nombre != null && !nombre.isBlank()) ? HtmlUtils.htmlEscape(nombre) : "";
        String codigoHtml = HtmlUtils.htmlEscape(codigo);
        return """
                <div style="font-family: system-ui, sans-serif; max-width:480px; margin:0 auto; padding:24px; color:#18181b;">
                  <h2 style="color:#7c3aed;">ReportaYA</h2>
                  <p>Hola %s, recibimos una solicitud para restablecer tu contraseña.</p>
                  <p>Ingresa este código en la app para crear tu nueva contraseña:</p>
                  <p style="text-align:center; margin:32px 0;">
                    <span style="display:inline-block; background:#f4f4f5; color:#7c3aed; font-size:32px; font-weight:700; letter-spacing:8px; padding:16px 28px; border-radius:12px; font-family:monospace;">%s</span>
                  </p>
                  <p style="font-size:13px; color:#71717a;">Este código caduca en 30 minutos. Si no solicitaste este cambio, ignora este correo.</p>
                </div>
                """.formatted(saludo, codigoHtml);
    }

    private String construirTextoVerificacion(String nombre, String enlace) {
        String saludo = construirSaludoTexto(nombre);
        return """
                Hola%s,

                Para completar tu registro en ReportaYA, verifica tu cuenta aqui:
                %s

                Este enlace caduca en 24 horas. Si no creaste esta cuenta, ignora este correo.

                Equipo de ReportaYA
                """.formatted(saludo, enlace);
    }

    private String construirTextoRecuperacion(String nombre, String codigo) {
        String saludo = construirSaludoTexto(nombre);
        return """
                Hola%s,

                Recibimos una solicitud para restablecer tu contrasena de ReportaYA.
                Ingresa este codigo en la app para crear tu nueva contrasena:

                %s

                Este codigo caduca en 30 minutos. Si no solicitaste este cambio, ignora este correo.

                Equipo de ReportaYA
                """.formatted(saludo, codigo);
    }

    private String construirSaludoTexto(String nombre) {
        return (nombre != null && !nombre.isBlank()) ? " " + nombre.trim() : "";
    }
}
