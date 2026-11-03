# 🏗️ ERP Project — Architecture Graph

## 📊 High-Level Architecture

```mermaid
graph TB
    subgraph Entry["🚀 Entry Point"]
        main["main.dart"]
    end

    subgraph Core["⚙️ Core Layer"]
        config["Config"]
        theme["Theme"]
        widgets["Widgets"]
        utils["Utils"]
        security["Security"]
    end

    subgraph Router["🔀 Router"]
        app_router["app_router.dart"]
    end

    subgraph Services["🔧 Services Layer"]
        auth_svc["AuthService"]
        admin_svc["AdminService"]
        student_svc["StudentService"]
        teacher_svc["TeacherService"]
        hr_svc["HRService"]
        leave_svc["LeaveService"]
        fees_svc["FeesService"]
        events_svc["EventsService"]
        timetable_svc["TimetableService"]
        cache_svc["CacheManager"]
        offline_svc["OfflineService"]
        supabase_svc["SupabaseService"]
        pdf_svc["StaffPDFService"]
    end

    subgraph Features["📦 Feature Modules"]
        auth["🔐 Auth"]
        dashboard["📊 Dashboards"]
        student["🎓 Student"]
        teacher["👨‍🏫 Teacher"]
        admin["🛡️ Admin"]
        hod["👔 HOD"]
        hostel["🏠 Hostel"]
        transport["🚌 Transport"]
        admission["📝 Admission"]
        leads["📈 Leads"]
        leave["🌴 Leave"]
        hr["👥 HR"]
        fees["💰 Fees"]
        notices["📢 Notices"]
        timetable["🗓️ Timetable"]
        splash["✨ Splash"]
    end

    subgraph Backend["☁️ Backend"]
        supabase["Supabase DB"]
        firebase["Firebase Hosting"]
    end

    main --> app_router
    app_router --> Features
    Features --> Services
    Services --> supabase
    Core --> Features
    Core --> Services
```

---

## 📦 Feature Modules — Detailed Breakdown

```mermaid
graph LR
    subgraph Auth["🔐 Auth"]
        auth_login["login_screen.dart"]
    end

    subgraph Splash["✨ Splash"]
        splash_screen["splash_screen.dart"]
    end

    subgraph Dashboard["📊 Dashboards"]
        dash_main["dashboard_screen.dart"]
        dash_admin["admin_dashboard.dart<br/>39 KB"]
        dash_student["student_dashboard.dart<br/>85 KB ⚠️"]
        dash_teacher["teacher_dashboard.dart<br/>33 KB"]
        dash_hod["hod_dashboard.dart<br/>30 KB"]
        dash_hr["hr_dashboard.dart<br/>37 KB"]
    end

    subgraph Notices["📢 Notices"]
        notices_screen["notices_screen.dart"]
    end

    subgraph Timetable["🗓️ Timetable"]
        tt_screen["timetable_screen.dart"]
    end
```

---

### 🎓 Student Module (16 files)

```mermaid
graph TD
    subgraph Student["🎓 Student Feature"]
        s1["student_profile_screen.dart — 26 KB"]
        s2["student_assignments_screen.dart — 18 KB"]
        s3["student_events_screen.dart — 18 KB"]
        s4["student_study_materials_screen.dart — 15 KB"]
        s5["student_library.dart — 14 KB"]
        s6["student_marks_screen.dart — 13 KB"]
        s7["student_subjects_screen.dart — 13 KB"]
        s8["student_exam_schedule_screen.dart — 12 KB"]
        s9["student_announcements_screen.dart — 12 KB"]
        s10["student_timetable.dart — 12 KB"]
        s11["student_notice_screen.dart — 9 KB"]
        s12["coming_soon_screen.dart — 9 KB"]
        s13["student_attendance.dart"]
        s14["student_fees.dart"]
        s15["student_profile.dart"]
        s16["student_results.dart"]
    end
```

### 👨‍🏫 Teacher Module (12 files)

