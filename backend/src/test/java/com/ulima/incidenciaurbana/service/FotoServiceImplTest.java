package com.ulima.incidenciaurbana.service;

import com.ulima.incidenciaurbana.dto.FotoDTO;
import com.ulima.incidenciaurbana.model.*;
import com.ulima.incidenciaurbana.repository.FotoArchivoRepository;
import com.ulima.incidenciaurbana.repository.FotoRepository;
import com.ulima.incidenciaurbana.repository.ReporteRepository;
import com.ulima.incidenciaurbana.service.impl.FotoServiceImpl;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import java.util.Base64;
import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class FotoServiceImplTest {

    FotoRepository fotos = mock(FotoRepository.class);
    ReporteRepository reportes = mock(ReporteRepository.class);
    IFirebaseStorageService firebase = mock(IFirebaseStorageService.class);
    FotoArchivoRepository archivos = mock(FotoArchivoRepository.class);
    FotoServiceImpl servicio;
    static final byte[] PNG = {(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3};
    static final byte[] JPG = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0, 1, 2};

    @BeforeEach
    void preparar() {
        servicio = new FotoServiceImpl(fotos, reportes, firebase, archivos);
        Reporte r = new Reporte("t", "d", null);
        r.setId(5L);
        when(reportes.findById(5L)).thenReturn(Optional.of(r));
        when(fotos.save(any())).thenAnswer(i -> i.getArgument(0));
        when(firebase.isAvailable()).thenReturn(false);
    }

    private String b64(byte[] b) { return Base64.getEncoder().encodeToString(b); }

    @Test
    @DisplayName("Sin Firebase la foto se guarda en la base con su tipo MIME y una URL /media/fotos/{clave}")
    void guardaEnBase() {
        FotoDTO dto = servicio.subirFoto(5L, b64(PNG), TipoFoto.INICIAL, "foto");
        ArgumentCaptor<FotoArchivo> a = ArgumentCaptor.forClass(FotoArchivo.class);
        verify(archivos).save(a.capture());
        assertThat(a.getValue().getContentType()).isEqualTo("image/png");
        assertThat(dto.getUrl()).contains("/media/fotos/");
        verify(firebase, never()).uploadFile(anyString(), any());
    }

    @Test
    @DisplayName("Acepta un data-URI y detecta JPEG por su firma")
    void dataUri() {
        servicio.subirFoto(5L, "data:image/jpeg;base64," + b64(JPG), TipoFoto.INICIAL, "foto");
        ArgumentCaptor<FotoArchivo> a = ArgumentCaptor.forClass(FotoArchivo.class);
        verify(archivos).save(a.capture());
        assertThat(a.getValue().getContentType()).isEqualTo("image/jpeg");
    }

    @Test
    @DisplayName("Con Firebase disponible la foto se sube al bucket")
    void usaFirebase() {
        when(firebase.isAvailable()).thenReturn(true);
        when(firebase.uploadFile(anyString(), any())).thenReturn("https://storage.example/f.png");
        assertThat(servicio.subirFoto(5L, b64(PNG), TipoFoto.FINAL, "f").getUrl()).isEqualTo("https://storage.example/f.png");
        verify(archivos, never()).save(any());
    }

    @Test
    @DisplayName("Rechaza base64 invalido, archivo vacio y archivos de mas de 5 MB")
    void validaciones() {
        assertThatThrownBy(() -> servicio.subirFoto(5L, "%%%", TipoFoto.INICIAL, "x")).hasMessageContaining("base64");
        assertThatThrownBy(() -> servicio.subirFoto(5L, "", TipoFoto.INICIAL, "x")).hasMessageContaining("vacía");
        byte[] limite = new byte[5 * 1024 * 1024];
        System.arraycopy(PNG, 0, limite, 0, PNG.length);
        assertThatCode(() -> servicio.subirFoto(5L, b64(limite), TipoFoto.INICIAL, "x")).doesNotThrowAnyException();
        byte[] grande = new byte[5 * 1024 * 1024 + 1];
        assertThatThrownBy(() -> servicio.subirFoto(5L, b64(grande), TipoFoto.INICIAL, "x")).hasMessageContaining("5 MB");
    }
}
