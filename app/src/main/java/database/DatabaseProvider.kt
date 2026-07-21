package com.example.controlhorario.database

import android.content.Context
import androidx.room.Room
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

object DatabaseProvider {

    @Volatile
    private var INSTANCE: AppDatabase? = null

    fun getDatabase(context: Context): AppDatabase {

        return INSTANCE ?: synchronized(this) {

            val instance = Room.databaseBuilder(
                context.applicationContext,
                AppDatabase::class.java,
                "osinet_time_database"
            ).addMigrations(MIGRATION_26_27,MIGRATION_27_28,MIGRATION_28_29,MIGRATION_29_30,MIGRATION_30_31,MIGRATION_31_32,MIGRATION_32_33,MIGRATION_33_34,MIGRATION_34_35,MIGRATION_35_36).build()

            INSTANCE = instance

            instance
        }
    }
}

private val MIGRATION_26_27=object:Migration(26,27){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteId TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteBranchId TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteUpdatedAt TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN lastSyncedAt INTEGER")
 db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_employees_remoteId ON employees(remoteId)")
 db.execSQL("CREATE TABLE IF NOT EXISTS device_enrollment (deviceId TEXT NOT NULL PRIMARY KEY, installationId TEXT NOT NULL, credentialExpiresAt TEXT NOT NULL, enrolledAt INTEGER NOT NULL, lastEmployeeSyncAt INTEGER)")
}}

private val MIGRATION_27_28=object:Migration(27,28){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("ALTER TABLE employees ADD COLUMN email TEXT NOT NULL DEFAULT ''")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteBranchName TEXT NOT NULL DEFAULT ''")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteDepartmentId TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteDepartmentName TEXT NOT NULL DEFAULT ''")
 db.execSQL("ALTER TABLE employees ADD COLUMN remotePositionId TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN remotePositionName TEXT NOT NULL DEFAULT ''")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteSupervisorId TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteSupervisorName TEXT NOT NULL DEFAULT ''")
 db.execSQL("ALTER TABLE employees ADD COLUMN employmentStatus TEXT NOT NULL DEFAULT 'activo'")
 db.execSQL("ALTER TABLE employees ADD COLUMN startDate TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN payType TEXT")
 db.execSQL("ALTER TABLE device_enrollment ADD COLUMN employeeSyncCursorUpdatedAt TEXT")
 db.execSQL("ALTER TABLE device_enrollment ADD COLUMN employeeSyncCursorId TEXT")
}}

val MIGRATION_28_29=object:Migration(28,29){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("ALTER TABLE employees ADD COLUMN jornadaEnabled INTEGER NOT NULL DEFAULT 1")
 db.execSQL("CREATE TABLE IF NOT EXISTS journeys (localId INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, remoteId TEXT, employeeLocalId INTEGER NOT NULL, employeeRemoteId TEXT NOT NULL, deviceId TEXT NOT NULL, workDate TEXT NOT NULL, status TEXT NOT NULL, startedAt TEXT, pauseStartedAt TEXT, pauseEndedAt TEXT, finishedAt TEXT, workedMinutes INTEGER NOT NULL, breakMinutes INTEGER NOT NULL, syncStatus TEXT NOT NULL, syncVersion INTEGER NOT NULL, lastSyncedAt INTEGER, createdOffline INTEGER NOT NULL, updatedAt INTEGER NOT NULL, pendingReview INTEGER NOT NULL, severity TEXT NOT NULL, jornadaEnabledSnapshot INTEGER NOT NULL)")
 db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_journeys_employeeLocalId_workDate ON journeys(employeeLocalId,workDate)")
 db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_journeys_remoteId ON journeys(remoteId)")
 db.execSQL("CREATE INDEX IF NOT EXISTS index_journeys_syncStatus ON journeys(syncStatus)")
 db.execSQL("CREATE TABLE IF NOT EXISTS journey_outbox (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, journeyLocalId INTEGER NOT NULL, operation TEXT NOT NULL, idempotencyKey TEXT NOT NULL, payload TEXT NOT NULL, attempts INTEGER NOT NULL, nextRetryAt INTEGER NOT NULL, lastError TEXT NOT NULL, state TEXT NOT NULL, createdAt INTEGER NOT NULL, sentAt INTEGER)")
 db.execSQL("CREATE INDEX IF NOT EXISTS index_journey_outbox_journeyLocalId ON journey_outbox(journeyLocalId)")
 db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_journey_outbox_idempotencyKey ON journey_outbox(idempotencyKey)")
 db.execSQL("CREATE INDEX IF NOT EXISTS index_journey_outbox_state_nextRetryAt ON journey_outbox(state,nextRetryAt)")
 db.execSQL("CREATE TABLE IF NOT EXISTS journey_conflicts (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, journeyLocalId INTEGER NOT NULL, idempotencyKey TEXT NOT NULL, localSnapshot TEXT NOT NULL, remoteSnapshot TEXT NOT NULL, reason TEXT NOT NULL, resolutionState TEXT NOT NULL, createdAt INTEGER NOT NULL, resolvedAt INTEGER)")
 db.execSQL("CREATE INDEX IF NOT EXISTS index_journey_conflicts_journeyLocalId ON journey_conflicts(journeyLocalId)")
 db.execSQL("CREATE INDEX IF NOT EXISTS index_journey_conflicts_resolutionState ON journey_conflicts(resolutionState)")
}}

