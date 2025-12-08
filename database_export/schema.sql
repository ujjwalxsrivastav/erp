--
-- PostgreSQL database dump
--

\restrict cJl16R5fXdITw7iTyVTQpOdPemf3OFd9YYXPbxEWtlJ6XypMExTAo4KDZHSn0Qv

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: ensure_monthly_leave_balance(text, text, integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ensure_monthly_leave_balance(p_teacher_id text, p_employee_id text, p_month integer, p_year integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO teacher_leave_balance (teacher_id, employee_id, month, year)
  VALUES (p_teacher_id, p_employee_id, p_month, p_year)
  ON CONFLICT (teacher_id, month, year) DO NOTHING;
END;
$$;


ALTER FUNCTION public.ensure_monthly_leave_balance(p_teacher_id text, p_employee_id text, p_month integer, p_year integer) OWNER TO postgres;

--
-- Name: ensure_single_active_salary(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.ensure_single_active_salary() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.is_active = true THEN
    -- Deactivate all other active salaries for this employee
    UPDATE teacher_salary 
    SET is_active = false, effective_to = CURRENT_DATE
    WHERE employee_id = NEW.employee_id 
    AND is_active = true 
    AND salary_id != NEW.salary_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.ensure_single_active_salary() OWNER TO postgres;

--
-- Name: update_events_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_events_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_events_updated_at() OWNER TO postgres;

--
-- Name: update_leave_balance_on_approval(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_leave_balance_on_approval() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  leave_month INTEGER;
  leave_year INTEGER;
BEGIN
  -- Only update if status changed to Approved
  IF NEW.status = 'Approved' AND (OLD.status IS NULL OR OLD.status != 'Approved') THEN
    leave_month := EXTRACT(MONTH FROM NEW.start_date);
    leave_year := EXTRACT(YEAR FROM NEW.start_date);
    
    -- Ensure balance record exists
    PERFORM ensure_monthly_leave_balance(NEW.teacher_id, NEW.employee_id, leave_month, leave_year);
    
    -- Update used leaves
    UPDATE teacher_leave_balance
    SET sick_leaves_used = sick_leaves_used + NEW.total_days
    WHERE teacher_id = NEW.teacher_id
      AND month = leave_month
      AND year = leave_year;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_leave_balance_on_approval() OWNER TO postgres;

--
-- Name: update_leave_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_leave_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_leave_updated_at() OWNER TO postgres;

--
-- Name: update_salary_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_salary_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_salary_updated_at() OWNER TO postgres;

--
-- Name: update_student_fees_after_payment(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_student_fees_after_payment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Only update if payment is successful
    IF NEW.payment_status = 'success' THEN
        UPDATE student_fees
        SET 
            paid_amount = paid_amount + NEW.amount,
            pending_amount = total_fee - (paid_amount + NEW.amount),
            last_payment_date = NEW.payment_date,
            updated_at = CURRENT_TIMESTAMP
        WHERE student_id = NEW.student_id 
        AND academic_year = NEW.academic_year;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_student_fees_after_payment() OWNER TO postgres;

--
-- Name: update_teacher_updated_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_teacher_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_teacher_updated_at() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = TIMEZONE('utc'::text, NOW());
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: announcements; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.announcements (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    title text NOT NULL,
    message text NOT NULL,
    priority text DEFAULT 'Normal'::text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    year text NOT NULL,
    section text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.announcements OWNER TO postgres;

--
-- Name: assignment_submissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assignment_submissions (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    assignment_id text NOT NULL,
    student_id text NOT NULL,
    file_url text NOT NULL,
    submitted_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'submitted'::text,
    grade numeric,
    feedback text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.assignment_submissions OWNER TO postgres;

--
-- Name: assignments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.assignments (
    id integer NOT NULL,
    title text NOT NULL,
    description text,
    file_url text,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    due_date timestamp with time zone,
    created_at timestamp with time zone DEFAULT now(),
    year text,
    section text
);


ALTER TABLE public.assignments OWNER TO postgres;

--
-- Name: TABLE assignments; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.assignments IS 'Stores assignment details uploaded by teachers';


--
-- Name: assignments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.assignments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.assignments_id_seq OWNER TO postgres;

--
-- Name: assignments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.assignments_id_seq OWNED BY public.assignments.id;


--
-- Name: bus_fee_enrollment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.bus_fee_enrollment (
    student_id character varying(20) NOT NULL,
    bus_fee numeric(10,2) DEFAULT 20000.00 NOT NULL,
    enrolled_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.bus_fee_enrollment OWNER TO postgres;

--
-- Name: classes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.classes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    class_name character varying(50) NOT NULL,
    year integer NOT NULL,
    section character varying(1) NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT classes_section_check CHECK (((section)::text = ANY ((ARRAY['A'::character varying, 'B'::character varying])::text[]))),
    CONSTRAINT classes_year_check CHECK (((year >= 1) AND (year <= 4)))
);


ALTER TABLE public.classes OWNER TO postgres;

--
-- Name: subjects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.subjects (
    subject_id text NOT NULL,
    subject_name text NOT NULL,
    teacher_id text NOT NULL,
    department text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.subjects OWNER TO postgres;

--
-- Name: TABLE subjects; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.subjects IS 'Stores subject information with assigned teachers';


--
-- Name: teacher_details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teacher_details (
    teacher_id text NOT NULL,
    name text NOT NULL,
    employee_id text NOT NULL,
    subject text NOT NULL,
    department text NOT NULL,
    phone text,
    email text,
    qualification text,
    profile_photo_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    date_of_birth date,
    gender text,
    address text,
    city text,
    state text,
    pincode text,
    emergency_contact_name text,
    emergency_contact_number text,
    emergency_contact_relation text,
    designation text,
    date_of_joining date,
    employment_type text,
    reporting_to text,
    status text DEFAULT 'Active'::text,
    highest_qualification text,
    university text,
    passing_year integer,
    specialization text,
    total_experience_years integer,
    previous_employer_1 text,
    previous_role_1 text,
    previous_duration_1 text,
    previous_employer_2 text,
    previous_role_2 text,
    previous_duration_2 text,
    previous_employer_3 text,
    previous_role_3 text,
    previous_duration_3 text,
    aadhaar_url text,
    pan_url text,
    degree_certificate_url text,
    experience_letter_url text,
    offer_letter_url text,
    joining_letter_url text,
    resume_url text,
    aadhaar_number text,
    pan_number text,
    created_by text,
    updated_by text,
    CONSTRAINT teacher_details_employment_type_check CHECK ((employment_type = ANY (ARRAY['Permanent'::text, 'Contract'::text, 'Visiting'::text, 'Guest'::text]))),
    CONSTRAINT teacher_details_gender_check CHECK ((gender = ANY (ARRAY['Male'::text, 'Female'::text, 'Other'::text]))),
    CONSTRAINT teacher_details_status_check CHECK ((status = ANY (ARRAY['Active'::text, 'On Leave'::text, 'Resigned'::text, 'Terminated'::text, 'Retired'::text])))
);


ALTER TABLE public.teacher_details OWNER TO postgres;

--
-- Name: TABLE teacher_details; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.teacher_details IS 'Stores teacher profile information';


--
-- Name: timetable; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.timetable (
    id integer NOT NULL,
    day_of_week text NOT NULL,
    time_slot text NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    room_number text,
    created_at timestamp with time zone DEFAULT now(),
    class_id uuid,
    CONSTRAINT timetable_day_of_week_check CHECK ((day_of_week = ANY (ARRAY['Monday'::text, 'Tuesday'::text, 'Wednesday'::text, 'Thursday'::text, 'Friday'::text])))
);


ALTER TABLE public.timetable OWNER TO postgres;

--
-- Name: TABLE timetable; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.timetable IS 'Weekly timetable for all classes';


--
-- Name: class_timetable_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.class_timetable_view WITH (security_invoker='on') AS
 SELECT c.class_name,
    c.year,
    c.section,
    t.day_of_week,
    t.time_slot,
    t.start_time,
    t.end_time,
    s.subject_name,
    td.name AS teacher_name,
    t.room_number,
    t.id AS timetable_id,
    t.class_id
   FROM (((public.timetable t
     JOIN public.classes c ON ((t.class_id = c.id)))
     JOIN public.subjects s ON ((t.subject_id = s.subject_id)))
     JOIN public.teacher_details td ON ((t.teacher_id = td.teacher_id)))
  ORDER BY c.class_name,
        CASE t.day_of_week
            WHEN 'Monday'::text THEN 1
            WHEN 'Tuesday'::text THEN 2
            WHEN 'Wednesday'::text THEN 3
            WHEN 'Thursday'::text THEN 4
            WHEN 'Friday'::text THEN 5
            ELSE NULL::integer
        END, t.start_time;


ALTER VIEW public.class_timetable_view OWNER TO postgres;

--
-- Name: events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.events (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    title text NOT NULL,
    description text,
    event_type text NOT NULL,
    event_date date NOT NULL,
    start_time time without time zone,
    end_time time without time zone,
    location text,
    organizer text,
    target_audience text[] DEFAULT ARRAY['all'::text],
    status text DEFAULT 'upcoming'::text,
    created_by text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT events_event_type_check CHECK ((event_type = ANY (ARRAY['academic'::text, 'cultural'::text, 'sports'::text, 'workshop'::text, 'seminar'::text, 'other'::text]))),
    CONSTRAINT events_status_check CHECK ((status = ANY (ARRAY['upcoming'::text, 'ongoing'::text, 'completed'::text, 'cancelled'::text])))
);


ALTER TABLE public.events OWNER TO postgres;

--
-- Name: fee_payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fee_payments (
    payment_id character varying(50) NOT NULL,
    student_id character varying(20) NOT NULL,
    razorpay_order_id character varying(100),
    razorpay_payment_id character varying(100),
    razorpay_signature character varying(200),
    amount numeric(10,2) NOT NULL,
    fee_type character varying(50) NOT NULL,
    payment_status character varying(20) DEFAULT 'pending'::character varying,
    academic_year character varying(10) NOT NULL,
    payment_date timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.fee_payments OWNER TO postgres;

--
-- Name: fee_transactions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fee_transactions (
    transaction_id integer NOT NULL,
    student_id character varying(20) NOT NULL,
    amount numeric(10,2) NOT NULL,
    payment_method character varying(50) DEFAULT 'razorpay'::character varying,
    razorpay_order_id character varying(100),
    razorpay_payment_id character varying(100),
    razorpay_signature character varying(200),
    payment_status character varying(20) DEFAULT 'pending'::character varying,
    academic_year character varying(10) NOT NULL,
    payment_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.fee_transactions OWNER TO postgres;

--
-- Name: fee_transactions_transaction_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.fee_transactions_transaction_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.fee_transactions_transaction_id_seq OWNER TO postgres;

--
-- Name: fee_transactions_transaction_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.fee_transactions_transaction_id_seq OWNED BY public.fee_transactions.transaction_id;


--
-- Name: holidays; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.holidays (
    holiday_id integer NOT NULL,
    holiday_name text NOT NULL,
    holiday_date date NOT NULL,
    description text,
    holiday_type text DEFAULT 'National'::text,
    is_holiday boolean DEFAULT true,
    is_working_day boolean DEFAULT false,
    created_by text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT holidays_holiday_type_check CHECK ((holiday_type = ANY (ARRAY['National'::text, 'Religious'::text, 'College'::text, 'Custom'::text])))
);


ALTER TABLE public.holidays OWNER TO postgres;

--
-- Name: TABLE holidays; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.holidays IS 'Stores college holidays and working day overrides';


--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.holidays_holiday_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.holidays_holiday_id_seq OWNER TO postgres;

--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.holidays_holiday_id_seq OWNED BY public.holidays.holiday_id;


--
-- Name: hostel_fee_enrollment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.hostel_fee_enrollment (
    student_id character varying(20) NOT NULL,
    hostel_fee numeric(10,2) DEFAULT 100000.00 NOT NULL,
    enrolled_date timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.hostel_fee_enrollment OWNER TO postgres;

--
-- Name: marks; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks (
    id integer NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    exam_type text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) NOT NULL,
    teacher_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT marks_exam_type_check CHECK ((exam_type = ANY (ARRAY['Mid Term'::text, 'End Semester'::text, 'Quiz'::text, 'Assignment'::text])))
);


ALTER TABLE public.marks OWNER TO postgres;

--
-- Name: TABLE marks; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.marks IS 'Stores student marks for different exams';


--
-- Name: marks_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.marks_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.marks_id_seq OWNER TO postgres;

--
-- Name: marks_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.marks_id_seq OWNED BY public.marks.id;


--
-- Name: marks_year1_sectiona_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year1_sectiona_assignment (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year1_sectiona_assignment OWNER TO postgres;

--
-- Name: marks_year1_sectiona_endsem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year1_sectiona_endsem (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year1_sectiona_endsem OWNER TO postgres;

--
-- Name: marks_year1_sectiona_midterm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year1_sectiona_midterm (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year1_sectiona_midterm OWNER TO postgres;

--
-- Name: marks_year1_sectiona_quiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year1_sectiona_quiz (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year1_sectiona_quiz OWNER TO postgres;

--
-- Name: marks_year1_sectionb_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year1_sectionb_assignment (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year1_sectionb_assignment OWNER TO postgres;

--
-- Name: marks_year1_sectionb_endsem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year1_sectionb_endsem (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year1_sectionb_endsem OWNER TO postgres;

--
-- Name: marks_year1_sectionb_midterm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year1_sectionb_midterm (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year1_sectionb_midterm OWNER TO postgres;

--
-- Name: marks_year1_sectionb_quiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year1_sectionb_quiz (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year1_sectionb_quiz OWNER TO postgres;

--
-- Name: marks_year2_sectiona_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year2_sectiona_assignment (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year2_sectiona_assignment OWNER TO postgres;

--
-- Name: marks_year2_sectiona_endsem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year2_sectiona_endsem (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year2_sectiona_endsem OWNER TO postgres;

--
-- Name: marks_year2_sectiona_midterm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year2_sectiona_midterm (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year2_sectiona_midterm OWNER TO postgres;

--
-- Name: marks_year2_sectiona_quiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year2_sectiona_quiz (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year2_sectiona_quiz OWNER TO postgres;

--
-- Name: marks_year2_sectionb_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year2_sectionb_assignment (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year2_sectionb_assignment OWNER TO postgres;

--
-- Name: marks_year2_sectionb_endsem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year2_sectionb_endsem (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year2_sectionb_endsem OWNER TO postgres;

--
-- Name: marks_year2_sectionb_midterm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year2_sectionb_midterm (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year2_sectionb_midterm OWNER TO postgres;

--
-- Name: marks_year2_sectionb_quiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year2_sectionb_quiz (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year2_sectionb_quiz OWNER TO postgres;

--
-- Name: marks_year3_sectiona_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year3_sectiona_assignment (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year3_sectiona_assignment OWNER TO postgres;

--
-- Name: marks_year3_sectiona_endsem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year3_sectiona_endsem (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year3_sectiona_endsem OWNER TO postgres;

--
-- Name: marks_year3_sectiona_midterm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year3_sectiona_midterm (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year3_sectiona_midterm OWNER TO postgres;

--
-- Name: marks_year3_sectiona_quiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year3_sectiona_quiz (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year3_sectiona_quiz OWNER TO postgres;

--
-- Name: marks_year3_sectionb_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year3_sectionb_assignment (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year3_sectionb_assignment OWNER TO postgres;

--
-- Name: marks_year3_sectionb_endsem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year3_sectionb_endsem (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year3_sectionb_endsem OWNER TO postgres;

--
-- Name: marks_year3_sectionb_midterm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year3_sectionb_midterm (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year3_sectionb_midterm OWNER TO postgres;

--
-- Name: marks_year3_sectionb_quiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year3_sectionb_quiz (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year3_sectionb_quiz OWNER TO postgres;

--
-- Name: marks_year4_sectiona_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year4_sectiona_assignment (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year4_sectiona_assignment OWNER TO postgres;

--
-- Name: marks_year4_sectiona_endsem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year4_sectiona_endsem (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year4_sectiona_endsem OWNER TO postgres;

--
-- Name: marks_year4_sectiona_midterm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year4_sectiona_midterm (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year4_sectiona_midterm OWNER TO postgres;

--
-- Name: marks_year4_sectiona_quiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year4_sectiona_quiz (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year4_sectiona_quiz OWNER TO postgres;

--
-- Name: marks_year4_sectionb_assignment; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year4_sectionb_assignment (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year4_sectionb_assignment OWNER TO postgres;

--
-- Name: marks_year4_sectionb_endsem; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year4_sectionb_endsem (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year4_sectionb_endsem OWNER TO postgres;

--
-- Name: marks_year4_sectionb_midterm; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year4_sectionb_midterm (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year4_sectionb_midterm OWNER TO postgres;

--
-- Name: marks_year4_sectionb_quiz; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.marks_year4_sectionb_quiz (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    marks_obtained numeric(5,2) NOT NULL,
    total_marks numeric(5,2) DEFAULT 100 NOT NULL,
    percentage numeric(5,2) GENERATED ALWAYS AS (((marks_obtained / total_marks) * (100)::numeric)) STORED,
    grade text,
    remarks text,
    uploaded_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.marks_year4_sectionb_quiz OWNER TO postgres;

--
-- Name: student_details; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_details (
    student_id text NOT NULL,
    name text NOT NULL,
    father_name text NOT NULL,
    year integer NOT NULL,
    semester integer NOT NULL,
    department text DEFAULT 'CSE'::text NOT NULL,
    section text NOT NULL,
    profile_photo_url text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    class_id uuid,
    CONSTRAINT student_details_section_check CHECK ((section = ANY (ARRAY['A'::text, 'B'::text, 'C'::text]))),
    CONSTRAINT student_details_semester_check CHECK (((semester >= 1) AND (semester <= 8))),
    CONSTRAINT student_details_year_check CHECK (((year >= 1) AND (year <= 4)))
);


ALTER TABLE public.student_details OWNER TO postgres;

--
-- Name: student_fees; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_fees (
    student_id character varying(20) NOT NULL,
    base_fee numeric(10,2) DEFAULT 134000.00 NOT NULL,
    total_fee numeric(10,2) NOT NULL,
    paid_amount numeric(10,2) DEFAULT 0.00,
    pending_amount numeric(10,2) NOT NULL,
    academic_year character varying(10) DEFAULT '2024-25'::character varying NOT NULL,
    last_payment_date timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.student_fees OWNER TO postgres;

--
-- Name: student_subjects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.student_subjects (
    id integer NOT NULL,
    student_id text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.student_subjects OWNER TO postgres;

--
-- Name: TABLE student_subjects; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.student_subjects IS 'Maps students to subjects and teachers';


--
-- Name: student_subjects_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.student_subjects_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.student_subjects_id_seq OWNER TO postgres;

--
-- Name: student_subjects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.student_subjects_id_seq OWNED BY public.student_subjects.id;


--
-- Name: study_materials; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.study_materials (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    title text NOT NULL,
    description text,
    material_type text NOT NULL,
    subject_id text NOT NULL,
    teacher_id text NOT NULL,
    file_url text NOT NULL,
    year text NOT NULL,
    section text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.study_materials OWNER TO postgres;

--
-- Name: teacher_leave_balance; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teacher_leave_balance (
    balance_id integer NOT NULL,
    teacher_id text NOT NULL,
    employee_id text NOT NULL,
    month integer NOT NULL,
    year integer NOT NULL,
    sick_leaves_total integer DEFAULT 2,
    sick_leaves_used integer DEFAULT 0,
    sick_leaves_remaining integer GENERATED ALWAYS AS ((sick_leaves_total - sick_leaves_used)) STORED,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT teacher_leave_balance_month_check CHECK (((month >= 1) AND (month <= 12)))
);


ALTER TABLE public.teacher_leave_balance OWNER TO postgres;

--
-- Name: TABLE teacher_leave_balance; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.teacher_leave_balance IS 'Tracks monthly leave balance for teachers';


--
-- Name: teacher_leave_balance_balance_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.teacher_leave_balance_balance_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.teacher_leave_balance_balance_id_seq OWNER TO postgres;

--
-- Name: teacher_leave_balance_balance_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.teacher_leave_balance_balance_id_seq OWNED BY public.teacher_leave_balance.balance_id;


--
-- Name: teacher_leaves; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teacher_leaves (
    leave_id integer NOT NULL,
    teacher_id text NOT NULL,
    employee_id text NOT NULL,
    leave_type text DEFAULT 'Sick Leave'::text NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    total_days integer NOT NULL,
    reason text NOT NULL,
    document_url text,
    status text DEFAULT 'Pending'::text,
    approved_by text,
    approved_at timestamp with time zone,
    rejection_reason text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    deduction_amount numeric(10,2) DEFAULT 0.00,
    is_salary_deducted boolean DEFAULT false,
    CONSTRAINT teacher_leaves_leave_type_check CHECK ((leave_type = ANY (ARRAY['Sick Leave'::text, 'Casual Leave'::text, 'Emergency Leave'::text]))),
    CONSTRAINT teacher_leaves_status_check CHECK ((status = ANY (ARRAY['Pending'::text, 'Approved'::text, 'Rejected'::text])))
);


ALTER TABLE public.teacher_leaves OWNER TO postgres;

--
-- Name: TABLE teacher_leaves; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.teacher_leaves IS 'Stores teacher leave applications';


--
-- Name: teacher_leaves_leave_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.teacher_leaves_leave_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.teacher_leaves_leave_id_seq OWNER TO postgres;

--
-- Name: teacher_leaves_leave_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.teacher_leaves_leave_id_seq OWNED BY public.teacher_leaves.leave_id;


--
-- Name: teacher_salary; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teacher_salary (
    salary_id integer NOT NULL,
    employee_id text NOT NULL,
    basic_salary numeric(10,2) DEFAULT 0.00 NOT NULL,
    hra numeric(10,2) DEFAULT 0.00,
    travel_allowance numeric(10,2) DEFAULT 0.00,
    medical_allowance numeric(10,2) DEFAULT 0.00,
    special_allowance numeric(10,2) DEFAULT 0.00,
    other_allowances numeric(10,2) DEFAULT 0.00,
    provident_fund numeric(10,2) DEFAULT 0.00,
    professional_tax numeric(10,2) DEFAULT 0.00,
    income_tax numeric(10,2) DEFAULT 0.00,
    other_deductions numeric(10,2) DEFAULT 0.00,
    gross_salary numeric(10,2) GENERATED ALWAYS AS ((((((basic_salary + hra) + travel_allowance) + medical_allowance) + special_allowance) + other_allowances)) STORED,
    total_deductions numeric(10,2) GENERATED ALWAYS AS ((((provident_fund + professional_tax) + income_tax) + other_deductions)) STORED,
    net_salary numeric(10,2) GENERATED ALWAYS AS (((((((basic_salary + hra) + travel_allowance) + medical_allowance) + special_allowance) + other_allowances) - (((provident_fund + professional_tax) + income_tax) + other_deductions))) STORED,
    bank_name text,
    account_number text,
    ifsc_code text,
    branch_name text,
    payment_mode text DEFAULT 'Bank Transfer'::text,
    effective_from date DEFAULT CURRENT_DATE NOT NULL,
    effective_to date,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    created_by text,
    updated_by text,
    CONSTRAINT teacher_salary_payment_mode_check CHECK ((payment_mode = ANY (ARRAY['Bank Transfer'::text, 'Cheque'::text, 'Cash'::text, 'UPI'::text]))),
    CONSTRAINT valid_date_range CHECK (((effective_to IS NULL) OR (effective_to > effective_from)))
);


ALTER TABLE public.teacher_salary OWNER TO postgres;

--
-- Name: TABLE teacher_salary; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON TABLE public.teacher_salary IS 'Stores salary and payroll information for teachers/staff';


--
-- Name: teacher_monthly_payroll; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.teacher_monthly_payroll AS
 SELECT employee_id,
    basic_salary,
    hra,
    travel_allowance,
    medical_allowance,
    special_allowance,
    other_allowances,
    gross_salary,
    provident_fund,
    professional_tax,
    income_tax,
    other_deductions,
    total_deductions,
    net_salary AS base_net_salary,
    COALESCE(( SELECT sum(tl.deduction_amount) AS sum
           FROM public.teacher_leaves tl
          WHERE ((tl.employee_id = ts.employee_id) AND (tl.status = 'Approved'::text) AND (tl.is_salary_deducted = true) AND (EXTRACT(month FROM tl.start_date) = EXTRACT(month FROM CURRENT_DATE)) AND (EXTRACT(year FROM tl.start_date) = EXTRACT(year FROM CURRENT_DATE)))), (0)::numeric) AS current_month_leave_deductions,
    (net_salary - COALESCE(( SELECT sum(tl.deduction_amount) AS sum
           FROM public.teacher_leaves tl
          WHERE ((tl.employee_id = ts.employee_id) AND (tl.status = 'Approved'::text) AND (tl.is_salary_deducted = true) AND (EXTRACT(month FROM tl.start_date) = EXTRACT(month FROM CURRENT_DATE)) AND (EXTRACT(year FROM tl.start_date) = EXTRACT(year FROM CURRENT_DATE)))), (0)::numeric)) AS final_net_salary
   FROM public.teacher_salary ts
  WHERE (is_active = true);


ALTER VIEW public.teacher_monthly_payroll OWNER TO postgres;

--
-- Name: teacher_salary_salary_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.teacher_salary_salary_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.teacher_salary_salary_id_seq OWNER TO postgres;

--
-- Name: teacher_salary_salary_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.teacher_salary_salary_id_seq OWNED BY public.teacher_salary.salary_id;


--
-- Name: teacher_salary_summary; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.teacher_salary_summary AS
 SELECT ts.employee_id,
    td.name,
    td.designation,
    td.department,
    ts.basic_salary,
    ts.hra,
    ts.travel_allowance,
    ts.medical_allowance,
    ts.special_allowance,
    ts.other_allowances,
    ts.gross_salary,
    ts.provident_fund,
    ts.professional_tax,
    ts.income_tax,
    ts.other_deductions,
    ts.total_deductions,
    ts.net_salary,
    ts.bank_name,
    ts.account_number,
    ts.ifsc_code,
    ts.payment_mode,
    ts.effective_from,
    ts.is_active
   FROM (public.teacher_salary ts
     JOIN public.teacher_details td ON ((ts.employee_id = td.employee_id)))
  WHERE (ts.is_active = true);


ALTER VIEW public.teacher_salary_summary OWNER TO postgres;

--
-- Name: VIEW teacher_salary_summary; Type: COMMENT; Schema: public; Owner: postgres
--

COMMENT ON VIEW public.teacher_salary_summary IS 'Active salary details with teacher information';


--
-- Name: timetable_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.timetable_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.timetable_id_seq OWNER TO postgres;

--
-- Name: timetable_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.timetable_id_seq OWNED BY public.timetable.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    username text NOT NULL,
    password text NOT NULL,
    role text NOT NULL,
    CONSTRAINT users_role_check CHECK ((role = ANY (ARRAY['student'::text, 'teacher'::text, 'admin'::text, 'staff'::text, 'HR'::text, 'hod'::text])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: assignments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignments ALTER COLUMN id SET DEFAULT nextval('public.assignments_id_seq'::regclass);


--
-- Name: fee_transactions transaction_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fee_transactions ALTER COLUMN transaction_id SET DEFAULT nextval('public.fee_transactions_transaction_id_seq'::regclass);


--
-- Name: holidays holiday_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holidays ALTER COLUMN holiday_id SET DEFAULT nextval('public.holidays_holiday_id_seq'::regclass);


--
-- Name: marks id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks ALTER COLUMN id SET DEFAULT nextval('public.marks_id_seq'::regclass);


--
-- Name: student_subjects id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_subjects ALTER COLUMN id SET DEFAULT nextval('public.student_subjects_id_seq'::regclass);


--
-- Name: teacher_leave_balance balance_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_leave_balance ALTER COLUMN balance_id SET DEFAULT nextval('public.teacher_leave_balance_balance_id_seq'::regclass);


--
-- Name: teacher_leaves leave_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_leaves ALTER COLUMN leave_id SET DEFAULT nextval('public.teacher_leaves_leave_id_seq'::regclass);


--
-- Name: teacher_salary salary_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_salary ALTER COLUMN salary_id SET DEFAULT nextval('public.teacher_salary_salary_id_seq'::regclass);


--
-- Name: timetable id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timetable ALTER COLUMN id SET DEFAULT nextval('public.timetable_id_seq'::regclass);


--
-- Name: announcements announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.announcements
    ADD CONSTRAINT announcements_pkey PRIMARY KEY (id);


--
-- Name: assignment_submissions assignment_submissions_assignment_id_student_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignment_submissions
    ADD CONSTRAINT assignment_submissions_assignment_id_student_id_key UNIQUE (assignment_id, student_id);


--
-- Name: assignment_submissions assignment_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignment_submissions
    ADD CONSTRAINT assignment_submissions_pkey PRIMARY KEY (id);


--
-- Name: assignments assignments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT assignments_pkey PRIMARY KEY (id);


--
-- Name: bus_fee_enrollment bus_fee_enrollment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.bus_fee_enrollment
    ADD CONSTRAINT bus_fee_enrollment_pkey PRIMARY KEY (student_id);


--
-- Name: classes classes_class_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_class_name_key UNIQUE (class_name);


--
-- Name: classes classes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_pkey PRIMARY KEY (id);


--
-- Name: classes classes_year_section_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.classes
    ADD CONSTRAINT classes_year_section_key UNIQUE (year, section);


--
-- Name: events events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_pkey PRIMARY KEY (id);


--
-- Name: fee_payments fee_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fee_payments
    ADD CONSTRAINT fee_payments_pkey PRIMARY KEY (payment_id);


--
-- Name: fee_transactions fee_transactions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fee_transactions
    ADD CONSTRAINT fee_transactions_pkey PRIMARY KEY (transaction_id);


--
-- Name: holidays holidays_holiday_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holidays
    ADD CONSTRAINT holidays_holiday_date_key UNIQUE (holiday_date);


--
-- Name: holidays holidays_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.holidays
    ADD CONSTRAINT holidays_pkey PRIMARY KEY (holiday_id);


--
-- Name: hostel_fee_enrollment hostel_fee_enrollment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.hostel_fee_enrollment
    ADD CONSTRAINT hostel_fee_enrollment_pkey PRIMARY KEY (student_id);


--
-- Name: marks marks_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks
    ADD CONSTRAINT marks_pkey PRIMARY KEY (id);


--
-- Name: marks marks_student_id_subject_id_exam_type_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks
    ADD CONSTRAINT marks_student_id_subject_id_exam_type_key UNIQUE (student_id, subject_id, exam_type);


--
-- Name: marks_year1_sectiona_assignment marks_year1_sectiona_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectiona_assignment
    ADD CONSTRAINT marks_year1_sectiona_assignment_pkey PRIMARY KEY (id);


--
-- Name: marks_year1_sectiona_assignment marks_year1_sectiona_assignment_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectiona_assignment
    ADD CONSTRAINT marks_year1_sectiona_assignment_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year1_sectiona_endsem marks_year1_sectiona_endsem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectiona_endsem
    ADD CONSTRAINT marks_year1_sectiona_endsem_pkey PRIMARY KEY (id);


--
-- Name: marks_year1_sectiona_endsem marks_year1_sectiona_endsem_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectiona_endsem
    ADD CONSTRAINT marks_year1_sectiona_endsem_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year1_sectiona_midterm marks_year1_sectiona_midterm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectiona_midterm
    ADD CONSTRAINT marks_year1_sectiona_midterm_pkey PRIMARY KEY (id);


--
-- Name: marks_year1_sectiona_midterm marks_year1_sectiona_midterm_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectiona_midterm
    ADD CONSTRAINT marks_year1_sectiona_midterm_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year1_sectiona_quiz marks_year1_sectiona_quiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectiona_quiz
    ADD CONSTRAINT marks_year1_sectiona_quiz_pkey PRIMARY KEY (id);


--
-- Name: marks_year1_sectiona_quiz marks_year1_sectiona_quiz_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectiona_quiz
    ADD CONSTRAINT marks_year1_sectiona_quiz_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year1_sectionb_assignment marks_year1_sectionb_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectionb_assignment
    ADD CONSTRAINT marks_year1_sectionb_assignment_pkey PRIMARY KEY (id);


--
-- Name: marks_year1_sectionb_assignment marks_year1_sectionb_assignment_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectionb_assignment
    ADD CONSTRAINT marks_year1_sectionb_assignment_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year1_sectionb_endsem marks_year1_sectionb_endsem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectionb_endsem
    ADD CONSTRAINT marks_year1_sectionb_endsem_pkey PRIMARY KEY (id);


--
-- Name: marks_year1_sectionb_endsem marks_year1_sectionb_endsem_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectionb_endsem
    ADD CONSTRAINT marks_year1_sectionb_endsem_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year1_sectionb_midterm marks_year1_sectionb_midterm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectionb_midterm
    ADD CONSTRAINT marks_year1_sectionb_midterm_pkey PRIMARY KEY (id);


--
-- Name: marks_year1_sectionb_midterm marks_year1_sectionb_midterm_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectionb_midterm
    ADD CONSTRAINT marks_year1_sectionb_midterm_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year1_sectionb_quiz marks_year1_sectionb_quiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectionb_quiz
    ADD CONSTRAINT marks_year1_sectionb_quiz_pkey PRIMARY KEY (id);


--
-- Name: marks_year1_sectionb_quiz marks_year1_sectionb_quiz_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year1_sectionb_quiz
    ADD CONSTRAINT marks_year1_sectionb_quiz_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year2_sectiona_assignment marks_year2_sectiona_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectiona_assignment
    ADD CONSTRAINT marks_year2_sectiona_assignment_pkey PRIMARY KEY (id);


--
-- Name: marks_year2_sectiona_assignment marks_year2_sectiona_assignment_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectiona_assignment
    ADD CONSTRAINT marks_year2_sectiona_assignment_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year2_sectiona_endsem marks_year2_sectiona_endsem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectiona_endsem
    ADD CONSTRAINT marks_year2_sectiona_endsem_pkey PRIMARY KEY (id);


--
-- Name: marks_year2_sectiona_endsem marks_year2_sectiona_endsem_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectiona_endsem
    ADD CONSTRAINT marks_year2_sectiona_endsem_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year2_sectiona_midterm marks_year2_sectiona_midterm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectiona_midterm
    ADD CONSTRAINT marks_year2_sectiona_midterm_pkey PRIMARY KEY (id);


--
-- Name: marks_year2_sectiona_midterm marks_year2_sectiona_midterm_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectiona_midterm
    ADD CONSTRAINT marks_year2_sectiona_midterm_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year2_sectiona_quiz marks_year2_sectiona_quiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectiona_quiz
    ADD CONSTRAINT marks_year2_sectiona_quiz_pkey PRIMARY KEY (id);


--
-- Name: marks_year2_sectiona_quiz marks_year2_sectiona_quiz_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectiona_quiz
    ADD CONSTRAINT marks_year2_sectiona_quiz_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year2_sectionb_assignment marks_year2_sectionb_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectionb_assignment
    ADD CONSTRAINT marks_year2_sectionb_assignment_pkey PRIMARY KEY (id);


--
-- Name: marks_year2_sectionb_assignment marks_year2_sectionb_assignment_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectionb_assignment
    ADD CONSTRAINT marks_year2_sectionb_assignment_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year2_sectionb_endsem marks_year2_sectionb_endsem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectionb_endsem
    ADD CONSTRAINT marks_year2_sectionb_endsem_pkey PRIMARY KEY (id);


--
-- Name: marks_year2_sectionb_endsem marks_year2_sectionb_endsem_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectionb_endsem
    ADD CONSTRAINT marks_year2_sectionb_endsem_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year2_sectionb_midterm marks_year2_sectionb_midterm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectionb_midterm
    ADD CONSTRAINT marks_year2_sectionb_midterm_pkey PRIMARY KEY (id);


--
-- Name: marks_year2_sectionb_midterm marks_year2_sectionb_midterm_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectionb_midterm
    ADD CONSTRAINT marks_year2_sectionb_midterm_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year2_sectionb_quiz marks_year2_sectionb_quiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectionb_quiz
    ADD CONSTRAINT marks_year2_sectionb_quiz_pkey PRIMARY KEY (id);


--
-- Name: marks_year2_sectionb_quiz marks_year2_sectionb_quiz_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year2_sectionb_quiz
    ADD CONSTRAINT marks_year2_sectionb_quiz_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year3_sectiona_assignment marks_year3_sectiona_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectiona_assignment
    ADD CONSTRAINT marks_year3_sectiona_assignment_pkey PRIMARY KEY (id);


--
-- Name: marks_year3_sectiona_assignment marks_year3_sectiona_assignment_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectiona_assignment
    ADD CONSTRAINT marks_year3_sectiona_assignment_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year3_sectiona_endsem marks_year3_sectiona_endsem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectiona_endsem
    ADD CONSTRAINT marks_year3_sectiona_endsem_pkey PRIMARY KEY (id);


--
-- Name: marks_year3_sectiona_endsem marks_year3_sectiona_endsem_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectiona_endsem
    ADD CONSTRAINT marks_year3_sectiona_endsem_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year3_sectiona_midterm marks_year3_sectiona_midterm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectiona_midterm
    ADD CONSTRAINT marks_year3_sectiona_midterm_pkey PRIMARY KEY (id);


--
-- Name: marks_year3_sectiona_midterm marks_year3_sectiona_midterm_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectiona_midterm
    ADD CONSTRAINT marks_year3_sectiona_midterm_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year3_sectiona_quiz marks_year3_sectiona_quiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectiona_quiz
    ADD CONSTRAINT marks_year3_sectiona_quiz_pkey PRIMARY KEY (id);


--
-- Name: marks_year3_sectiona_quiz marks_year3_sectiona_quiz_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectiona_quiz
    ADD CONSTRAINT marks_year3_sectiona_quiz_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year3_sectionb_assignment marks_year3_sectionb_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectionb_assignment
    ADD CONSTRAINT marks_year3_sectionb_assignment_pkey PRIMARY KEY (id);


--
-- Name: marks_year3_sectionb_assignment marks_year3_sectionb_assignment_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectionb_assignment
    ADD CONSTRAINT marks_year3_sectionb_assignment_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year3_sectionb_endsem marks_year3_sectionb_endsem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectionb_endsem
    ADD CONSTRAINT marks_year3_sectionb_endsem_pkey PRIMARY KEY (id);


--
-- Name: marks_year3_sectionb_endsem marks_year3_sectionb_endsem_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectionb_endsem
    ADD CONSTRAINT marks_year3_sectionb_endsem_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year3_sectionb_midterm marks_year3_sectionb_midterm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectionb_midterm
    ADD CONSTRAINT marks_year3_sectionb_midterm_pkey PRIMARY KEY (id);


--
-- Name: marks_year3_sectionb_midterm marks_year3_sectionb_midterm_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectionb_midterm
    ADD CONSTRAINT marks_year3_sectionb_midterm_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year3_sectionb_quiz marks_year3_sectionb_quiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectionb_quiz
    ADD CONSTRAINT marks_year3_sectionb_quiz_pkey PRIMARY KEY (id);


--
-- Name: marks_year3_sectionb_quiz marks_year3_sectionb_quiz_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year3_sectionb_quiz
    ADD CONSTRAINT marks_year3_sectionb_quiz_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year4_sectiona_assignment marks_year4_sectiona_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectiona_assignment
    ADD CONSTRAINT marks_year4_sectiona_assignment_pkey PRIMARY KEY (id);


--
-- Name: marks_year4_sectiona_assignment marks_year4_sectiona_assignment_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectiona_assignment
    ADD CONSTRAINT marks_year4_sectiona_assignment_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year4_sectiona_endsem marks_year4_sectiona_endsem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectiona_endsem
    ADD CONSTRAINT marks_year4_sectiona_endsem_pkey PRIMARY KEY (id);


--
-- Name: marks_year4_sectiona_endsem marks_year4_sectiona_endsem_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectiona_endsem
    ADD CONSTRAINT marks_year4_sectiona_endsem_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year4_sectiona_midterm marks_year4_sectiona_midterm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectiona_midterm
    ADD CONSTRAINT marks_year4_sectiona_midterm_pkey PRIMARY KEY (id);


--
-- Name: marks_year4_sectiona_midterm marks_year4_sectiona_midterm_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectiona_midterm
    ADD CONSTRAINT marks_year4_sectiona_midterm_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year4_sectiona_quiz marks_year4_sectiona_quiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectiona_quiz
    ADD CONSTRAINT marks_year4_sectiona_quiz_pkey PRIMARY KEY (id);


--
-- Name: marks_year4_sectiona_quiz marks_year4_sectiona_quiz_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectiona_quiz
    ADD CONSTRAINT marks_year4_sectiona_quiz_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year4_sectionb_assignment marks_year4_sectionb_assignment_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectionb_assignment
    ADD CONSTRAINT marks_year4_sectionb_assignment_pkey PRIMARY KEY (id);


--
-- Name: marks_year4_sectionb_assignment marks_year4_sectionb_assignment_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectionb_assignment
    ADD CONSTRAINT marks_year4_sectionb_assignment_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year4_sectionb_endsem marks_year4_sectionb_endsem_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectionb_endsem
    ADD CONSTRAINT marks_year4_sectionb_endsem_pkey PRIMARY KEY (id);


--
-- Name: marks_year4_sectionb_endsem marks_year4_sectionb_endsem_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectionb_endsem
    ADD CONSTRAINT marks_year4_sectionb_endsem_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year4_sectionb_midterm marks_year4_sectionb_midterm_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectionb_midterm
    ADD CONSTRAINT marks_year4_sectionb_midterm_pkey PRIMARY KEY (id);


--
-- Name: marks_year4_sectionb_midterm marks_year4_sectionb_midterm_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectionb_midterm
    ADD CONSTRAINT marks_year4_sectionb_midterm_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: marks_year4_sectionb_quiz marks_year4_sectionb_quiz_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectionb_quiz
    ADD CONSTRAINT marks_year4_sectionb_quiz_pkey PRIMARY KEY (id);


--
-- Name: marks_year4_sectionb_quiz marks_year4_sectionb_quiz_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks_year4_sectionb_quiz
    ADD CONSTRAINT marks_year4_sectionb_quiz_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: student_details student_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_details
    ADD CONSTRAINT student_details_pkey PRIMARY KEY (student_id);


--
-- Name: student_fees student_fees_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_fees
    ADD CONSTRAINT student_fees_pkey PRIMARY KEY (student_id);


--
-- Name: student_subjects student_subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_subjects
    ADD CONSTRAINT student_subjects_pkey PRIMARY KEY (id);


--
-- Name: student_subjects student_subjects_student_id_subject_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_subjects
    ADD CONSTRAINT student_subjects_student_id_subject_id_key UNIQUE (student_id, subject_id);


--
-- Name: study_materials study_materials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.study_materials
    ADD CONSTRAINT study_materials_pkey PRIMARY KEY (id);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (subject_id);


--
-- Name: teacher_details teacher_details_employee_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_details
    ADD CONSTRAINT teacher_details_employee_id_key UNIQUE (employee_id);


--
-- Name: teacher_details teacher_details_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_details
    ADD CONSTRAINT teacher_details_pkey PRIMARY KEY (teacher_id);


--
-- Name: teacher_leave_balance teacher_leave_balance_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_leave_balance
    ADD CONSTRAINT teacher_leave_balance_pkey PRIMARY KEY (balance_id);


--
-- Name: teacher_leave_balance teacher_leave_balance_teacher_id_month_year_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_leave_balance
    ADD CONSTRAINT teacher_leave_balance_teacher_id_month_year_key UNIQUE (teacher_id, month, year);


--
-- Name: teacher_leaves teacher_leaves_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_leaves
    ADD CONSTRAINT teacher_leaves_pkey PRIMARY KEY (leave_id);


--
-- Name: teacher_salary teacher_salary_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_salary
    ADD CONSTRAINT teacher_salary_pkey PRIMARY KEY (salary_id);


--
-- Name: timetable timetable_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_pkey PRIMARY KEY (id);


--
-- Name: timetable timetable_unique_slot; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_unique_slot UNIQUE (class_id, day_of_week, time_slot);


--
-- Name: teacher_salary unique_active_salary; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_salary
    ADD CONSTRAINT unique_active_salary UNIQUE (employee_id, is_active);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (username);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_announcements_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_announcements_created ON public.announcements USING btree (created_at DESC);


--
-- Name: idx_announcements_priority; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_announcements_priority ON public.announcements USING btree (priority);


--
-- Name: idx_announcements_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_announcements_subject ON public.announcements USING btree (subject_id);


--
-- Name: idx_announcements_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_announcements_teacher ON public.announcements USING btree (teacher_id);


--
-- Name: idx_announcements_year_section; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_announcements_year_section ON public.announcements USING btree (year, section);


--
-- Name: idx_balance_month; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_balance_month ON public.teacher_leave_balance USING btree (month, year);


--
-- Name: idx_balance_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_balance_teacher ON public.teacher_leave_balance USING btree (teacher_id);


--
-- Name: idx_events_created_by; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_created_by ON public.events USING btree (created_by);


--
-- Name: idx_events_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_date ON public.events USING btree (event_date);


--
-- Name: idx_events_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_events_status ON public.events USING btree (status);


--
-- Name: idx_holidays_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_holidays_date ON public.holidays USING btree (holiday_date);


--
-- Name: idx_leaves_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_leaves_date ON public.teacher_leaves USING btree (start_date, end_date);


--
-- Name: idx_leaves_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_leaves_status ON public.teacher_leaves USING btree (status);


--
-- Name: idx_leaves_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_leaves_teacher ON public.teacher_leaves USING btree (teacher_id);


--
-- Name: idx_marks_year1_sectiona_assignment_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_assignment_student ON public.marks_year1_sectiona_assignment USING btree (student_id);


--
-- Name: idx_marks_year1_sectiona_assignment_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_assignment_subject ON public.marks_year1_sectiona_assignment USING btree (subject_id);


--
-- Name: idx_marks_year1_sectiona_assignment_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_assignment_teacher ON public.marks_year1_sectiona_assignment USING btree (teacher_id);


--
-- Name: idx_marks_year1_sectiona_endsem_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_endsem_student ON public.marks_year1_sectiona_endsem USING btree (student_id);


--
-- Name: idx_marks_year1_sectiona_endsem_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_endsem_subject ON public.marks_year1_sectiona_endsem USING btree (subject_id);


--
-- Name: idx_marks_year1_sectiona_endsem_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_endsem_teacher ON public.marks_year1_sectiona_endsem USING btree (teacher_id);


--
-- Name: idx_marks_year1_sectiona_midterm_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_midterm_student ON public.marks_year1_sectiona_midterm USING btree (student_id);


--
-- Name: idx_marks_year1_sectiona_midterm_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_midterm_subject ON public.marks_year1_sectiona_midterm USING btree (subject_id);


--
-- Name: idx_marks_year1_sectiona_midterm_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_midterm_teacher ON public.marks_year1_sectiona_midterm USING btree (teacher_id);


--
-- Name: idx_marks_year1_sectiona_quiz_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_quiz_student ON public.marks_year1_sectiona_quiz USING btree (student_id);


--
-- Name: idx_marks_year1_sectiona_quiz_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_quiz_subject ON public.marks_year1_sectiona_quiz USING btree (subject_id);


--
-- Name: idx_marks_year1_sectiona_quiz_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectiona_quiz_teacher ON public.marks_year1_sectiona_quiz USING btree (teacher_id);


--
-- Name: idx_marks_year1_sectionb_assignment_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_assignment_student ON public.marks_year1_sectionb_assignment USING btree (student_id);


--
-- Name: idx_marks_year1_sectionb_assignment_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_assignment_subject ON public.marks_year1_sectionb_assignment USING btree (subject_id);


--
-- Name: idx_marks_year1_sectionb_assignment_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_assignment_teacher ON public.marks_year1_sectionb_assignment USING btree (teacher_id);


--
-- Name: idx_marks_year1_sectionb_endsem_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_endsem_student ON public.marks_year1_sectionb_endsem USING btree (student_id);


--
-- Name: idx_marks_year1_sectionb_endsem_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_endsem_subject ON public.marks_year1_sectionb_endsem USING btree (subject_id);


--
-- Name: idx_marks_year1_sectionb_endsem_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_endsem_teacher ON public.marks_year1_sectionb_endsem USING btree (teacher_id);


--
-- Name: idx_marks_year1_sectionb_midterm_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_midterm_student ON public.marks_year1_sectionb_midterm USING btree (student_id);


--
-- Name: idx_marks_year1_sectionb_midterm_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_midterm_subject ON public.marks_year1_sectionb_midterm USING btree (subject_id);


--
-- Name: idx_marks_year1_sectionb_midterm_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_midterm_teacher ON public.marks_year1_sectionb_midterm USING btree (teacher_id);


--
-- Name: idx_marks_year1_sectionb_quiz_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_quiz_student ON public.marks_year1_sectionb_quiz USING btree (student_id);


--
-- Name: idx_marks_year1_sectionb_quiz_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_quiz_subject ON public.marks_year1_sectionb_quiz USING btree (subject_id);


--
-- Name: idx_marks_year1_sectionb_quiz_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year1_sectionb_quiz_teacher ON public.marks_year1_sectionb_quiz USING btree (teacher_id);


--
-- Name: idx_marks_year2_sectiona_assignment_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_assignment_student ON public.marks_year2_sectiona_assignment USING btree (student_id);


--
-- Name: idx_marks_year2_sectiona_assignment_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_assignment_subject ON public.marks_year2_sectiona_assignment USING btree (subject_id);


--
-- Name: idx_marks_year2_sectiona_assignment_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_assignment_teacher ON public.marks_year2_sectiona_assignment USING btree (teacher_id);


--
-- Name: idx_marks_year2_sectiona_endsem_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_endsem_student ON public.marks_year2_sectiona_endsem USING btree (student_id);


--
-- Name: idx_marks_year2_sectiona_endsem_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_endsem_subject ON public.marks_year2_sectiona_endsem USING btree (subject_id);


--
-- Name: idx_marks_year2_sectiona_endsem_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_endsem_teacher ON public.marks_year2_sectiona_endsem USING btree (teacher_id);


--
-- Name: idx_marks_year2_sectiona_midterm_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_midterm_student ON public.marks_year2_sectiona_midterm USING btree (student_id);


--
-- Name: idx_marks_year2_sectiona_midterm_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_midterm_subject ON public.marks_year2_sectiona_midterm USING btree (subject_id);


--
-- Name: idx_marks_year2_sectiona_midterm_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_midterm_teacher ON public.marks_year2_sectiona_midterm USING btree (teacher_id);


--
-- Name: idx_marks_year2_sectiona_quiz_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_quiz_student ON public.marks_year2_sectiona_quiz USING btree (student_id);


--
-- Name: idx_marks_year2_sectiona_quiz_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_quiz_subject ON public.marks_year2_sectiona_quiz USING btree (subject_id);


--
-- Name: idx_marks_year2_sectiona_quiz_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectiona_quiz_teacher ON public.marks_year2_sectiona_quiz USING btree (teacher_id);


--
-- Name: idx_marks_year2_sectionb_assignment_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_assignment_student ON public.marks_year2_sectionb_assignment USING btree (student_id);


--
-- Name: idx_marks_year2_sectionb_assignment_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_assignment_subject ON public.marks_year2_sectionb_assignment USING btree (subject_id);


--
-- Name: idx_marks_year2_sectionb_assignment_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_assignment_teacher ON public.marks_year2_sectionb_assignment USING btree (teacher_id);


--
-- Name: idx_marks_year2_sectionb_endsem_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_endsem_student ON public.marks_year2_sectionb_endsem USING btree (student_id);


--
-- Name: idx_marks_year2_sectionb_endsem_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_endsem_subject ON public.marks_year2_sectionb_endsem USING btree (subject_id);


--
-- Name: idx_marks_year2_sectionb_endsem_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_endsem_teacher ON public.marks_year2_sectionb_endsem USING btree (teacher_id);


--
-- Name: idx_marks_year2_sectionb_midterm_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_midterm_student ON public.marks_year2_sectionb_midterm USING btree (student_id);


--
-- Name: idx_marks_year2_sectionb_midterm_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_midterm_subject ON public.marks_year2_sectionb_midterm USING btree (subject_id);


--
-- Name: idx_marks_year2_sectionb_midterm_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_midterm_teacher ON public.marks_year2_sectionb_midterm USING btree (teacher_id);


--
-- Name: idx_marks_year2_sectionb_quiz_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_quiz_student ON public.marks_year2_sectionb_quiz USING btree (student_id);


--
-- Name: idx_marks_year2_sectionb_quiz_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_quiz_subject ON public.marks_year2_sectionb_quiz USING btree (subject_id);


--
-- Name: idx_marks_year2_sectionb_quiz_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year2_sectionb_quiz_teacher ON public.marks_year2_sectionb_quiz USING btree (teacher_id);


--
-- Name: idx_marks_year3_sectiona_assignment_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_assignment_student ON public.marks_year3_sectiona_assignment USING btree (student_id);


--
-- Name: idx_marks_year3_sectiona_assignment_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_assignment_subject ON public.marks_year3_sectiona_assignment USING btree (subject_id);


--
-- Name: idx_marks_year3_sectiona_assignment_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_assignment_teacher ON public.marks_year3_sectiona_assignment USING btree (teacher_id);


--
-- Name: idx_marks_year3_sectiona_endsem_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_endsem_student ON public.marks_year3_sectiona_endsem USING btree (student_id);


--
-- Name: idx_marks_year3_sectiona_endsem_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_endsem_subject ON public.marks_year3_sectiona_endsem USING btree (subject_id);


--
-- Name: idx_marks_year3_sectiona_endsem_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_endsem_teacher ON public.marks_year3_sectiona_endsem USING btree (teacher_id);


--
-- Name: idx_marks_year3_sectiona_midterm_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_midterm_student ON public.marks_year3_sectiona_midterm USING btree (student_id);


--
-- Name: idx_marks_year3_sectiona_midterm_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_midterm_subject ON public.marks_year3_sectiona_midterm USING btree (subject_id);


--
-- Name: idx_marks_year3_sectiona_midterm_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_midterm_teacher ON public.marks_year3_sectiona_midterm USING btree (teacher_id);


--
-- Name: idx_marks_year3_sectiona_quiz_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_quiz_student ON public.marks_year3_sectiona_quiz USING btree (student_id);


--
-- Name: idx_marks_year3_sectiona_quiz_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_quiz_subject ON public.marks_year3_sectiona_quiz USING btree (subject_id);


--
-- Name: idx_marks_year3_sectiona_quiz_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectiona_quiz_teacher ON public.marks_year3_sectiona_quiz USING btree (teacher_id);


--
-- Name: idx_marks_year3_sectionb_assignment_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_assignment_student ON public.marks_year3_sectionb_assignment USING btree (student_id);


--
-- Name: idx_marks_year3_sectionb_assignment_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_assignment_subject ON public.marks_year3_sectionb_assignment USING btree (subject_id);


--
-- Name: idx_marks_year3_sectionb_assignment_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_assignment_teacher ON public.marks_year3_sectionb_assignment USING btree (teacher_id);


--
-- Name: idx_marks_year3_sectionb_endsem_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_endsem_student ON public.marks_year3_sectionb_endsem USING btree (student_id);


--
-- Name: idx_marks_year3_sectionb_endsem_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_endsem_subject ON public.marks_year3_sectionb_endsem USING btree (subject_id);


--
-- Name: idx_marks_year3_sectionb_endsem_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_endsem_teacher ON public.marks_year3_sectionb_endsem USING btree (teacher_id);


--
-- Name: idx_marks_year3_sectionb_midterm_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_midterm_student ON public.marks_year3_sectionb_midterm USING btree (student_id);


--
-- Name: idx_marks_year3_sectionb_midterm_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_midterm_subject ON public.marks_year3_sectionb_midterm USING btree (subject_id);


--
-- Name: idx_marks_year3_sectionb_midterm_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_midterm_teacher ON public.marks_year3_sectionb_midterm USING btree (teacher_id);


--
-- Name: idx_marks_year3_sectionb_quiz_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_quiz_student ON public.marks_year3_sectionb_quiz USING btree (student_id);


--
-- Name: idx_marks_year3_sectionb_quiz_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_quiz_subject ON public.marks_year3_sectionb_quiz USING btree (subject_id);


--
-- Name: idx_marks_year3_sectionb_quiz_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year3_sectionb_quiz_teacher ON public.marks_year3_sectionb_quiz USING btree (teacher_id);


--
-- Name: idx_marks_year4_sectiona_assignment_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_assignment_student ON public.marks_year4_sectiona_assignment USING btree (student_id);


--
-- Name: idx_marks_year4_sectiona_assignment_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_assignment_subject ON public.marks_year4_sectiona_assignment USING btree (subject_id);


--
-- Name: idx_marks_year4_sectiona_assignment_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_assignment_teacher ON public.marks_year4_sectiona_assignment USING btree (teacher_id);


--
-- Name: idx_marks_year4_sectiona_endsem_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_endsem_student ON public.marks_year4_sectiona_endsem USING btree (student_id);


--
-- Name: idx_marks_year4_sectiona_endsem_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_endsem_subject ON public.marks_year4_sectiona_endsem USING btree (subject_id);


--
-- Name: idx_marks_year4_sectiona_endsem_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_endsem_teacher ON public.marks_year4_sectiona_endsem USING btree (teacher_id);


--
-- Name: idx_marks_year4_sectiona_midterm_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_midterm_student ON public.marks_year4_sectiona_midterm USING btree (student_id);


--
-- Name: idx_marks_year4_sectiona_midterm_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_midterm_subject ON public.marks_year4_sectiona_midterm USING btree (subject_id);


--
-- Name: idx_marks_year4_sectiona_midterm_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_midterm_teacher ON public.marks_year4_sectiona_midterm USING btree (teacher_id);


--
-- Name: idx_marks_year4_sectiona_quiz_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_quiz_student ON public.marks_year4_sectiona_quiz USING btree (student_id);


--
-- Name: idx_marks_year4_sectiona_quiz_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_quiz_subject ON public.marks_year4_sectiona_quiz USING btree (subject_id);


--
-- Name: idx_marks_year4_sectiona_quiz_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectiona_quiz_teacher ON public.marks_year4_sectiona_quiz USING btree (teacher_id);


--
-- Name: idx_marks_year4_sectionb_assignment_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_assignment_student ON public.marks_year4_sectionb_assignment USING btree (student_id);


--
-- Name: idx_marks_year4_sectionb_assignment_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_assignment_subject ON public.marks_year4_sectionb_assignment USING btree (subject_id);


--
-- Name: idx_marks_year4_sectionb_assignment_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_assignment_teacher ON public.marks_year4_sectionb_assignment USING btree (teacher_id);


--
-- Name: idx_marks_year4_sectionb_endsem_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_endsem_student ON public.marks_year4_sectionb_endsem USING btree (student_id);


--
-- Name: idx_marks_year4_sectionb_endsem_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_endsem_subject ON public.marks_year4_sectionb_endsem USING btree (subject_id);


--
-- Name: idx_marks_year4_sectionb_endsem_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_endsem_teacher ON public.marks_year4_sectionb_endsem USING btree (teacher_id);


--
-- Name: idx_marks_year4_sectionb_midterm_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_midterm_student ON public.marks_year4_sectionb_midterm USING btree (student_id);


--
-- Name: idx_marks_year4_sectionb_midterm_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_midterm_subject ON public.marks_year4_sectionb_midterm USING btree (subject_id);


--
-- Name: idx_marks_year4_sectionb_midterm_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_midterm_teacher ON public.marks_year4_sectionb_midterm USING btree (teacher_id);


--
-- Name: idx_marks_year4_sectionb_quiz_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_quiz_student ON public.marks_year4_sectionb_quiz USING btree (student_id);


--
-- Name: idx_marks_year4_sectionb_quiz_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_quiz_subject ON public.marks_year4_sectionb_quiz USING btree (subject_id);


--
-- Name: idx_marks_year4_sectionb_quiz_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_marks_year4_sectionb_quiz_teacher ON public.marks_year4_sectionb_quiz USING btree (teacher_id);


--
-- Name: idx_payment_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_payment_status ON public.fee_payments USING btree (payment_status);


--
-- Name: idx_salary_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_salary_active ON public.teacher_salary USING btree (is_active);


--
-- Name: idx_salary_effective_from; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_salary_effective_from ON public.teacher_salary USING btree (effective_from);


--
-- Name: idx_salary_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_salary_employee_id ON public.teacher_salary USING btree (employee_id);


--
-- Name: idx_student_details_class; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_student_details_class ON public.student_details USING btree (class_id);


--
-- Name: idx_student_fees_year; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_student_fees_year ON public.student_fees USING btree (academic_year);


--
-- Name: idx_student_payments; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_student_payments ON public.fee_payments USING btree (student_id, academic_year);


--
-- Name: idx_study_materials_created; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_study_materials_created ON public.study_materials USING btree (created_at DESC);


--
-- Name: idx_study_materials_subject; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_study_materials_subject ON public.study_materials USING btree (subject_id);


--
-- Name: idx_study_materials_teacher; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_study_materials_teacher ON public.study_materials USING btree (teacher_id);


--
-- Name: idx_study_materials_year_section; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_study_materials_year_section ON public.study_materials USING btree (year, section);


--
-- Name: idx_submissions_assignment; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_submissions_assignment ON public.assignment_submissions USING btree (assignment_id);


--
-- Name: idx_submissions_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_submissions_status ON public.assignment_submissions USING btree (status);


--
-- Name: idx_submissions_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_submissions_student ON public.assignment_submissions USING btree (student_id);


--
-- Name: idx_submissions_submitted_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_submissions_submitted_at ON public.assignment_submissions USING btree (submitted_at DESC);


--
-- Name: idx_teacher_department; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_teacher_department ON public.teacher_details USING btree (department);


--
-- Name: idx_teacher_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_teacher_email ON public.teacher_details USING btree (email);


--
-- Name: idx_teacher_employee_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_teacher_employee_id ON public.teacher_details USING btree (employee_id);


--
-- Name: idx_teacher_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_teacher_status ON public.teacher_details USING btree (status);


--
-- Name: idx_timetable_class; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_timetable_class ON public.timetable USING btree (class_id);


--
-- Name: idx_transactions_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_status ON public.fee_transactions USING btree (payment_status);


--
-- Name: idx_transactions_student; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_transactions_student ON public.fee_transactions USING btree (student_id, academic_year);


--
-- Name: teacher_salary ensure_single_active_salary_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER ensure_single_active_salary_trigger BEFORE INSERT OR UPDATE ON public.teacher_salary FOR EACH ROW EXECUTE FUNCTION public.ensure_single_active_salary();


--
-- Name: events events_updated_at_trigger; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER events_updated_at_trigger BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION public.update_events_updated_at();


--
-- Name: holidays holidays_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER holidays_updated_at BEFORE UPDATE ON public.holidays FOR EACH ROW EXECUTE FUNCTION public.update_leave_updated_at();


--
-- Name: teacher_details teacher_details_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER teacher_details_updated_at BEFORE UPDATE ON public.teacher_details FOR EACH ROW EXECUTE FUNCTION public.update_teacher_updated_at();


--
-- Name: teacher_leave_balance teacher_leave_balance_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER teacher_leave_balance_updated_at BEFORE UPDATE ON public.teacher_leave_balance FOR EACH ROW EXECUTE FUNCTION public.update_leave_updated_at();


--
-- Name: teacher_leaves teacher_leaves_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER teacher_leaves_updated_at BEFORE UPDATE ON public.teacher_leaves FOR EACH ROW EXECUTE FUNCTION public.update_leave_updated_at();


--
-- Name: teacher_salary teacher_salary_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER teacher_salary_updated_at BEFORE UPDATE ON public.teacher_salary FOR EACH ROW EXECUTE FUNCTION public.update_salary_updated_at();


--
-- Name: fee_transactions trigger_update_fees_after_payment; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trigger_update_fees_after_payment AFTER INSERT OR UPDATE ON public.fee_transactions FOR EACH ROW EXECUTE FUNCTION public.update_student_fees_after_payment();


--
-- Name: teacher_leaves update_balance_on_leave_approval; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_balance_on_leave_approval AFTER INSERT OR UPDATE ON public.teacher_leaves FOR EACH ROW EXECUTE FUNCTION public.update_leave_balance_on_approval();


--
-- Name: student_details update_student_details_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_student_details_updated_at BEFORE UPDATE ON public.student_details FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: assignments assignments_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT assignments_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(subject_id);


--
-- Name: assignments assignments_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.assignments
    ADD CONSTRAINT assignments_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher_details(teacher_id);


--
-- Name: events events_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.events
    ADD CONSTRAINT events_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(username);


--
-- Name: marks marks_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks
    ADD CONSTRAINT marks_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_details(student_id);


--
-- Name: marks marks_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks
    ADD CONSTRAINT marks_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(subject_id);


--
-- Name: marks marks_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.marks
    ADD CONSTRAINT marks_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher_details(teacher_id);


--
-- Name: student_details student_details_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_details
    ADD CONSTRAINT student_details_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id);


--
-- Name: student_details student_details_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_details
    ADD CONSTRAINT student_details_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(username) ON DELETE CASCADE;


--
-- Name: student_subjects student_subjects_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_subjects
    ADD CONSTRAINT student_subjects_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.student_details(student_id);


--
-- Name: student_subjects student_subjects_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_subjects
    ADD CONSTRAINT student_subjects_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(subject_id);


--
-- Name: student_subjects student_subjects_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.student_subjects
    ADD CONSTRAINT student_subjects_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher_details(teacher_id);


--
-- Name: subjects subjects_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher_details(teacher_id);


--
-- Name: teacher_leave_balance teacher_leave_balance_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_leave_balance
    ADD CONSTRAINT teacher_leave_balance_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.teacher_details(employee_id) ON DELETE CASCADE;


--
-- Name: teacher_leave_balance teacher_leave_balance_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_leave_balance
    ADD CONSTRAINT teacher_leave_balance_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher_details(teacher_id) ON DELETE CASCADE;


--
-- Name: teacher_leaves teacher_leaves_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_leaves
    ADD CONSTRAINT teacher_leaves_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.teacher_details(employee_id) ON DELETE CASCADE;


--
-- Name: teacher_leaves teacher_leaves_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_leaves
    ADD CONSTRAINT teacher_leaves_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher_details(teacher_id) ON DELETE CASCADE;


--
-- Name: teacher_salary teacher_salary_employee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_salary
    ADD CONSTRAINT teacher_salary_employee_id_fkey FOREIGN KEY (employee_id) REFERENCES public.teacher_details(employee_id) ON DELETE CASCADE;


--
-- Name: timetable timetable_class_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_class_id_fkey FOREIGN KEY (class_id) REFERENCES public.classes(id) ON DELETE CASCADE;


--
-- Name: timetable timetable_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(subject_id);


--
-- Name: timetable timetable_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.timetable
    ADD CONSTRAINT timetable_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.teacher_details(teacher_id);


--
-- Name: teacher_salary Allow HR and Admin to manage salaries; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow HR and Admin to manage salaries" ON public.teacher_salary TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.username = CURRENT_USER) AND (users.role = ANY (ARRAY['HR'::text, 'admin'::text]))))));


--
-- Name: teacher_salary Allow HR and Admin to view all salaries; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow HR and Admin to view all salaries" ON public.teacher_salary FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.username = CURRENT_USER) AND (users.role = ANY (ARRAY['HR'::text, 'admin'::text]))))));


--
-- Name: classes Allow read access to all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow read access to all users" ON public.classes FOR SELECT TO authenticated USING (true);


--
-- Name: student_details Allow read access to all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow read access to all users" ON public.student_details FOR SELECT USING (true);


--
-- Name: student_subjects Allow read access to all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow read access to all users" ON public.student_subjects FOR SELECT USING (true);


--
-- Name: subjects Allow read access to all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow read access to all users" ON public.subjects FOR SELECT USING (true);


--
-- Name: timetable Allow read access to all users; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow read access to all users" ON public.timetable FOR SELECT USING (true);


--
-- Name: users Allow select for login; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow select for login" ON public.users FOR SELECT USING (true);


--
-- Name: teacher_salary Allow teachers to view own salary; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow teachers to view own salary" ON public.teacher_salary FOR SELECT TO authenticated USING ((employee_id IN ( SELECT teacher_details.employee_id
   FROM public.teacher_details
  WHERE (teacher_details.teacher_id = CURRENT_USER))));


--
-- Name: events Events are viewable by everyone; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Events are viewable by everyone" ON public.events FOR SELECT USING (true);


--
-- Name: holidays Everyone can view holidays; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Everyone can view holidays" ON public.holidays FOR SELECT TO authenticated USING (true);


--
-- Name: classes HOD and Admin can manage classes; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "HOD and Admin can manage classes" ON public.classes TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((classes.id = auth.uid()) AND (users.role = ANY (ARRAY['admin'::text, 'hod'::text]))))));


--
-- Name: events HOD can delete their own events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "HOD can delete their own events" ON public.events FOR DELETE USING ((created_by IN ( SELECT users.username
   FROM public.users
  WHERE (users.role = 'hod'::text))));


--
-- Name: events HOD can insert events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "HOD can insert events" ON public.events FOR INSERT WITH CHECK ((created_by IN ( SELECT users.username
   FROM public.users
  WHERE (users.role = 'hod'::text))));


--
-- Name: events HOD can update their own events; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "HOD can update their own events" ON public.events FOR UPDATE USING ((created_by IN ( SELECT users.username
   FROM public.users
  WHERE (users.role = 'hod'::text))));


--
-- Name: holidays HR and Admin can manage holidays; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "HR and Admin can manage holidays" ON public.holidays TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.username = CURRENT_USER) AND (users.role = ANY (ARRAY['HR'::text, 'admin'::text]))))));


--
-- Name: teacher_leaves HR and Admin can update leaves; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "HR and Admin can update leaves" ON public.teacher_leaves FOR UPDATE TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.username = CURRENT_USER) AND (users.role = ANY (ARRAY['HR'::text, 'admin'::text]))))));


--
-- Name: teacher_leave_balance HR and Admin can view all balances; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "HR and Admin can view all balances" ON public.teacher_leave_balance FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.username = CURRENT_USER) AND (users.role = ANY (ARRAY['HR'::text, 'admin'::text]))))));


--
-- Name: teacher_leaves HR and Admin can view all leaves; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "HR and Admin can view all leaves" ON public.teacher_leaves FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.users
  WHERE ((users.username = CURRENT_USER) AND (users.role = ANY (ARRAY['HR'::text, 'admin'::text]))))));


--
-- Name: assignment_submissions Students can submit assignments; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can submit assignments" ON public.assignment_submissions FOR INSERT WITH CHECK (((auth.uid())::text = student_id));


--
-- Name: student_details Students can update own details; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can update own details" ON public.student_details FOR UPDATE USING (((auth.uid())::text = student_id)) WITH CHECK (((auth.uid())::text = student_id));


--
-- Name: announcements Students can view announcements; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can view announcements" ON public.announcements FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.student_details
  WHERE ((student_details.student_id = (auth.uid())::text) AND ((student_details.year)::text = announcements.year) AND (student_details.section = announcements.section)))));


--
-- Name: assignments Students can view assignments; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can view assignments" ON public.assignments FOR SELECT USING (true);


--
-- Name: marks Students can view own marks; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can view own marks" ON public.marks FOR SELECT USING ((student_id = CURRENT_USER));


--
-- Name: study_materials Students can view study materials; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can view study materials" ON public.study_materials FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.student_details
  WHERE ((student_details.student_id = (auth.uid())::text) AND ((student_details.year)::text = study_materials.year) AND (student_details.section = study_materials.section)))));


--
-- Name: assignment_submissions Students can view their submissions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Students can view their submissions" ON public.assignment_submissions FOR SELECT USING (((auth.uid())::text = student_id));


--
-- Name: teacher_leaves Teachers can apply for leave; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can apply for leave" ON public.teacher_leaves FOR INSERT TO authenticated WITH CHECK ((teacher_id = CURRENT_USER));


--
-- Name: assignment_submissions Teachers can grade submissions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can grade submissions" ON public.assignment_submissions FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM public.teacher_details
  WHERE (teacher_details.teacher_id = (auth.uid())::text))));


--
-- Name: announcements Teachers can insert announcements; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can insert announcements" ON public.announcements FOR INSERT WITH CHECK (((auth.uid())::text = teacher_id));


--
-- Name: study_materials Teachers can insert study materials; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can insert study materials" ON public.study_materials FOR INSERT WITH CHECK (((auth.uid())::text = teacher_id));


--
-- Name: marks Teachers can manage marks; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can manage marks" ON public.marks USING ((teacher_id = CURRENT_USER));


--
-- Name: assignments Teachers can manage own assignments; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can manage own assignments" ON public.assignments USING ((teacher_id = CURRENT_USER));


--
-- Name: teacher_leave_balance Teachers can view own balance; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can view own balance" ON public.teacher_leave_balance FOR SELECT TO authenticated USING ((teacher_id = CURRENT_USER));


--
-- Name: teacher_leaves Teachers can view own leaves; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can view own leaves" ON public.teacher_leaves FOR SELECT TO authenticated USING ((teacher_id = CURRENT_USER));


--
-- Name: assignment_submissions Teachers can view submissions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can view submissions" ON public.assignment_submissions FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.teacher_details
  WHERE (teacher_details.teacher_id = (auth.uid())::text))));


--
-- Name: announcements Teachers can view their announcements; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can view their announcements" ON public.announcements FOR SELECT USING (((auth.uid())::text = teacher_id));


--
-- Name: study_materials Teachers can view their study materials; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Teachers can view their study materials" ON public.study_materials FOR SELECT USING (((auth.uid())::text = teacher_id));


--
-- Name: announcements; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

--
-- Name: assignment_submissions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.assignment_submissions ENABLE ROW LEVEL SECURITY;

--
-- Name: assignments; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;

--
-- Name: bus_fee_enrollment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.bus_fee_enrollment ENABLE ROW LEVEL SECURITY;

--
-- Name: classes; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;

--
-- Name: events; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;

--
-- Name: fee_payments; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.fee_payments ENABLE ROW LEVEL SECURITY;

--
-- Name: holidays; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.holidays ENABLE ROW LEVEL SECURITY;

--
-- Name: hostel_fee_enrollment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.hostel_fee_enrollment ENABLE ROW LEVEL SECURITY;

--
-- Name: marks; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year1_sectiona_assignment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year1_sectiona_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year1_sectiona_endsem; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year1_sectiona_endsem ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year1_sectiona_midterm; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year1_sectiona_midterm ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year1_sectiona_quiz; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year1_sectiona_quiz ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year1_sectionb_assignment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year1_sectionb_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year1_sectionb_endsem; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year1_sectionb_endsem ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year1_sectionb_midterm; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year1_sectionb_midterm ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year1_sectionb_quiz; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year1_sectionb_quiz ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year2_sectiona_assignment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year2_sectiona_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year2_sectiona_endsem; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year2_sectiona_endsem ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year2_sectiona_midterm; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year2_sectiona_midterm ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year2_sectiona_quiz; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year2_sectiona_quiz ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year2_sectionb_assignment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year2_sectionb_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year2_sectionb_endsem; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year2_sectionb_endsem ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year2_sectionb_midterm; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year2_sectionb_midterm ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year2_sectionb_quiz; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year2_sectionb_quiz ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year3_sectiona_assignment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year3_sectiona_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year3_sectiona_endsem; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year3_sectiona_endsem ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year3_sectiona_midterm; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year3_sectiona_midterm ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year3_sectiona_quiz; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year3_sectiona_quiz ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year3_sectionb_assignment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year3_sectionb_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year3_sectionb_endsem; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year3_sectionb_endsem ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year3_sectionb_midterm; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year3_sectionb_midterm ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year3_sectionb_quiz; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year3_sectionb_quiz ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year4_sectiona_assignment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year4_sectiona_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year4_sectiona_endsem; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year4_sectiona_endsem ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year4_sectiona_midterm; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year4_sectiona_midterm ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year4_sectiona_quiz; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year4_sectiona_quiz ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year4_sectionb_assignment; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year4_sectionb_assignment ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year4_sectionb_endsem; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year4_sectionb_endsem ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year4_sectionb_midterm; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year4_sectionb_midterm ENABLE ROW LEVEL SECURITY;

--
-- Name: marks_year4_sectionb_quiz; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.marks_year4_sectionb_quiz ENABLE ROW LEVEL SECURITY;

--
-- Name: student_details; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.student_details ENABLE ROW LEVEL SECURITY;

--
-- Name: study_materials; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.study_materials ENABLE ROW LEVEL SECURITY;

--
-- Name: teacher_leave_balance; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.teacher_leave_balance ENABLE ROW LEVEL SECURITY;

--
-- Name: teacher_leaves; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.teacher_leaves ENABLE ROW LEVEL SECURITY;

--
-- Name: teacher_salary; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.teacher_salary ENABLE ROW LEVEL SECURITY;

--
-- Name: timetable; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.timetable ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION ensure_monthly_leave_balance(p_teacher_id text, p_employee_id text, p_month integer, p_year integer); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.ensure_monthly_leave_balance(p_teacher_id text, p_employee_id text, p_month integer, p_year integer) TO anon;
GRANT ALL ON FUNCTION public.ensure_monthly_leave_balance(p_teacher_id text, p_employee_id text, p_month integer, p_year integer) TO authenticated;
GRANT ALL ON FUNCTION public.ensure_monthly_leave_balance(p_teacher_id text, p_employee_id text, p_month integer, p_year integer) TO service_role;


--
-- Name: FUNCTION ensure_single_active_salary(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.ensure_single_active_salary() TO anon;
GRANT ALL ON FUNCTION public.ensure_single_active_salary() TO authenticated;
GRANT ALL ON FUNCTION public.ensure_single_active_salary() TO service_role;


--
-- Name: FUNCTION update_events_updated_at(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_events_updated_at() TO anon;
GRANT ALL ON FUNCTION public.update_events_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.update_events_updated_at() TO service_role;


--
-- Name: FUNCTION update_leave_balance_on_approval(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_leave_balance_on_approval() TO anon;
GRANT ALL ON FUNCTION public.update_leave_balance_on_approval() TO authenticated;
GRANT ALL ON FUNCTION public.update_leave_balance_on_approval() TO service_role;


--
-- Name: FUNCTION update_leave_updated_at(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_leave_updated_at() TO anon;
GRANT ALL ON FUNCTION public.update_leave_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.update_leave_updated_at() TO service_role;


--
-- Name: FUNCTION update_salary_updated_at(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_salary_updated_at() TO anon;
GRANT ALL ON FUNCTION public.update_salary_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.update_salary_updated_at() TO service_role;


--
-- Name: FUNCTION update_student_fees_after_payment(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_student_fees_after_payment() TO anon;
GRANT ALL ON FUNCTION public.update_student_fees_after_payment() TO authenticated;
GRANT ALL ON FUNCTION public.update_student_fees_after_payment() TO service_role;


--
-- Name: FUNCTION update_teacher_updated_at(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_teacher_updated_at() TO anon;
GRANT ALL ON FUNCTION public.update_teacher_updated_at() TO authenticated;
GRANT ALL ON FUNCTION public.update_teacher_updated_at() TO service_role;


--
-- Name: FUNCTION update_updated_at_column(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.update_updated_at_column() TO anon;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO authenticated;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO service_role;


--
-- Name: TABLE announcements; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.announcements TO anon;
GRANT ALL ON TABLE public.announcements TO authenticated;
GRANT ALL ON TABLE public.announcements TO service_role;


--
-- Name: TABLE assignment_submissions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.assignment_submissions TO anon;
GRANT ALL ON TABLE public.assignment_submissions TO authenticated;
GRANT ALL ON TABLE public.assignment_submissions TO service_role;


--
-- Name: TABLE assignments; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.assignments TO anon;
GRANT ALL ON TABLE public.assignments TO authenticated;
GRANT ALL ON TABLE public.assignments TO service_role;


--
-- Name: SEQUENCE assignments_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.assignments_id_seq TO anon;
GRANT ALL ON SEQUENCE public.assignments_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.assignments_id_seq TO service_role;


--
-- Name: TABLE bus_fee_enrollment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.bus_fee_enrollment TO anon;
GRANT ALL ON TABLE public.bus_fee_enrollment TO authenticated;
GRANT ALL ON TABLE public.bus_fee_enrollment TO service_role;


--
-- Name: TABLE classes; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.classes TO anon;
GRANT ALL ON TABLE public.classes TO authenticated;
GRANT ALL ON TABLE public.classes TO service_role;


--
-- Name: TABLE subjects; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.subjects TO anon;
GRANT ALL ON TABLE public.subjects TO authenticated;
GRANT ALL ON TABLE public.subjects TO service_role;


--
-- Name: TABLE teacher_details; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teacher_details TO anon;
GRANT ALL ON TABLE public.teacher_details TO authenticated;
GRANT ALL ON TABLE public.teacher_details TO service_role;


--
-- Name: TABLE timetable; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.timetable TO anon;
GRANT ALL ON TABLE public.timetable TO authenticated;
GRANT ALL ON TABLE public.timetable TO service_role;


--
-- Name: TABLE class_timetable_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.class_timetable_view TO anon;
GRANT ALL ON TABLE public.class_timetable_view TO authenticated;
GRANT ALL ON TABLE public.class_timetable_view TO service_role;


--
-- Name: TABLE events; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.events TO anon;
GRANT ALL ON TABLE public.events TO authenticated;
GRANT ALL ON TABLE public.events TO service_role;


--
-- Name: TABLE fee_payments; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.fee_payments TO anon;
GRANT ALL ON TABLE public.fee_payments TO authenticated;
GRANT ALL ON TABLE public.fee_payments TO service_role;


--
-- Name: TABLE fee_transactions; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.fee_transactions TO anon;
GRANT ALL ON TABLE public.fee_transactions TO authenticated;
GRANT ALL ON TABLE public.fee_transactions TO service_role;


--
-- Name: SEQUENCE fee_transactions_transaction_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.fee_transactions_transaction_id_seq TO anon;
GRANT ALL ON SEQUENCE public.fee_transactions_transaction_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.fee_transactions_transaction_id_seq TO service_role;


--
-- Name: TABLE holidays; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.holidays TO anon;
GRANT ALL ON TABLE public.holidays TO authenticated;
GRANT ALL ON TABLE public.holidays TO service_role;


--
-- Name: SEQUENCE holidays_holiday_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.holidays_holiday_id_seq TO anon;
GRANT ALL ON SEQUENCE public.holidays_holiday_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.holidays_holiday_id_seq TO service_role;


--
-- Name: TABLE hostel_fee_enrollment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.hostel_fee_enrollment TO anon;
GRANT ALL ON TABLE public.hostel_fee_enrollment TO authenticated;
GRANT ALL ON TABLE public.hostel_fee_enrollment TO service_role;


--
-- Name: TABLE marks; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks TO anon;
GRANT ALL ON TABLE public.marks TO authenticated;
GRANT ALL ON TABLE public.marks TO service_role;


--
-- Name: SEQUENCE marks_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.marks_id_seq TO anon;
GRANT ALL ON SEQUENCE public.marks_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.marks_id_seq TO service_role;


--
-- Name: TABLE marks_year1_sectiona_assignment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year1_sectiona_assignment TO anon;
GRANT ALL ON TABLE public.marks_year1_sectiona_assignment TO authenticated;
GRANT ALL ON TABLE public.marks_year1_sectiona_assignment TO service_role;


--
-- Name: TABLE marks_year1_sectiona_endsem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year1_sectiona_endsem TO anon;
GRANT ALL ON TABLE public.marks_year1_sectiona_endsem TO authenticated;
GRANT ALL ON TABLE public.marks_year1_sectiona_endsem TO service_role;


--
-- Name: TABLE marks_year1_sectiona_midterm; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year1_sectiona_midterm TO anon;
GRANT ALL ON TABLE public.marks_year1_sectiona_midterm TO authenticated;
GRANT ALL ON TABLE public.marks_year1_sectiona_midterm TO service_role;


--
-- Name: TABLE marks_year1_sectiona_quiz; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year1_sectiona_quiz TO anon;
GRANT ALL ON TABLE public.marks_year1_sectiona_quiz TO authenticated;
GRANT ALL ON TABLE public.marks_year1_sectiona_quiz TO service_role;


--
-- Name: TABLE marks_year1_sectionb_assignment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year1_sectionb_assignment TO anon;
GRANT ALL ON TABLE public.marks_year1_sectionb_assignment TO authenticated;
GRANT ALL ON TABLE public.marks_year1_sectionb_assignment TO service_role;


--
-- Name: TABLE marks_year1_sectionb_endsem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year1_sectionb_endsem TO anon;
GRANT ALL ON TABLE public.marks_year1_sectionb_endsem TO authenticated;
GRANT ALL ON TABLE public.marks_year1_sectionb_endsem TO service_role;


--
-- Name: TABLE marks_year1_sectionb_midterm; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year1_sectionb_midterm TO anon;
GRANT ALL ON TABLE public.marks_year1_sectionb_midterm TO authenticated;
GRANT ALL ON TABLE public.marks_year1_sectionb_midterm TO service_role;


--
-- Name: TABLE marks_year1_sectionb_quiz; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year1_sectionb_quiz TO anon;
GRANT ALL ON TABLE public.marks_year1_sectionb_quiz TO authenticated;
GRANT ALL ON TABLE public.marks_year1_sectionb_quiz TO service_role;


--
-- Name: TABLE marks_year2_sectiona_assignment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year2_sectiona_assignment TO anon;
GRANT ALL ON TABLE public.marks_year2_sectiona_assignment TO authenticated;
GRANT ALL ON TABLE public.marks_year2_sectiona_assignment TO service_role;


--
-- Name: TABLE marks_year2_sectiona_endsem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year2_sectiona_endsem TO anon;
GRANT ALL ON TABLE public.marks_year2_sectiona_endsem TO authenticated;
GRANT ALL ON TABLE public.marks_year2_sectiona_endsem TO service_role;


--
-- Name: TABLE marks_year2_sectiona_midterm; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year2_sectiona_midterm TO anon;
GRANT ALL ON TABLE public.marks_year2_sectiona_midterm TO authenticated;
GRANT ALL ON TABLE public.marks_year2_sectiona_midterm TO service_role;


--
-- Name: TABLE marks_year2_sectiona_quiz; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year2_sectiona_quiz TO anon;
GRANT ALL ON TABLE public.marks_year2_sectiona_quiz TO authenticated;
GRANT ALL ON TABLE public.marks_year2_sectiona_quiz TO service_role;


--
-- Name: TABLE marks_year2_sectionb_assignment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year2_sectionb_assignment TO anon;
GRANT ALL ON TABLE public.marks_year2_sectionb_assignment TO authenticated;
GRANT ALL ON TABLE public.marks_year2_sectionb_assignment TO service_role;


--
-- Name: TABLE marks_year2_sectionb_endsem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year2_sectionb_endsem TO anon;
GRANT ALL ON TABLE public.marks_year2_sectionb_endsem TO authenticated;
GRANT ALL ON TABLE public.marks_year2_sectionb_endsem TO service_role;


--
-- Name: TABLE marks_year2_sectionb_midterm; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year2_sectionb_midterm TO anon;
GRANT ALL ON TABLE public.marks_year2_sectionb_midterm TO authenticated;
GRANT ALL ON TABLE public.marks_year2_sectionb_midterm TO service_role;


--
-- Name: TABLE marks_year2_sectionb_quiz; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year2_sectionb_quiz TO anon;
GRANT ALL ON TABLE public.marks_year2_sectionb_quiz TO authenticated;
GRANT ALL ON TABLE public.marks_year2_sectionb_quiz TO service_role;


--
-- Name: TABLE marks_year3_sectiona_assignment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year3_sectiona_assignment TO anon;
GRANT ALL ON TABLE public.marks_year3_sectiona_assignment TO authenticated;
GRANT ALL ON TABLE public.marks_year3_sectiona_assignment TO service_role;


--
-- Name: TABLE marks_year3_sectiona_endsem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year3_sectiona_endsem TO anon;
GRANT ALL ON TABLE public.marks_year3_sectiona_endsem TO authenticated;
GRANT ALL ON TABLE public.marks_year3_sectiona_endsem TO service_role;


--
-- Name: TABLE marks_year3_sectiona_midterm; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year3_sectiona_midterm TO anon;
GRANT ALL ON TABLE public.marks_year3_sectiona_midterm TO authenticated;
GRANT ALL ON TABLE public.marks_year3_sectiona_midterm TO service_role;


--
-- Name: TABLE marks_year3_sectiona_quiz; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year3_sectiona_quiz TO anon;
GRANT ALL ON TABLE public.marks_year3_sectiona_quiz TO authenticated;
GRANT ALL ON TABLE public.marks_year3_sectiona_quiz TO service_role;


--
-- Name: TABLE marks_year3_sectionb_assignment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year3_sectionb_assignment TO anon;
GRANT ALL ON TABLE public.marks_year3_sectionb_assignment TO authenticated;
GRANT ALL ON TABLE public.marks_year3_sectionb_assignment TO service_role;


--
-- Name: TABLE marks_year3_sectionb_endsem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year3_sectionb_endsem TO anon;
GRANT ALL ON TABLE public.marks_year3_sectionb_endsem TO authenticated;
GRANT ALL ON TABLE public.marks_year3_sectionb_endsem TO service_role;


--
-- Name: TABLE marks_year3_sectionb_midterm; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year3_sectionb_midterm TO anon;
GRANT ALL ON TABLE public.marks_year3_sectionb_midterm TO authenticated;
GRANT ALL ON TABLE public.marks_year3_sectionb_midterm TO service_role;


--
-- Name: TABLE marks_year3_sectionb_quiz; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year3_sectionb_quiz TO anon;
GRANT ALL ON TABLE public.marks_year3_sectionb_quiz TO authenticated;
GRANT ALL ON TABLE public.marks_year3_sectionb_quiz TO service_role;


--
-- Name: TABLE marks_year4_sectiona_assignment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year4_sectiona_assignment TO anon;
GRANT ALL ON TABLE public.marks_year4_sectiona_assignment TO authenticated;
GRANT ALL ON TABLE public.marks_year4_sectiona_assignment TO service_role;


--
-- Name: TABLE marks_year4_sectiona_endsem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year4_sectiona_endsem TO anon;
GRANT ALL ON TABLE public.marks_year4_sectiona_endsem TO authenticated;
GRANT ALL ON TABLE public.marks_year4_sectiona_endsem TO service_role;


--
-- Name: TABLE marks_year4_sectiona_midterm; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year4_sectiona_midterm TO anon;
GRANT ALL ON TABLE public.marks_year4_sectiona_midterm TO authenticated;
GRANT ALL ON TABLE public.marks_year4_sectiona_midterm TO service_role;


--
-- Name: TABLE marks_year4_sectiona_quiz; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year4_sectiona_quiz TO anon;
GRANT ALL ON TABLE public.marks_year4_sectiona_quiz TO authenticated;
GRANT ALL ON TABLE public.marks_year4_sectiona_quiz TO service_role;


--
-- Name: TABLE marks_year4_sectionb_assignment; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year4_sectionb_assignment TO anon;
GRANT ALL ON TABLE public.marks_year4_sectionb_assignment TO authenticated;
GRANT ALL ON TABLE public.marks_year4_sectionb_assignment TO service_role;


--
-- Name: TABLE marks_year4_sectionb_endsem; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year4_sectionb_endsem TO anon;
GRANT ALL ON TABLE public.marks_year4_sectionb_endsem TO authenticated;
GRANT ALL ON TABLE public.marks_year4_sectionb_endsem TO service_role;


--
-- Name: TABLE marks_year4_sectionb_midterm; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year4_sectionb_midterm TO anon;
GRANT ALL ON TABLE public.marks_year4_sectionb_midterm TO authenticated;
GRANT ALL ON TABLE public.marks_year4_sectionb_midterm TO service_role;


--
-- Name: TABLE marks_year4_sectionb_quiz; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.marks_year4_sectionb_quiz TO anon;
GRANT ALL ON TABLE public.marks_year4_sectionb_quiz TO authenticated;
GRANT ALL ON TABLE public.marks_year4_sectionb_quiz TO service_role;


--
-- Name: TABLE student_details; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.student_details TO anon;
GRANT ALL ON TABLE public.student_details TO authenticated;
GRANT ALL ON TABLE public.student_details TO service_role;


--
-- Name: TABLE student_fees; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.student_fees TO anon;
GRANT ALL ON TABLE public.student_fees TO authenticated;
GRANT ALL ON TABLE public.student_fees TO service_role;


--
-- Name: TABLE student_subjects; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.student_subjects TO anon;
GRANT ALL ON TABLE public.student_subjects TO authenticated;
GRANT ALL ON TABLE public.student_subjects TO service_role;


--
-- Name: SEQUENCE student_subjects_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.student_subjects_id_seq TO anon;
GRANT ALL ON SEQUENCE public.student_subjects_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.student_subjects_id_seq TO service_role;


--
-- Name: TABLE study_materials; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.study_materials TO anon;
GRANT ALL ON TABLE public.study_materials TO authenticated;
GRANT ALL ON TABLE public.study_materials TO service_role;


--
-- Name: TABLE teacher_leave_balance; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teacher_leave_balance TO anon;
GRANT ALL ON TABLE public.teacher_leave_balance TO authenticated;
GRANT ALL ON TABLE public.teacher_leave_balance TO service_role;


--
-- Name: SEQUENCE teacher_leave_balance_balance_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.teacher_leave_balance_balance_id_seq TO anon;
GRANT ALL ON SEQUENCE public.teacher_leave_balance_balance_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.teacher_leave_balance_balance_id_seq TO service_role;


--
-- Name: TABLE teacher_leaves; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teacher_leaves TO anon;
GRANT ALL ON TABLE public.teacher_leaves TO authenticated;
GRANT ALL ON TABLE public.teacher_leaves TO service_role;


--
-- Name: SEQUENCE teacher_leaves_leave_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.teacher_leaves_leave_id_seq TO anon;
GRANT ALL ON SEQUENCE public.teacher_leaves_leave_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.teacher_leaves_leave_id_seq TO service_role;


--
-- Name: TABLE teacher_salary; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teacher_salary TO anon;
GRANT ALL ON TABLE public.teacher_salary TO authenticated;
GRANT ALL ON TABLE public.teacher_salary TO service_role;


--
-- Name: TABLE teacher_monthly_payroll; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teacher_monthly_payroll TO anon;
GRANT ALL ON TABLE public.teacher_monthly_payroll TO authenticated;
GRANT ALL ON TABLE public.teacher_monthly_payroll TO service_role;


--
-- Name: SEQUENCE teacher_salary_salary_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.teacher_salary_salary_id_seq TO anon;
GRANT ALL ON SEQUENCE public.teacher_salary_salary_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.teacher_salary_salary_id_seq TO service_role;


--
-- Name: TABLE teacher_salary_summary; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.teacher_salary_summary TO anon;
GRANT ALL ON TABLE public.teacher_salary_summary TO authenticated;
GRANT ALL ON TABLE public.teacher_salary_summary TO service_role;


--
-- Name: SEQUENCE timetable_id_seq; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON SEQUENCE public.timetable_id_seq TO anon;
GRANT ALL ON SEQUENCE public.timetable_id_seq TO authenticated;
GRANT ALL ON SEQUENCE public.timetable_id_seq TO service_role;


--
-- Name: TABLE users; Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON TABLE public.users TO anon;
GRANT ALL ON TABLE public.users TO authenticated;
GRANT ALL ON TABLE public.users TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict cJl16R5fXdITw7iTyVTQpOdPemf3OFd9YYXPbxEWtlJ6XypMExTAo4KDZHSn0Qv