```mermaid
graph TD
    subgraph Teacher["👨‍🏫 Teacher Feature"]
        t1["class_detail_screen.dart — 27 KB"]
        t2["teacher_profile_screen.dart — 21 KB"]
        t3["teacher_events_screen.dart — 18 KB"]
        t4["upload_assignment_screen.dart — 16 KB"]
        t5["upload_marks_screen.dart — 16 KB"]
        t6["upload_study_material_screen.dart — 15 KB"]
        t7["make_announcement_screen.dart — 14 KB"]
        t8["check_submissions_screen.dart — 14 KB"]
        t9["teacher_payroll_screen.dart — 12 KB"]
        t10["class_options_screen.dart — 10 KB"]
        t11["assignment_management_screen.dart — 8 KB"]
        t12["subject_classes_screen.dart — 8 KB"]
    end
```

### 👔 HOD Module (6 files)

```mermaid
graph TD
    subgraph HOD["👔 HOD Feature"]
        h1["edit_timetable_screen.dart — 30 KB"]
        h2["hod_events_screen.dart — 22 KB"]
        h3["arrangement_screen.dart — 18 KB"]
        h4["create_event_screen.dart — 17 KB"]
        h5["class_options_screen.dart — 14 KB"]
        h6["manage_classes_screen.dart — 6 KB"]
    end
```

### 🏠 Hostel Module (10 screens + 2 services)

```mermaid
graph TD
    subgraph Hostel["🏠 Hostel Feature"]
        direction TB
        subgraph Screens["Screens"]
            hs1["warden_room_screen.dart — 40 KB"]
            hs2["warden_student_directory.dart — 35 KB"]
            hs3["student_hostel_screen.dart — 26 KB"]
            hs4["warden_allocation_screen.dart — 25 KB"]
            hs5["incident_log_screen.dart — 25 KB"]
            hs6["gatepass_management.dart — 24 KB"]
            hs7["student_grievance_screen.dart — 23 KB"]
            hs8["warden_grievance_screen.dart — 22 KB"]
            hs9["night_attendance_screen.dart — 20 KB"]
            hs10["warden_dashboard.dart — 18 KB"]
        end
        subgraph HostelSvc["Services"]
            hsvc1["hostel_service.dart — 9 KB"]
            hsvc2["grievance_service.dart — 5 KB"]
        end
    end
```

### 📈 Leads Module (6 screens + 4 services + 3 models + 5 widgets)

```mermaid
graph TD
    subgraph Leads["📈 Lead Management"]
        subgraph LeadScreens["Screens"]
            ls1["dean_dashboard.dart — 61 KB ⚠️"]
            ls2["lead_detail_screen.dart — 49 KB ⚠️"]
            ls3["counsellor_dashboard.dart — 38 KB"]
            ls4["admission_form_view.dart — 21 KB"]
            ls5["counsellor_profile.dart — 20 KB"]
            ls6["lead_capture_screen.dart — 15 KB"]
        end
        subgraph LeadSvc["Services"]
            lsvc1["lead_service.dart — 24 KB"]
            lsvc2["counsellor_service.dart — 13 KB"]
            lsvc3["lead_analytics_service.dart — 13 KB"]
            lsvc4["admission_form_service.dart — 11 KB"]
        end
        subgraph LeadModels["Data Models"]
            lm1["lead_model.dart — 14 KB"]
            lm2["lead_status.dart — 7 KB"]
            lm3["counsellor_model.dart — 7 KB"]
        end
        subgraph LeadWidgets["Widgets"]
            lw1["analytics_charts.dart — 45 KB ⚠️"]
            lw2["lead_card.dart — 17 KB"]
            lw3["sla_alerts.dart — 14 KB"]
            lw4["activity_feed.dart — 10 KB"]
            lw5["lead_status_chip.dart — 6 KB"]
        end
    end
```

### 👥 HR Module (6 files)

```mermaid
graph TD
    subgraph HR["👥 HR Feature"]
        hr1["staff_profile_detail.dart — 49 KB ⚠️"]
        hr2["add_employee_screen.dart — 38 KB"]
        hr3["hr_payroll_management.dart — 32 KB"]
        hr4["staff_edit_screen.dart — 22 KB"]
        hr5["staff_management_screen.dart — 20 KB"]
        hr6["edit_salary_screen.dart — 16 KB"]
    end
```