val MIGRATION_29_30=object:Migration(29,30){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteScheduleStart TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteScheduleEnd TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteLunchStart TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteLunchDurationMinutes INTEGER")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteWorkDays TEXT")
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteToleranceMinutes INTEGER")
}}

val MIGRATION_30_31=object:Migration(30,31){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("ALTER TABLE app_users ADD COLUMN email TEXT NOT NULL DEFAULT ''")
 db.execSQL("UPDATE app_users SET email=lower(trim(username)) WHERE instr(username,'@')>0")
 db.execSQL("UPDATE app_users SET email=lower(trim((SELECT email FROM employees WHERE employees.id=app_users.employeeId LIMIT 1))) WHERE email='' AND employeeId<>0 AND EXISTS(SELECT 1 FROM employees WHERE employees.id=app_users.employeeId AND trim(employees.email)<>'')")
}}

val MIGRATION_31_32=object:Migration(31,32){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("ALTER TABLE journeys ADD COLUMN startBranchId TEXT")
 db.execSQL("ALTER TABLE journeys ADD COLUMN endBranchId TEXT")
}}

val MIGRATION_32_33=object:Migration(32,33){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("CREATE TABLE IF NOT EXISTS employee_face_biometrics (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, employeeId INTEGER NOT NULL, encryptedEmbedding TEXT NOT NULL, embeddingVersion INTEGER NOT NULL, modelName TEXT NOT NULL, embeddingDimension INTEGER NOT NULL, registeredAt TEXT NOT NULL, registeredBy TEXT NOT NULL, updatedAt TEXT NOT NULL, isActive INTEGER NOT NULL)")
 db.execSQL("CREATE UNIQUE INDEX IF NOT EXISTS index_employee_face_biometrics_employeeId ON employee_face_biometrics(employeeId)")
}}

val MIGRATION_33_34=object:Migration(33,34){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("ALTER TABLE employees ADD COLUMN syncStatus TEXT NOT NULL DEFAULT 'PENDING'")
 db.execSQL("ALTER TABLE employees ADD COLUMN lastSyncError TEXT")
 db.execSQL("UPDATE employees SET syncStatus=CASE WHEN remoteId IS NULL THEN 'PENDING' ELSE 'SYNCED' END")
 db.execSQL("CREATE TABLE employee_sync_outbox (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, employeeLocalId INTEGER NOT NULL, operation TEXT NOT NULL, payloadJson TEXT NOT NULL, idempotencyKey TEXT NOT NULL, status TEXT NOT NULL, retryCount INTEGER NOT NULL, lastError TEXT, nextRetryAt INTEGER NOT NULL, createdAt INTEGER NOT NULL, updatedAt INTEGER NOT NULL)")
 db.execSQL("CREATE INDEX index_employee_sync_outbox_employeeLocalId ON employee_sync_outbox(employeeLocalId)")
 db.execSQL("CREATE INDEX index_employee_sync_outbox_status_nextRetryAt ON employee_sync_outbox(status,nextRetryAt)")
 db.execSQL("CREATE UNIQUE INDEX index_employee_sync_outbox_idempotencyKey ON employee_sync_outbox(idempotencyKey)")
}}

val MIGRATION_34_35=object:Migration(34,35){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("ALTER TABLE device_enrollment ADD COLUMN companyId TEXT")
 db.execSQL("ALTER TABLE device_enrollment ADD COLUMN branchId TEXT")
 db.execSQL("CREATE TABLE IF NOT EXISTS kiosk_settings (companyId TEXT NOT NULL, deviceId TEXT NOT NULL, faceOnlyEnabled INTEGER NOT NULL, pinFallbackEnabled INTEGER NOT NULL, faceMatchThreshold REAL NOT NULL, faceMatchMargin REAL, remoteUpdatedAt TEXT NOT NULL, lastSyncedAt INTEGER NOT NULL, PRIMARY KEY(companyId,deviceId))")
}}

val MIGRATION_35_36=object:Migration(35,36){override fun migrate(db:SupportSQLiteDatabase){
 db.execSQL("ALTER TABLE employees ADD COLUMN remoteCompanyId TEXT")
}}
