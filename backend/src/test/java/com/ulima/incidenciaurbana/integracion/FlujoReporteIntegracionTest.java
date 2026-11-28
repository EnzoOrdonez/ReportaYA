package com.ulima.incidenciaurbana.integracion;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ulima.incidenciaurbana.model.OperadorMunicipal;
import com.ulima.incidenciaurbana.model.Persona;
import com.ulima.incidenciaurbana.model.Tecnico;
import com.ulima.incidenciaurbana.repository.CuentaRepository;
import com.ulima.incidenciaurbana.repository.OperadorMunicipalRepository;
import com.ulima.incidenciaurbana.repository.TecnicoRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

import java.util.Base64;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

/**
 * Prueba de integracion: contexto Spring completo (interceptor JWT, controladores,
 * servicios, JPA) sobre una base H2 en modo PostgreSQL creada para la prueba.
 */
@SpringBootTest(properties = {
        "spring.datasource.url=jdbc:h2:mem:reportaya;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DEFAULT_NULL_ORDERING=HIGH",
        "spring.datasource.username=sa", "spring.datasource.password=",
        "spring.datasource.driver-class-name=org.h2.Driver",
        "spring.jpa.hibernate.ddl-auto=create-drop",
        "jwt.secret=clave-de-pruebas-de-integracion-con-mas-de-32-bytes",
        "app.registro.verificar-correo=false"})
@AutoConfigureMockMvc
class FlujoReporteIntegracionTest {

    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired CuentaRepository cuentas;
    @Autowired OperadorMunicipalRepository operadores;
    @Autowired TecnicoRepository tecnicos;
    @Autowired BCryptPasswordEncoder bcrypt;