### 🌴 Leave Module (4 files)

```mermaid
graph TD
    subgraph Leave["🌴 Leave Feature"]
        lv1["teacher_leave_apply.dart — 29 KB"]
        lv2["hr_holiday_controls.dart — 24 KB"]
        lv3["holiday_calendar.dart — 23 KB"]
        lv4["hr_leave_requests.dart — 20 KB"]
    end
```

### 📝 Admission Module (5 screens + 1 service)

```mermaid
graph TD
    subgraph Admission["📝 Admission Feature"]
        ad1["offer_letter_screen.dart — 30 KB"]
        ad2["temp_student_dashboard.dart — 14 KB"]
        ad3["dead_admissions_screen.dart — 8 KB"]
        ad4["hostel_management_screen.dart — 5 KB"]
        ad5["transport_management_screen.dart — 5 KB"]
        ad_svc["temp_admission_service.dart — 6 KB"]
    end
```

### 🚌 Transport Module (1 screen + 1 service)

```mermaid
graph TD
    subgraph Transport["🚌 Transport Feature"]
        tr1["transport_dashboard.dart — 17 KB"]
        tr_svc["transport_service.dart — 2 KB"]
    end
```

### 💰 Fees Module (3 files)

```mermaid
graph TD
    subgraph Fees["💰 Fees Feature"]
        f1["student_fees_screen.dart — 19 KB"]
        f2["payment_receipt_screen.dart — 8 KB"]
        f3["payment_history_screen.dart — 5 KB"]
    end
```

### 🛡️ Admin Module (3 files)

```mermaid
graph TD
    subgraph Admin["🛡️ Admin Feature"]
        a1["add_student_screen.dart — 21 KB"]
        a2["add_teacher_screen.dart — 17 KB"]
        a3["add_user_screen.dart — 5 KB"]
    end
```

---

## ⚙️ Core Infrastructure

```mermaid
graph TD
    subgraph CoreLayer["⚙️ Core"]
        subgraph Config["📋 Config"]
            cfg1["app_config.dart"]
            cfg2["performance_config.dart"]
        end

        subgraph Theme["🎨 Theme"]
            thm["app_theme.dart"]
        end

        subgraph Widgets["🧩 Shared Widgets"]
            w1["error_handler.dart"]
            w2["glass_card.dart"]
            w3["gradient_button.dart"]
        end

        subgraph Utils["🔧 Utils"]
            u1["connection_monitor.dart"]
            u2["pagination_helper.dart"]
            u3["query_optimizer.dart"]
            u4["realtime_manager.dart"]
            u5["resilient_api_client.dart"]
            u6["safe_api_helper.dart"]
        end

        subgraph Security["🔒 Security"]
            sec1["role_guard.dart"]
            sec2["input_validator.dart"]
            sec3["file_validator.dart"]
            sec4["secure_logger.dart"]
            sec5["table_whitelist.dart"]
            sec6["security_config.dart"]
            sec7["security.dart"]
        end
    end
```

---

## 🔧 Services Layer

