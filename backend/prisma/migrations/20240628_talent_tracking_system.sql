/*
  MIGRACIÓN: Talent Tracking System
  FECHA: 28/06/2024
  DESCRIPCIÓN: Implementación del modelo de datos para sistema de seguimiento de talento
  
  CAMBIOS PRINCIPALES:
  - Creación de tipos ENUM para categorización de datos
  - Mejora de la entidad Candidate existente
  - Creación de nuevas entidades relacionadas con el proceso de contratación
  - Adición de índices optimizados para consultas frecuentes
  - Implementación de soft-delete en entidades principales
  - Configuración de triggers para actualización automática de timestamps
  
  Esta migración implementa un modelo completo para gestión de candidatos, 
  posiciones, entrevistas y empresas según el diagrama ERD proporcionado.
*/

-- -----------------------------------------------------
-- TIPOS ENUMERADOS
-- -----------------------------------------------------
-- Justificación: Los tipos ENUM garantizan consistencia de datos, mejoran la legibilidad
-- del código y optimizan el rendimiento de la base de datos al usar valores predefinidos.

-- CreateEnum: Estados posibles de una posición laboral
CREATE TYPE "PositionStatus" AS ENUM (
    'OPEN',      -- Posición abierta y visible para aplicaciones
    'CLOSED',    -- Posición cerrada, no acepta más aplicaciones
    'DRAFT',     -- Posición en borrador, no publicada
    'ARCHIVED'   -- Posición archivada, no visible pero conservada para referencia
);

-- CreateEnum: Estados posibles de una aplicación
CREATE TYPE "ApplicationStatus" AS ENUM (
    'APPLIED',      -- Candidato ha enviado su aplicación
    'SCREENING',    -- Aplicación en fase de revisión inicial
    'INTERVIEWING', -- Candidato en proceso de entrevistas
    'OFFERED',      -- Se ha realizado una oferta al candidato
    'HIRED',        -- Candidato contratado
    'REJECTED',     -- Aplicación rechazada
    'WITHDRAWN'     -- Candidato retiró su aplicación
);

-- CreateEnum: Resultados posibles de una entrevista
CREATE TYPE "InterviewResult" AS ENUM (
    'PENDING',      -- Entrevista programada pero no realizada
    'PASSED',       -- Candidato superó la entrevista
    'FAILED',       -- Candidato no superó la entrevista
    'NO_SHOW',      -- Candidato no se presentó a la entrevista
    'RESCHEDULED',  -- Entrevista reprogramada
    'CANCELLED'     -- Entrevista cancelada
);

-- CreateEnum: Tipos de empleo
CREATE TYPE "EmploymentType" AS ENUM (
    'FULL_TIME',   -- Jornada completa
    'PART_TIME',   -- Jornada parcial
    'CONTRACT',    -- Contrato temporal
    'FREELANCE',   -- Autónomo/freelance
    'INTERNSHIP'   -- Prácticas/pasantía
);

-- -----------------------------------------------------
-- MEJORAS A TABLAS EXISTENTES
-- -----------------------------------------------------
-- Justificación: Añadir campos de auditoría (timestamps) y soft-delete permite
-- mantener un historial completo de los cambios y evitar la eliminación permanente
-- de datos importantes, facilitando la recuperación si es necesario.

-- AlterTable: Añadir campos de timestamp y soft delete a Candidate
ALTER TABLE "Candidate" 
ADD COLUMN "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN "deletedAt" TIMESTAMP(3);

-- -----------------------------------------------------
-- NUEVAS TABLAS
-- -----------------------------------------------------
-- Justificación: Se crean nuevas entidades que modelan el proceso completo
-- de contratación, desde la empresa que ofrece las posiciones hasta las
-- entrevistas realizadas, siguiendo el principio de normalización.

-- CreateTable: Company
-- Justificación: Centraliza la información de empresas que ofrecen posiciones
CREATE TABLE "Company" (
    "id" SERIAL NOT NULL,
    "name" VARCHAR(100) NOT NULL,              -- Nombre de la empresa
    "description" TEXT,                         -- Descripción detallada de la empresa
    "logo" VARCHAR(500),                        -- URL del logo de la empresa
    "website" VARCHAR(255),                     -- Sitio web oficial de la empresa
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),                   -- Para soft-delete

    CONSTRAINT "Company_pkey" PRIMARY KEY ("id")
);

