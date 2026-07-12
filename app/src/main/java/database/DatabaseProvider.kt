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
            ).addMigrations(MIGRATION_26_27,MIGRATION_27_28).build()

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
