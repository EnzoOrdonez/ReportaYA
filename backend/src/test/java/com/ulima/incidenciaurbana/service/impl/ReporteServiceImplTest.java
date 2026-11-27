package com.ulima.incidenciaurbana.service.impl;

import com.ulima.incidenciaurbana.service.INotificationService;

import com.ulima.incidenciaurbana.dto.ReporteDTO;
import com.ulima.incidenciaurbana.dto.UbicacionDTO;
import com.ulima.incidenciaurbana.model.*;
import com.ulima.incidenciaurbana.repository.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.ArgumentCaptor;

import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

/** Pruebas unitarias de las reglas de negocio del reporte (ciclo de estados y validaciones). */
class ReporteServiceImplTest {

    ReporteRepository reportes = mock(ReporteRepository.class);
    CuentaRepository cuentas = mock(CuentaRepository.class);
    TecnicoRepository tecnicos = mock(TecnicoRepository.class);
    UbicacionRepository ubicaciones = mock(UbicacionRepository.class);
    HistorialEstadoRepository historial = mock(HistorialEstadoRepository.class);
    INotificationService notificaciones = mock(INotificationService.class);
    ReporteQueryServiceImpl consultas = mock(ReporteQueryServiceImpl.class);
    FotoArchivoRepository archivos = mock(FotoArchivoRepository.class);
    ReporteServiceImpl servicio;
    Ciudadano ana;

    @BeforeEach
    void preparar() {
        servicio = new ReporteServiceImpl(reportes, cuentas, tecnicos, ubicaciones, historial, notificaciones, consultas, archivos);
        ana = new Ciudadano("ana", "$2a$10$hash", new Persona("Ana", "Quispe", "45781230", "987654321", "ana@mail.com"));
        ana.setId(1L);
        when(cuentas.findById(1L)).thenReturn(Optional.of(ana));
        when(ubicaciones.save(any())).thenAnswer(i -> i.getArgument(0));
        when(reportes.save(any())).thenAnswer(i -> i.getArgument(0));
        when(consultas.convertirADTO(any())).thenAnswer(i -> {
            Reporte r = i.getArgument(0);
            ReporteDTO d = new ReporteDTO();
            d.setEstado(r.getEstado());
            return d;
        });
    }

    private ReporteDTO dto(String titulo, String descripcion, Double lat, Double lng, String direccion) {
        ReporteDTO d = new ReporteDTO();
        d.setTitulo(titulo);
        d.setDescripcion(descripcion);
        d.setCuentaId(1L);
        d.setTipoProblema(TipoProblema.ALUMBRADO);
        if (lat != null || lng != null || direccion != null) {
            UbicacionDTO u = new UbicacionDTO();
            u.setLatitud(lat);
            u.setLongitud(lng);
            u.setDireccion(direccion);
            d.setUbicacion(u);
        }
        return d;
    }

    private Reporte reporteEn(EstadoReporte estado) {
        Reporte r = new Reporte("Poste caido", "Poste inclinado sobre la vereda", ana);
        r.setId(10L);
        r.cambiarEstado(estado);
        when(reportes.findById(10L)).thenReturn(Optional.of(r));
        return r;
    }

    @Test
    @DisplayName("Crear un reporte valido lo deja PENDIENTE y registra el primer historial")
    void crearReporteValido() {
        ReporteDTO res = servicio.crearReporte(dto("Poste caido", "Poste inclinado", -12.08, -77.03, "Av. Arequipa 1234"));
        assertThat(res.getEstado()).isEqualTo(EstadoReporte.PENDIENTE);
        ArgumentCaptor<HistorialEstado> h = ArgumentCaptor.forClass(HistorialEstado.class);
        verify(historial).save(h.capture());
        assertThat(h.getValue().getEstadoAnterior()).isNull();
        assertThat(h.getValue().getEstadoNuevo()).isEqualTo(EstadoReporte.PENDIENTE);
    }