    static final String PNG = Base64.getEncoder().encodeToString(
            new byte[]{(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0});
    String s;

    @BeforeEach
    void semilla() {
        s = UUID.randomUUID().toString().substring(0, 6);
        operadores.save(new OperadorMunicipal("op" + s, bcrypt.encode("Clave123"), new Persona("Op", "Uno", "1" + s + "0", "9", "op" + s + "@m.pe")));
        tecnicos.save(new Tecnico("tec" + s, bcrypt.encode("Clave123"), new Persona("Tec", "Uno", "2" + s + "0", "9", "tec" + s + "@m.pe")));
    }

    private static String dniNumerico() {
        return String.format("%08d", java.util.concurrent.ThreadLocalRandom.current().nextInt(100_000_000));
    }

    private JsonNode body(ResultActions r) throws Exception {
        return json.readTree(r.andReturn().getResponse().getContentAsString());
    }

    private JsonNode login(String usuario) throws Exception {
        return body(mvc.perform(post("/api/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content("{\"usuario\":\"" + usuario + "\",\"password\":\"Clave123\"}")).andExpect(status().isOk()));
    }

    private ResultActions conToken(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder b, String token, String cuerpo) throws Exception {
        b.header("Authorization", "Bearer " + token);
        if (cuerpo != null) b.contentType(MediaType.APPLICATION_JSON).content(cuerpo);
        return mvc.perform(b);
    }

    @Test
    @DisplayName("Registro, reporte, validacion, asignacion y cierre de punta a punta")
    void flujoCompleto() throws Exception {
        mvc.perform(post("/api/cuenta").contentType(MediaType.APPLICATION_JSON).content(
                "{\"usuario\":\"ana" + s + "\",\"contrasena\":\"Clave123\",\"nombres\":\"Ana\",\"apellidos\":\"Quispe\",\"dni\":\"" + dniNumerico() + "\","
                        + "\"telefono\":\"987654321\",\"correo\":\"ana" + s + "@mail.pe\",\"tipoCuenta\":\"CIUDADANO\",\"aceptaPrivacidad\":true}"))
                .andExpect(status().isCreated()).andExpect(jsonPath("$.activo").value(true));
        String ana = login("ana" + s).get("token").asText();
        String op = login("op" + s).get("token").asText();
        JsonNode tec = login("tec" + s);

        long id = body(conToken(post("/api/reportes"), ana,
                "{\"titulo\":\"Poste caido\",\"descripcion\":\"Poste inclinado sobre la vereda\",\"tipoProblema\":\"ALUMBRADO\","
                        + "\"ubicacion\":{\"latitud\":-12.08,\"longitud\":-77.03,\"direccion\":\"Av. Arequipa 1234\"}}")
                .andExpect(status().isCreated()).andExpect(jsonPath("$.estado").value("PENDIENTE"))).get("id").asLong();

        conToken(post("/api/reportes/" + id + "/fotos"), ana, "{\"archivoBase64\":\"" + PNG + "\",\"tipo\":\"INICIAL\"}")
                .andExpect(status().isCreated());
        conToken(post("/api/operador/reportes/" + id + "/aceptar"), op, "{}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.estado").value("REVISION"));
        conToken(post("/api/asignaciones"), op, "{\"reporteId\":" + id + ",\"tecnicoId\":" + tec.get("cuentaId").asLong() + "}")
                .andExpect(status().isCreated());
        conToken(patch("/api/tecnicos/" + tec.get("cuentaId").asLong() + "/reportes/" + id + "/completar"), tec.get("token").asText(),
                "{\"comentarioResolucion\":\"Se cambio la luminaria\",\"fotos\":[{\"archivoBase64\":\"" + PNG
                        + "\",\"tipo\":\"FINAL\",\"descripcion\":\"Foto final\"}]}")
                .andExpect(status().isOk()).andExpect(jsonPath("$.reporte.estado").value("FINALIZADO"));

        JsonNode historial = body(conToken(get("/api/historial-estados/reporte/" + id), ana, null).andExpect(status().isOk()));
        assertThat(historial).hasSize(3);
        JsonNode detalle = body(conToken(get("/api/reportes/" + id), ana, null).andExpect(status().isOk()));
        assertThat(detalle.get("fotos")).hasSize(2);
    }

    @Test
    @DisplayName("El interceptor JWT y los permisos por rol responden 401 y 403")
    void seguridad() throws Exception {
        mvc.perform(get("/api/reportes/mapa")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/reportes/mapa").header("Authorization", "Bearer no.es.token")).andExpect(status().isUnauthorized());
        String tec = login("tec" + s).get("token").asText();
        conToken(get("/api/reportes?page=0"), tec, null).andExpect(status().isForbidden());
        conToken(post("/api/reportes"), tec, "{\"titulo\":\"x\",\"descripcion\":\"y\",\"ubicacion\":{\"latitud\":1,\"longitud\":1}}")
                .andExpect(status().isForbidden());
        assertThat(cuentas.findByUsuario("tec" + s).orElseThrow().getContrasenaHash()).startsWith("$2a$");
    }

    @Test
    @DisplayName("Regresion D-01, D-02 y D-03: DNI con letras, cierre sin fotos y foto corrupta responden 400")
    void regresiones() throws Exception {
        mvc.perform(post("/api/cuenta").contentType(MediaType.APPLICATION_JSON).content(
                "{\"usuario\":\"dni" + s + "\",\"contrasena\":\"Clave123\",\"nombres\":\"A\",\"apellidos\":\"B\",\"dni\":\"ABCDEFGH\","
                        + "\"telefono\":\"987654321\",\"correo\":\"dni" + s + "@mail.pe\",\"tipoCuenta\":\"CIUDADANO\",\"aceptaPrivacidad\":true}"))
                .andExpect(status().isBadRequest());

        mvc.perform(post("/api/cuenta").contentType(MediaType.APPLICATION_JSON).content(
                "{\"usuario\":\"leo" + s + "\",\"contrasena\":\"Clave123\",\"nombres\":\"Leo\",\"apellidos\":\"Paz\",\"dni\":\"" + dniNumerico() + "\","
                        + "\"telefono\":\"987654321\",\"correo\":\"leo" + s + "@mail.pe\",\"tipoCuenta\":\"CIUDADANO\",\"aceptaPrivacidad\":true}"))
                .andExpect(status().isCreated());
        String leo = login("leo" + s).get("token").asText();
        String op = login("op" + s).get("token").asText();
        JsonNode tec = login("tec" + s);
        long id = body(conToken(post("/api/reportes"), leo,
                "{\"titulo\":\"Basura en la esquina\",\"descripcion\":\"Basura acumulada junto al parque\",\"tipoProblema\":\"RESIDUOS\","
                        + "\"ubicacion\":{\"latitud\":-12.1,\"longitud\":-77.0}}")).get("id").asLong();
        conToken(post("/api/operador/reportes/" + id + "/aceptar"), op, "{}").andExpect(status().isOk());
        conToken(post("/api/asignaciones"), op, "{\"reporteId\":" + id + ",\"tecnicoId\":" + tec.get("cuentaId").asLong() + "}")
                .andExpect(status().isCreated());
        String url = "/api/tecnicos/" + tec.get("cuentaId").asLong() + "/reportes/" + id + "/completar";
        conToken(patch(url), tec.get("token").asText(), "{\"comentarioResolucion\":\"Se recogio la basura\",\"fotos\":[]}")
                .andExpect(status().isBadRequest());
        conToken(patch(url), tec.get("token").asText(),
                "{\"comentarioResolucion\":\"Se recogio la basura\",\"fotos\":[{\"archivoBase64\":\"%%%\",\"tipo\":\"FINAL\",\"descripcion\":\"Foto final\"}]}")
                .andExpect(status().isBadRequest());
        conToken(get("/api/reportes/" + id), op, null).andExpect(jsonPath("$.estado").value("REVISION"));
    }
}