```mermaid
graph LR
    subgraph Services["🔧 Services — 21 Files"]
        subgraph AuthGroup["Auth & Session"]
            s_auth["auth_service.dart — 17 KB"]
            s_session["session_service.dart — 2 KB"]
        end

        subgraph DataGroup["Data Services"]
            s_student["student_service.dart — 24 KB"]
            s_opt_student["optimized_student_service.dart — 19 KB"]
            s_comp_student["complete_student_service.dart — 10 KB"]
            s_teacher["teacher_service.dart — 14 KB"]
            s_opt_teacher["optimized_teacher_service.dart — 14 KB"]
            s_comp_teacher["complete_teacher_service.dart — 7 KB"]
            s_admin["admin_service.dart — 10 KB"]
            s_comp_admin["complete_admin_service.dart — 5 KB"]
        end

        subgraph ModuleGroup["Module Services"]
            s_hr["hr_service.dart — 13 KB"]
            s_leave["leave_service.dart — 13 KB"]
            s_fees["fees_service.dart — 6 KB"]
            s_events["events_service.dart — 6 KB"]
            s_timetable["timetable_service.dart — 5 KB"]
            s_arrangement["arrangement_service.dart — 8 KB"]
            s_pdf["staff_pdf_service.dart — 19 KB"]
        end

        subgraph InfraGroup["Infrastructure"]
            s_supabase["supabase_service.dart — 2 KB"]
            s_cache["cache_manager.dart — 8 KB"]
            s_ecache["enhanced_cache_manager.dart — 7 KB"]
            s_offline["offline_service.dart — 6 KB"]
        end
    end
```

---

## 🗄️ Database & Backend

```mermaid
graph TD
    subgraph DB["🗄️ Database Layer"]
        direction TB
        subgraph SQL["SQL Migrations — 25+ files"]
            sql1["supabase_lead_management_setup.sql — 27 KB"]
            sql2["create_marks_tables.sql — 21 KB"]
            sql3["COMPLETE_RESTORE.sql — 19 KB"]
            sql4["supabase_hod_setup.sql — 12 KB"]
            sql5["QUICK_LOGIN_FIX.sql — 11 KB"]
            sql6["supabase_leave_management_setup.sql — 9 KB"]
            sql7["+ 19 more SQL files..."]
        end

        subgraph Supabase["☁️ Supabase"]
            sup_db["PostgreSQL Database"]
            sup_auth["Auth / RLS"]
            sup_storage["Storage Buckets"]
        end

        subgraph Firebase["🔥 Firebase"]
            fb_host["Firebase Hosting"]
        end
    end

    SQL --> sup_db
```

---

## 📁 Full Directory Tree

```
erp/
├── 📄 main.dart                          ← Entry Point
├── 📂 core/
│   ├── 📂 config/
│   │   ├── app_config.dart
│   │   └── performance_config.dart
│   ├── 📂 theme/
│   │   └── app_theme.dart
│   ├── 📂 widgets/
│   │   ├── error_handler.dart
│   │   ├── glass_card.dart
│   │   └── gradient_button.dart
│   ├── 📂 utils/
│   │   ├── connection_monitor.dart
│   │   ├── pagination_helper.dart
│   │   ├── query_optimizer.dart
│   │   ├── realtime_manager.dart
│   │   ├── resilient_api_client.dart
│   │   └── safe_api_helper.dart
│   └── 📂 security/
│       ├── file_validator.dart
│       ├── input_validator.dart
│       ├── role_guard.dart
│       ├── secure_logger.dart
│       ├── security.dart
│       ├── security_config.dart
│       └── table_whitelist.dart
├── 📂 routes/
│   └── app_router.dart
├── 📂 services/                           ← 21 service files
│   ├── auth_service.dart
│   ├── admin_service.dart
│   ├── student_service.dart
│   ├── teacher_service.dart
│   ├── hr_service.dart
│   ├── leave_service.dart
│   ├── fees_service.dart
│   ├── events_service.dart
│   ├── timetable_service.dart
│   ├── arrangement_service.dart
│   ├── staff_pdf_service.dart
│   ├── supabase_service.dart
│   ├── session_service.dart
│   ├── cache_manager.dart
│   ├── enhanced_cache_manager.dart
│   ├── offline_service.dart
│   ├── optimized_student_service.dart
│   ├── optimized_teacher_service.dart
│   ├── complete_student_service.dart
│   ├── complete_teacher_service.dart
│   └── complete_admin_service.dart
├── 📂 debug/
│   ├── database_debug_screen.dart
│   └── storage_debug_screen.dart
└── 📂 features/                           ← 16 feature modules
    ├── 📂 auth/             → 1 screen
    ├── 📂 splash/           → 1 screen
    ├── 📂 dashboard/        → 6 dashboards
    ├── 📂 student/          → 16 screens
    ├── 📂 teacher/          → 12 screens
    ├── 📂 admin/            → 3 screens
    ├── 📂 hod/              → 6 screens
    ├── 📂 hostel/           → 10 screens, 2 services
    ├── 📂 transport/        → 1 screen, 1 service
    ├── 📂 admission/        → 5 screens, 1 service
    ├── 📂 leads/            → 6 screens, 4 services, 3 models, 5 widgets
    ├── 📂 leave/            → 4 screens
    ├── 📂 hr/               → 6 screens
    ├── 📂 fees/             → 3 screens
    ├── 📂 notices/          → 1 screen
    └── 📂 timetable/        → 1 screen
```