-- CreateTable: Employee
-- Justificación: Representa a los empleados de una empresa que participan en el proceso de contratación
CREATE TABLE "Employee" (
    "id" SERIAL NOT NULL,
    "companyId" INTEGER NOT NULL,               -- Empresa a la que pertenece
    "name" VARCHAR(200) NOT NULL,               -- Nombre completo del empleado
    "email" VARCHAR(255) NOT NULL,              -- Email de contacto (único)
    "role" VARCHAR(100) NOT NULL,               -- Rol en la empresa
    "isActive" BOOLEAN NOT NULL DEFAULT true,   -- Estado activo/inactivo
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),                   -- Para soft-delete

    CONSTRAINT "Employee_pkey" PRIMARY KEY ("id")
);

-- CreateTable: InterviewType
-- Justificación: Catálogo de tipos de entrevistas posibles
CREATE TABLE "InterviewType" (
    "id" SERIAL NOT NULL,
    "name" VARCHAR(100) NOT NULL,               -- Nombre del tipo (técnica, RRHH, etc.)
    "description" TEXT,                         -- Descripción del tipo de entrevista
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "InterviewType_pkey" PRIMARY KEY ("id")
);

-- CreateTable: InterviewFlow
-- Justificación: Define flujos de entrevistas personalizados para diferentes posiciones
CREATE TABLE "InterviewFlow" (
    "id" SERIAL NOT NULL,
    "name" VARCHAR(100) NOT NULL,               -- Nombre del flujo
    "description" TEXT,                         -- Descripción del flujo
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "InterviewFlow_pkey" PRIMARY KEY ("id")
);

-- CreateTable: InterviewStep
-- Justificación: Define los pasos específicos dentro de un flujo de entrevistas
CREATE TABLE "InterviewStep" (
    "id" SERIAL NOT NULL,
    "interviewFlowId" INTEGER NOT NULL,         -- Flujo al que pertenece
    "interviewTypeId" INTEGER NOT NULL,         -- Tipo de entrevista para este paso
    "name" VARCHAR(100) NOT NULL,               -- Nombre del paso
    "orderIndex" INTEGER NOT NULL,              -- Orden dentro del flujo
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "InterviewStep_pkey" PRIMARY KEY ("id")
);

-- CreateTable: Position
-- Justificación: Representa ofertas de trabajo disponibles
CREATE TABLE "Position" (
    "id" SERIAL NOT NULL,
    "companyId" INTEGER NOT NULL,               -- Empresa que ofrece la posición
    "interviewFlowId" INTEGER NOT NULL,         -- Flujo de entrevistas asignado
    "title" VARCHAR(100) NOT NULL,              -- Título del puesto
    "description" TEXT,                         -- Descripción general
    "status" "PositionStatus" NOT NULL DEFAULT 'DRAFT', -- Estado (borrador por defecto)
    "isVisible" BOOLEAN NOT NULL DEFAULT false, -- Visibilidad pública
    "location" VARCHAR(100),                    -- Ubicación geográfica
    "jobDescription" TEXT,                      -- Descripción detallada del trabajo
    "requirements" TEXT,                        -- Requisitos para el puesto
    "responsibilities" TEXT,                    -- Responsabilidades del puesto
    "salaryMin" DECIMAL(10,2),                  -- Salario mínimo ofrecido
    "salaryMax" DECIMAL(10,2),                  -- Salario máximo ofrecido
    "employmentType" "EmploymentType" NOT NULL DEFAULT 'FULL_TIME', -- Tipo de contrato
    "benefits" TEXT,                            -- Beneficios ofrecidos
    "companyDescription" TEXT,                  -- Descripción específica de la empresa para esta posición
    "applicationDeadline" DATE,                 -- Fecha límite para aplicar
    "contactInfo" VARCHAR(255),                 -- Información de contacto
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),                   -- Para soft-delete

    CONSTRAINT "Position_pkey" PRIMARY KEY ("id")
);

