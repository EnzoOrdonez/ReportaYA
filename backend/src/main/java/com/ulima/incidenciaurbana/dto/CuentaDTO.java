package com.ulima.incidenciaurbana.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * DTO genérico para cualquier tipo de cuenta (Ciudadano, Tecnico, OperadorMunicipal)
 * Se usa tanto para crear como para responder
 * Incluye validaciones para los campos requeridos
 */
public class CuentaDTO {

    /** Letra inicial y luego letras (con tildes), espacios, guiones o apóstrofes. */
    public static final String NOMBRE_VALIDO = "^\\p{L}[\\p{L}\\p{M} '’-]*$";
    
    @NotBlank(message = "El tipo de cuenta es obligatorio")
    private String tipoCuenta; // CIUDADANO, TECNICO, OPERADOR_MUNICIPAL
    
    @NotBlank(message = "El usuario es obligatorio")
    @Size(min = 3, max = 50, message = "El usuario debe tener entre 3 y 50 caracteres")
    private String usuario;
    
    @NotBlank(message = "La contraseña es obligatoria")
    @Size(min = 8, message = "La contraseña debe tener al menos 8 caracteres")
    private String contrasena;
    
    // HU-01: de 2 a 100 caracteres; se admiten tildes, espacios, guiones y apóstrofes.
    @NotBlank(message = "Los nombres son obligatorios")
    @Size(min = 2, max = 100, message = "Los nombres deben tener entre 2 y 100 caracteres")
    @Pattern(regexp = NOMBRE_VALIDO, message = "Los nombres solo admiten letras, espacios, guiones y apóstrofes")
    private String nombres;
    
    @NotBlank(message = "Los apellidos son obligatorios")
    @Size(min = 2, max = 100, message = "Los apellidos deben tener entre 2 y 100 caracteres")
    @Pattern(regexp = NOMBRE_VALIDO, message = "Los apellidos solo admiten letras, espacios, guiones y apóstrofes")
    private String apellidos;
    
    @NotBlank(message = "El DNI es obligatorio")
    @Size(min = 8, max = 8, message = "El DNI debe tener 8 dígitos")
    @Pattern(regexp = "\\d{8}", message = "El DNI debe tener 8 dígitos numéricos")
    private String dni;
    
    @NotBlank(message = "El teléfono es obligatorio")
    @Pattern(regexp = "\\d{9}", message = "El teléfono debe tener 9 dígitos numéricos")
    private String telefono;
    
    @NotBlank(message = "El correo es obligatorio")
    @Email(message = "El correo debe ser válido")
    private String correo;
    
    @NotNull(message = "El estado activo es obligatorio")
    private Boolean activo;
    
    /** RF-21: el registro público exige aceptar el aviso de privacidad. */
    private Boolean aceptaPrivacidad;

    private Long id; // Para respuestas
    
    // Constructors
    public CuentaDTO() {
        this.activo = true;
    }
    
    public CuentaDTO(String tipoCuenta, String usuario, String contrasena, String nombres, 
                     String apellidos, String dni, String telefono, String correo) {
        this.tipoCuenta = tipoCuenta;
        this.usuario = usuario;
        this.contrasena = contrasena;
        this.nombres = nombres;
        this.apellidos = apellidos;
        this.dni = dni;
        this.telefono = telefono;
        this.correo = correo;
        this.activo = true;
    }
    
    // Getters and Setters
    public String getTipoCuenta() {
        return tipoCuenta;
    }
    
    public void setTipoCuenta(String tipoCuenta) {
        this.tipoCuenta = tipoCuenta;
    }
    
    public String getUsuario() {
        return usuario;
    }
    
    public void setUsuario(String usuario) {
        this.usuario = usuario;
    }
    
    public String getContrasena() {
        return contrasena;
    }
    
    public void setContrasena(String contrasena) {
        this.contrasena = contrasena;
    }
    
    public String getNombres() {
        return nombres;
    }
    
    public void setNombres(String nombres) {
        this.nombres = nombres;
    }
    
    public String getApellidos() {
        return apellidos;
    }
    
    public void setApellidos(String apellidos) {
        this.apellidos = apellidos;
    }
    
    public String getDni() {
        return dni;
    }
    
    public void setDni(String dni) {
        this.dni = dni;
    }
    
    public String getTelefono() {
        return telefono;
    }
    
    public void setTelefono(String telefono) {
        this.telefono = telefono;
    }
    
    public String getCorreo() {
        return correo;
    }
    
    public void setCorreo(String correo) {
        this.correo = correo;
    }
    
    public Boolean getAceptaPrivacidad() {
        return aceptaPrivacidad;
    }

    public void setAceptaPrivacidad(Boolean aceptaPrivacidad) {
        this.aceptaPrivacidad = aceptaPrivacidad;
    }

    public Boolean getActivo() {
        return activo;
    }
    
    public void setActivo(Boolean activo) {
        this.activo = activo;
    }
    
    public Long getId() {
        return id;
    }
    
    public void setId(Long id) {
        this.id = id;
    }
}
