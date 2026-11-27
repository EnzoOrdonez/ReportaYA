package com.ulima.incidenciaurbana.controller;

import com.ulima.incidenciaurbana.dto.HistorialEstadoDTO;
import com.ulima.incidenciaurbana.dto.ReporteDTO;
import com.ulima.incidenciaurbana.service.IHistorialEstadoService;
import com.ulima.incidenciaurbana.service.IReporteQueryService;
import com.ulima.incidenciaurbana.util.ApiErrores;
import com.ulima.incidenciaurbana.util.RequestAuth;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/historial-estados")
public class HistorialEstadoController {

    private final IHistorialEstadoService historialEstadoService;
    private final IReporteQueryService reporteQueryService;

    @Autowired
    public HistorialEstadoController(IHistorialEstadoService historialEstadoService,
                                     IReporteQueryService reporteQueryService) {
        this.historialEstadoService = historialEstadoService;
        this.reporteQueryService = reporteQueryService;
    }

    /** Mismo permiso que el detalle del reporte: operador, ciudadano duenio o tecnico asignado. */
    @GetMapping("/reporte/{reporteId}")
    public ResponseEntity<?> obtenerHistorialPorReporte(@PathVariable Long reporteId, HttpServletRequest request) {
        ReporteDTO reporte;
        try {
            reporte = reporteQueryService.obtenerReportePorId(reporteId);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(Map.of("error", ApiErrores.mensaje(e)));
        }
        RequestAuth.requireLecturaReporte(request, reporte.getCuentaId(), reporte.getTecnicoAsignadoId());
        List<HistorialEstadoDTO> historial = historialEstadoService.obtenerHistorialPorReporte(reporteId);
        return ResponseEntity.ok(historial);
    }
}