-- CreateTable: Application
-- Justificación: Representa la aplicación de un candidato a una posición específica
CREATE TABLE "Application" (
    "id" SERIAL NOT NULL,
    "positionId" INTEGER NOT NULL,              -- Posición a la que aplica
    "candidateId" INTEGER NOT NULL,             -- Candidato que aplica
    "applicationDate" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, -- Fecha de aplicación
    "status" "ApplicationStatus" NOT NULL DEFAULT 'APPLIED', -- Estado inicial
    "notes" TEXT,                               -- Notas sobre la aplicación
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "deletedAt" TIMESTAMP(3),                   -- Para soft-delete

    CONSTRAINT "Application_pkey" PRIMARY KEY ("id")
);

-- CreateTable: Interview
-- Justificación: Registra entrevistas específicas realizadas a un candidato
CREATE TABLE "Interview" (
    "id" SERIAL NOT NULL,
    "applicationId" INTEGER NOT NULL,           -- Aplicación asociada
    "interviewStepId" INTEGER NOT NULL,         -- Paso de entrevista correspondiente
    "employeeId" INTEGER NOT NULL,              -- Empleado que realiza la entrevista
    "interviewDate" TIMESTAMP(3) NOT NULL,      -- Fecha y hora programada
    "result" "InterviewResult" NOT NULL DEFAULT 'PENDING', -- Resultado inicial
    "score" INTEGER,                            -- Puntuación opcional
    "notes" TEXT,                               -- Notas de la entrevista
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Interview_pkey" PRIMARY KEY ("id")
);

-- -----------------------------------------------------
-- ÍNDICES
-- -----------------------------------------------------
-- Justificación: Los índices optimizan las búsquedas frecuentes, mejorando
-- significativamente el rendimiento de la base de datos en consultas comunes.

-- CreateIndex para Company
CREATE UNIQUE INDEX "Company_name_key" ON "Company"("name");
CREATE INDEX "Company_name_idx" ON "Company"("name");

-- CreateIndex para Employee
CREATE UNIQUE INDEX "Employee_email_key" ON "Employee"("email");
CREATE INDEX "Employee_companyId_idx" ON "Employee"("companyId");
CREATE INDEX "Employee_email_idx" ON "Employee"("email");

-- CreateIndex para InterviewType
CREATE UNIQUE INDEX "InterviewType_name_key" ON "InterviewType"("name");

-- CreateIndex para InterviewFlow
CREATE UNIQUE INDEX "InterviewFlow_name_key" ON "InterviewFlow"("name");

-- CreateIndex para InterviewStep
-- Justificación: Garantiza que no haya dos pasos con el mismo orden en un flujo
CREATE UNIQUE INDEX "InterviewStep_interviewFlowId_orderIndex_key" ON "InterviewStep"("interviewFlowId", "orderIndex");
CREATE INDEX "InterviewStep_interviewFlowId_idx" ON "InterviewStep"("interviewFlowId");
CREATE INDEX "InterviewStep_interviewTypeId_idx" ON "InterviewStep"("interviewTypeId");

-- CreateIndex para Position
-- Justificación: Optimiza búsquedas de posiciones por empresa, estado, título y ubicación
CREATE INDEX "Position_companyId_idx" ON "Position"("companyId");
CREATE INDEX "Position_status_idx" ON "Position"("status");
CREATE INDEX "Position_title_idx" ON "Position"("title");
CREATE INDEX "Position_location_idx" ON "Position"("location");
CREATE INDEX "Position_isVisible_idx" ON "Position"("isVisible");

-- CreateIndex para Application
-- Justificación: Impide que un candidato aplique dos veces a la misma posición
CREATE UNIQUE INDEX "Application_candidateId_positionId_key" ON "Application"("candidateId", "positionId") WHERE "deletedAt" IS NULL;
CREATE INDEX "Application_candidateId_idx" ON "Application"("candidateId");
CREATE INDEX "Application_positionId_idx" ON "Application"("positionId");
CREATE INDEX "Application_status_idx" ON "Application"("status");
CREATE INDEX "Application_applicationDate_idx" ON "Application"("applicationDate");

-- CreateIndex para Interview
-- Justificación: Optimiza consultas de entrevistas por aplicación, paso, empleado y fecha
CREATE INDEX "Interview_applicationId_idx" ON "Interview"("applicationId");
CREATE INDEX "Interview_interviewStepId_idx" ON "Interview"("interviewStepId");
CREATE INDEX "Interview_employeeId_idx" ON "Interview"("employeeId");
CREATE INDEX "Interview_interviewDate_idx" ON "Interview"("interviewDate");
CREATE INDEX "Interview_result_idx" ON "Interview"("result");

