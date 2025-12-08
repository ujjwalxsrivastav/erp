#!/bin/bash
# Database Backup and Restore Script for ERP
# Usage: ./db_backup.sh backup OR ./db_backup.sh restore
# 
# SET DB_URL ENVIRONMENT VARIABLE BEFORE RUNNING:
# export DB_URL="postgresql://postgres:YOUR_PASSWORD@db.YOUR_PROJECT.supabase.co:5432/postgres"

if [ -z "$DB_URL" ]; then
  echo "❌ Error: DB_URL environment variable not set!"
  echo ""
  echo "Please set it first:"
  echo 'export DB_URL="postgresql://postgres:YOUR_PASSWORD@db.YOUR_PROJECT.supabase.co:5432/postgres"'
  exit 1
fi

BACKUP_DIR="database_export"
PSQL="/opt/homebrew/opt/libpq/bin/psql"
PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"

case "$1" in
  backup)
    echo "📦 Creating database backup..."
    mkdir -p $BACKUP_DIR
    
    # Schema backup
    $PG_DUMP $DB_URL --schema-only > "$BACKUP_DIR/schema_backup_$(date +%Y%m%d_%H%M%S).sql"
    echo "✅ Schema backed up"
    
    # Data backup
    $PG_DUMP $DB_URL --data-only > "$BACKUP_DIR/data_backup_$(date +%Y%m%d_%H%M%S).sql"
    echo "✅ Data backed up"
    
    echo "🎉 Backup complete! Files saved in $BACKUP_DIR/"
    ;;
    
  restore)
    if [ -z "$2" ]; then
      echo "Usage: ./db_backup.sh restore <backup_file.sql>"
      exit 1
    fi
    
    echo "🔄 Restoring from $2..."
    $PSQL $DB_URL -f "$2"
    echo "✅ Restore complete!"
    ;;
    
  check)
    echo "🔍 Checking database status..."
    $PSQL $DB_URL -c "
    SELECT 'users' as table_name, COUNT(*) as count FROM users
    UNION ALL SELECT 'teacher_details', COUNT(*) FROM teacher_details
    UNION ALL SELECT 'student_details', COUNT(*) FROM student_details
    UNION ALL SELECT 'subjects', COUNT(*) FROM subjects
    UNION ALL SELECT 'timetable', COUNT(*) FROM timetable
    UNION ALL SELECT 'classes', COUNT(*) FROM classes
    UNION ALL SELECT 'holidays', COUNT(*) FROM holidays
    ORDER BY table_name;
    "
    ;;
    
  seed)
    echo "🌱 Seeding essential data..."
    
    # Run fix scripts
    if [ -f "$BACKUP_DIR/fix_subjects.sql" ]; then
      $PSQL $DB_URL -f "$BACKUP_DIR/fix_subjects.sql"
      echo "✅ Subjects seeded"
    fi
    
    if [ -f "$BACKUP_DIR/fix_timetable.sql" ]; then
      $PSQL $DB_URL -f "$BACKUP_DIR/fix_timetable.sql"
      echo "✅ Timetable seeded"
    fi
    
    echo "🎉 Seeding complete!"
    ;;
    
  fix-rls)
    echo "🔓 Fixing RLS policies for all tables..."
    $PSQL $DB_URL -c "
    DO \$\$
    DECLARE
        tbl RECORD;
    BEGIN
        FOR tbl IN 
            SELECT tablename FROM pg_tables WHERE schemaname = 'public'
        LOOP
            EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl.tablename);
            EXECUTE format('DROP POLICY IF EXISTS \"Allow all\" ON public.%I', tbl.tablename);
            EXECUTE format('CREATE POLICY \"Allow all\" ON public.%I FOR ALL USING (true) WITH CHECK (true)', tbl.tablename);
        END LOOP;
    END \$\$;
    "
    echo "✅ RLS policies fixed!"
    ;;
    
  *)
    echo "Database Management Script"
    echo "=========================="
    echo "Usage: ./db_backup.sh <command>"
    echo ""
    echo "Commands:"
    echo "  backup     - Create backup of schema and data"
    echo "  restore    - Restore from a backup file"
    echo "  check      - Check current data counts"
    echo "  seed       - Seed essential data (subjects, timetable)"
    echo "  fix-rls    - Fix RLS policies for all tables"
    ;;
esac