---

## 📈 Stats at a Glance

| Metric | Count |
|---|---|
| **Feature Modules** | 16 |
| **Total Dart Screen Files** | ~82 |
| **Service Files** | 21 (global) + 8 (feature-local) |
| **Data Model Files** | 3 |
| **Widget Files** | 8 (3 core + 5 leads) |
| **Security Files** | 7 |
| **SQL Migration Files** | 25+ |
| **Backend** | Supabase (DB + Auth + Storage) |
| **Hosting** | Firebase |

---

## ⚠️ Large Files (>30 KB) — Potential Refactoring Candidates

| File | Size | Module |
|---|---|---|
| `student_dashboard.dart` | **85 KB** | Dashboard |
| `dean_dashboard.dart` | **61 KB** | Leads |
| `staff_profile_detail_screen.dart` | **49 KB** | HR |
| `lead_detail_screen.dart` | **49 KB** | Leads |
| `analytics_charts.dart` | **45 KB** | Leads/Widgets |
| `warden_room_screen.dart` | **40 KB** | Hostel |
| `admin_dashboard.dart` | **39 KB** | Dashboard |
| `add_employee_screen.dart` | **38 KB** | HR |
| `counsellor_dashboard.dart` | **38 KB** | Leads |
| `hr_dashboard.dart` | **37 KB** | Dashboard |
| `warden_student_directory.dart` | **35 KB** | Hostel |
| `teacher_dashboard.dart` | **33 KB** | Dashboard |
| `hr_payroll_management.dart` | **32 KB** | HR |
| `offer_letter_screen.dart` | **30 KB** | Admission |
| `hod_dashboard.dart` | **30 KB** | Dashboard |
| `edit_timetable_screen.dart` | **30 KB** | HOD |

---

## 🔄 Dependency Flow

```mermaid
flowchart TB
    User["👤 User"] --> SplashScreen
    SplashScreen --> LoginScreen
    LoginScreen --> AuthService
    AuthService --> SupabaseService
    AuthService --> |"Role Check"| RoleGuard

    RoleGuard --> |admin| AdminDashboard
    RoleGuard --> |student| StudentDashboard
    RoleGuard --> |teacher| TeacherDashboard
    RoleGuard --> |hod| HODDashboard
    RoleGuard --> |hr| HRDashboard
    RoleGuard --> |warden| WardenDashboard
    RoleGuard --> |transport_officer| TransportDashboard
    RoleGuard --> |admission_dean| DeanDashboard
    RoleGuard --> |counsellor| CounsellorDashboard

    AdminDashboard --> AdminService
    StudentDashboard --> StudentService
    TeacherDashboard --> TeacherService
    HODDashboard --> ArrangementService
    HRDashboard --> HRService
    WardenDashboard --> HostelService
    TransportDashboard --> TransportService
    DeanDashboard --> LeadService
    CounsellorDashboard --> CounsellorService

    AdminService --> SupabaseService
    StudentService --> SupabaseService
    TeacherService --> SupabaseService
    HRService --> SupabaseService
    LeadService --> SupabaseService
    HostelService --> SupabaseService
    TransportService --> SupabaseService

    SupabaseService --> |"PostgreSQL"| Database["🗄️ Supabase DB"]

    style User fill:#4CAF50,color:white
    style Database fill:#3F51B5,color:white
    style RoleGuard fill:#FF9800,color:white
```