-- CreateIndex para Candidate existente
-- Justificación: Mejora búsquedas por email y nombre
CREATE INDEX "Candidate_email_idx" ON "Candidate"("email");
CREATE INDEX "Candidate_firstName_lastName_idx" ON "Candidate"("firstName", "lastName");

-- -----------------------------------------------------
-- RESTRICCIONES DE INTEGRIDAD REFERENCIAL
-- -----------------------------------------------------
-- Justificación: Aseguran la integridad de los datos al vincular tablas relacionadas
-- y previenen la eliminación accidental de datos referenciados por otras tablas.

-- AddForeignKey: Employee -> Company
ALTER TABLE "Employee" ADD CONSTRAINT "Employee_companyId_fkey" 
FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: InterviewStep -> InterviewFlow
ALTER TABLE "InterviewStep" ADD CONSTRAINT "InterviewStep_interviewFlowId_fkey" 
FOREIGN KEY ("interviewFlowId") REFERENCES "InterviewFlow"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: InterviewStep -> InterviewType
ALTER TABLE "InterviewStep" ADD CONSTRAINT "InterviewStep_interviewTypeId_fkey" 
FOREIGN KEY ("interviewTypeId") REFERENCES "InterviewType"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: Position -> Company
ALTER TABLE "Position" ADD CONSTRAINT "Position_companyId_fkey" 
FOREIGN KEY ("companyId") REFERENCES "Company"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: Position -> InterviewFlow
ALTER TABLE "Position" ADD CONSTRAINT "Position_interviewFlowId_fkey" 
FOREIGN KEY ("interviewFlowId") REFERENCES "InterviewFlow"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: Application -> Position
ALTER TABLE "Application" ADD CONSTRAINT "Application_positionId_fkey" 
FOREIGN KEY ("positionId") REFERENCES "Position"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: Application -> Candidate
ALTER TABLE "Application" ADD CONSTRAINT "Application_candidateId_fkey" 
FOREIGN KEY ("candidateId") REFERENCES "Candidate"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: Interview -> Application
ALTER TABLE "Interview" ADD CONSTRAINT "Interview_applicationId_fkey" 
FOREIGN KEY ("applicationId") REFERENCES "Application"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: Interview -> InterviewStep
ALTER TABLE "Interview" ADD CONSTRAINT "Interview_interviewStepId_fkey" 
FOREIGN KEY ("interviewStepId") REFERENCES "InterviewStep"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey: Interview -> Employee
ALTER TABLE "Interview" ADD CONSTRAINT "Interview_employeeId_fkey" 
FOREIGN KEY ("employeeId") REFERENCES "Employee"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- -----------------------------------------------------
-- TRIGGERS PARA AUTOMATIZACIÓN
-- -----------------------------------------------------
-- Justificación: Automatizan la actualización de campos updatedAt, garantizando
-- que se registre la fecha/hora exacta de cada modificación sin intervención manual.

-- Función para actualización automática de timestamps
CREATE OR REPLACE FUNCTION update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
   NEW."updatedAt" = NOW();
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Aplicar trigger a todas las tablas que tienen updatedAt
-- Justificación: Mantiene consistencia en todos los registros de la BD
CREATE TRIGGER update_candidate_timestamp
BEFORE UPDATE ON "Candidate"
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_company_timestamp
BEFORE UPDATE ON "Company"
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_employee_timestamp
BEFORE UPDATE ON "Employee"
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_interview_type_timestamp
BEFORE UPDATE ON "InterviewType"
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_interview_flow_timestamp
BEFORE UPDATE ON "InterviewFlow"
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_interview_step_timestamp
BEFORE UPDATE ON "InterviewStep"
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_position_timestamp
BEFORE UPDATE ON "Position"
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_application_timestamp
BEFORE UPDATE ON "Application"
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

CREATE TRIGGER update_interview_timestamp
BEFORE UPDATE ON "Interview"
FOR EACH ROW
EXECUTE FUNCTION update_timestamp(); 