    @ParameterizedTest(name = "titulo de {0} caracteres y descripcion de {1} -> valido={2}")
    @CsvSource({"0,10,false", "1,10,true", "255,10,true", "256,10,false", "10,0,false", "10,1000,true", "10,1001,false"})
    @DisplayName("Valores limite de titulo (1..255) y descripcion (1..1000)")
    void limitesDeTexto(int largoTitulo, int largoDescripcion, boolean valido) {
        ReporteDTO d = dto("t".repeat(largoTitulo), "d".repeat(largoDescripcion), -12.0, -77.0, "Lima");
        if (valido) {
            assertThatCode(() -> servicio.crearReporte(d)).doesNotThrowAnyException();
        } else {
            assertThatThrownBy(() -> servicio.crearReporte(d)).isInstanceOf(RuntimeException.class);
            verify(reportes, never()).save(any());
        }
    }

    @Test
    @DisplayName("Sin ubicacion o sin coordenadas no se crea el reporte")
    void ubicacionObligatoria() {
        assertThatThrownBy(() -> servicio.crearReporte(dto("Poste", "Desc", null, null, null))).hasMessageContaining("ubicacion");
        assertThatThrownBy(() -> servicio.crearReporte(dto("Poste", "Desc", null, -77.0, "Lima"))).hasMessageContaining("latitud");
    }

    @Test
    @DisplayName("Sin direccion se guardan las coordenadas como direccion")
    void direccionPorDefecto() {
        servicio.crearReporte(dto("Poste", "Desc", -12.1, -77.0, "  "));
        ArgumentCaptor<Ubicacion> u = ArgumentCaptor.forClass(Ubicacion.class);
        verify(ubicaciones).save(u.capture());
        assertThat(u.getValue().getDireccion()).isEqualTo("Ubicación -12.10000, -77.00000");
    }

    @ParameterizedTest(name = "{0} -> {1} permitido={2}")
    @CsvSource({
            "PENDIENTE,REVISION,true", "REVISION,FINALIZADO,true",
            "PENDIENTE,FINALIZADO,false", "REVISION,PENDIENTE,false",
            "FINALIZADO,REVISION,false", "RECHAZADO,REVISION,false",
            "PENDIENTE,RECHAZADO,false"})
    @DisplayName("Tabla de transiciones del ciclo de estados")
    void transiciones(EstadoReporte desde, EstadoReporte hacia, boolean permitido) {
        Reporte r = reporteEn(desde);
        if (permitido) {
            servicio.cambiarEstadoReporte(10L, hacia);
            assertThat(r.getEstado()).isEqualTo(hacia);
            verify(historial).save(any(HistorialEstado.class));
            verify(notificaciones).enviarNotificacion(eq(1L), anyString(), anyString());
        } else {
            assertThatThrownBy(() -> servicio.cambiarEstadoReporte(10L, hacia)).isInstanceOf(RuntimeException.class);
            assertThat(r.getEstado()).isEqualTo(desde);
            verify(historial, never()).save(any());
        }
    }

    @Test
    @DisplayName("Rechazar guarda el motivo y la fecha de cierre; un FINALIZADO no se puede rechazar")
    void rechazar() {
        Reporte r = reporteEn(EstadoReporte.PENDIENTE);
        servicio.rechazarReporte(10L, "Duplicado");
        assertThat(r.getEstado()).isEqualTo(EstadoReporte.RECHAZADO);
        assertThat(r.getComentarioResolucion()).isEqualTo("Duplicado");
        assertThat(r.getFechaCierre()).isNotNull();

        reporteEn(EstadoReporte.FINALIZADO);
        assertThatThrownBy(() -> servicio.rechazarReporte(10L, "Tarde")).hasMessageContaining("FINALIZADO");
    }

    @Test
    @DisplayName("Solo se asigna tecnico a un reporte en REVISION")
    void asignarTecnico() {
        Tecnico carlos = new Tecnico("tec.carlos", "$2a$10$hash", new Persona("Carlos", "Mendoza", "70123456", "9", "c@muni.pe"));
        carlos.setId(4L);
        when(tecnicos.findById(4L)).thenReturn(Optional.of(carlos));

        reporteEn(EstadoReporte.PENDIENTE);
        assertThatThrownBy(() -> servicio.asignarTecnico(10L, 4L)).hasMessageContaining("REVISION");

        Reporte r = reporteEn(EstadoReporte.REVISION);
        servicio.asignarTecnico(10L, 4L);
        assertThat(r.getTecnico()).isSameAs(carlos);
    }
}
