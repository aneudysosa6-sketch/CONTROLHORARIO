# OSINET Time ERP

> Sistema ERP profesional de Recursos Humanos para la República Dominicana.

---

# Descripción

OSINET Time ERP es una plataforma integral para la administración del capital humano de empresas pequeñas, medianas y grandes.

El sistema está siendo desarrollado completamente en Android utilizando Kotlin, Jetpack Compose y Room Database, con una arquitectura preparada para evolucionar hacia una solución híbrida Android + Web.

---

# Objetivos

El objetivo del proyecto es reemplazar múltiples sistemas independientes por una sola plataforma capaz de administrar:

- Empleados
- Asistencia
- Jornadas laborales
- Horarios
- Calendario laboral
- Nómina
- Expediente digital
- Documentos
- PDF
- WhatsApp
- Portal del empleado
- Portal administrativo
- Inteligencia Artificial
- Automatizaciones mediante n8n

---

# Tecnologías

## Lenguaje

Kotlin

## Framework

Jetpack Compose

## UI

Material Design 3

## Base de datos

Room Database

## Arquitectura

MVVM

Repository Pattern

Engine Pattern

StateFlow

Navigation Compose

---

# Compatibilidad

Android 9 o superior

---

# Estado del proyecto

Actualmente el sistema se encuentra en desarrollo activo.

Los módulos principales ya funcionan correctamente.

---

# Módulos implementados

✔ Login

✔ Dashboard

✔ Empleados

✔ Perfil del empleado

✔ Expediente Digital

✔ Documentos

✔ Departamentos

✔ Sucursales

✔ Horarios

✔ Calendario Laboral

✔ Asistencia

✔ Configuración de Nómina

✔ Nómina por empleado

✔ Historial de Nómina

✔ PDF de Nómina

✔ Datos de Empresa

✔ Motores WhatsApp

---

# Próximos módulos

Vacaciones

Permisos

Licencias

Capacitaciones

Evaluaciones

Créditos

Beneficios

Portal del Empleado

Portal Administrativo

Sincronización Cloud

API REST

---

# Arquitectura General

Android App

↓

Room Database

↓

Repository

↓

ViewModel

↓

Jetpack Compose

↓

Motores (Engine)

↓

PDF

↓

WhatsApp

↓

n8n

↓

Portal Web

---

# Organización del proyecto

```
app/

database/

repository/

model/

engine/

ui/

navigation/

utils/

docs/
```

---

# Documentación

Toda la documentación oficial del proyecto se encuentra dentro de la carpeta:

```
docs/
```

---

# Director del proyecto

José Aneudy Sosa Valdez

OSINET

República Dominicana

---

# Arquitectura del software

OpenAI ChatGPT

Rol:

Arquitecto principal del proyecto.

Responsabilidades

- Arquitectura
- Diseño de Base de Datos
- Diseño de módulos
- Diseño de navegación
- Motores
- WhatsApp
- n8n
- Portal Web
- Documentación
- Escalabilidad

---

# Filosofía del proyecto

OSINET Time ERP no es únicamente una aplicación de control horario.

Es un ERP moderno de Recursos Humanos diseñado para crecer de forma modular, escalable y profesional, preparado para integrarse con inteligencia artificial, automatizaciones, servicios web y futuras plataformas empresariales.

Cada módulo debe poder evolucionar sin romper los módulos existentes.

La estabilidad del sistema siempre tendrá prioridad sobre la velocidad de desarrollo.