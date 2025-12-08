--
-- PostgreSQL database dump
--

\restrict kqJbYnVe9AAZELHKd3EokOxXi8RXKbU0UhmMCY4PwpQou4xQgMEQJHxud27hNLD

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
-- Data for Name: announcements; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.announcements (id, title, message, priority, subject_id, teacher_id, year, section, created_at, updated_at) FROM stdin;
f3817519-a205-4285-bac4-3b5b865954f3	Holiday	holiday on sunday	Normal	SUB001	teacher1	1	A	2025-12-02 15:03:22.783378+00	2025-12-02 09:33:23.12747+00
\.


--
-- Data for Name: assignment_submissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.assignment_submissions (id, assignment_id, student_id, file_url, submitted_at, status, grade, feedback, created_at, updated_at) FROM stdin;
6e33d1d0-26f5-4256-a115-2ac708b8d335	1	BT24CSE154	https://rvyzfqffjgwadxtbiuvr.supabase.co/storage/v1/object/public/assignment-submissions/submissions/submission_BT24CSE154_1_1764666707243.pdf	2025-12-02 14:41:49.720515+00	submitted	\N	\N	2025-12-02 09:11:49.892253+00	2025-12-02 09:11:49.892253+00
\.


--
-- Data for Name: teacher_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teacher_details (teacher_id, name, employee_id, subject, department, phone, email, qualification, profile_photo_url, created_at, updated_at, date_of_birth, gender, address, city, state, pincode, emergency_contact_name, emergency_contact_number, emergency_contact_relation, designation, date_of_joining, employment_type, reporting_to, status, highest_qualification, university, passing_year, specialization, total_experience_years, previous_employer_1, previous_role_1, previous_duration_1, previous_employer_2, previous_role_2, previous_duration_2, previous_employer_3, previous_role_3, previous_duration_3, aadhaar_url, pan_url, degree_certificate_url, experience_letter_url, offer_letter_url, joining_letter_url, resume_url, aadhaar_number, pan_number, created_by, updated_by) FROM stdin;
teacher1	Dr. Rajesh Kumar	EMP001	Data Structures	CSE	+91-9876543210	rajesh.kumar@shivalik.edu	PhD in Computer Science	\N	2025-12-08 14:31:28.249316+00	2025-12-08 14:31:28.249316+00	1985-01-15	Male	123, Green Valley, Sector 5	Dehradun	Uttarakhand	248001	Ravi Kumar	+91 98765 00000	Brother	Professor	2018-08-01	Permanent	\N	Active	Ph.D. in Computer Science	IIT Delhi	2015	Algorithms & Data Structures	12	ABC University	Associate Professor	2015 - 2018	XYZ Institute	Assistant Professor	2012 - 2015	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	123456789012	ABCDE1234F	\N	\N
teacher2	Prof. Priya Sharma	EMP002	Database Management	CSE	+91-9876543211	priya.sharma@shivalik.edu	M.Tech in CSE	\N	2025-12-08 14:31:28.249316+00	2025-12-08 14:31:28.249316+00	1988-03-22	Female	456, Park Avenue, Sector 7	Dehradun	Uttarakhand	248002	Rahul Sharma	+91 98765 00001	Husband	Associate Professor	2019-07-15	Permanent	EMP001	Active	Ph.D. in Electronics	NIT Trichy	2017	VLSI Design	10	DEF College	Assistant Professor	2017 - 2019	GHI University	Lecturer	2014 - 2017	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	234567890123	BCDEF2345G	\N	\N
teacher3	Dr. Amit Verma	EMP003	Operating Systems	CSE	+91-9876543212	amit.verma@shivalik.edu	PhD in Software Engineering	\N	2025-12-08 14:31:28.249316+00	2025-12-08 14:31:28.249316+00	1990-06-10	Male	789, Hill View, Sector 3	Dehradun	Uttarakhand	248003	Sunita Verma	+91 98765 00002	Wife	Assistant Professor	2020-01-10	Permanent	EMP001	On Leave	M.Tech in Mechanical Engineering	IIT Roorkee	2018	Thermal Engineering	8	JKL Institute	Lecturer	2018 - 2020	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	345678901234	CDEFG3456H	\N	\N
teacher4	Prof. Neha Gupta	EMP004	Computer Networks	CSE	+91-9876543213	neha.gupta@shivalik.edu	M.Tech in Networks	\N	2025-12-08 14:31:28.249316+00	2025-12-08 14:31:28.249316+00	1982-09-05	Female	321, Lake Side, Sector 9	Dehradun	Uttarakhand	248004	Kiran Patel	+91 98765 00003	Sister	HOD	2015-06-01	Permanent	\N	Active	Ph.D. in Computer Science	IIT Bombay	2012	Software Engineering	15	MNO University	Professor	2012 - 2015	PQR College	Associate Professor	2009 - 2012	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	456789012345	DEFGH4567I	\N	\N
teacher5	Dr. Vikram Singh	EMP005	General Administration	Administration	+91-9876543214	vikram.singh@shivalik.edu	PhD in AI & ML	\N	2025-12-08 14:31:28.249316+00	2025-12-08 14:31:28.249316+00	1992-11-20	Male	654, Mountain View, Sector 11	Dehradun	Uttarakhand	248005	Anjali Singh	+91 98765 00004	Mother	Admin Manager	2021-03-15	Permanent	EMP004	Active	MBA in HR Management	Delhi University	2016	Human Resources	6	STU Corporation	HR Executive	2016 - 2021	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	567890123456	EFGHI5678J	\N	\N
teacher6	Ujjwal Srivastav	EMP006	DSA	CSE	8881068415	ujjwalsvs123@gmail.com	Btech	\N	2025-12-08 14:31:28.249316+00	2025-12-08 14:31:28.249316+00	\N	\N	\N	\N	\N	\N	\N	\N	\N	Professor	\N	\N	\N	Active	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N	\N
\.


--
-- Data for Name: subjects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.subjects (subject_id, subject_name, teacher_id, department, created_at) FROM stdin;
\.


--
-- Data for Name: assignments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.assignments (id, title, description, file_url, subject_id, teacher_id, due_date, created_at, year, section) FROM stdin;
\.


--
-- Data for Name: bus_fee_enrollment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.bus_fee_enrollment (student_id, bus_fee, enrolled_date) FROM stdin;
BT24CSE161	20000.00	2025-11-23 10:00:53.870105
BT24CSE162	20000.00	2025-11-23 10:00:53.870105
\.


--
-- Data for Name: classes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.classes (id, class_name, year, section, created_at) FROM stdin;
8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd	1A	1	A	2025-12-03 11:35:18.934766
7364690c-7a5b-4fdb-a546-64d07041d03a	1B	1	B	2025-12-03 11:35:18.934766
94c9fca0-b196-42ac-abbb-08330fd6eab5	2A	2	A	2025-12-03 11:35:18.934766
1862984f-9273-45f8-adc0-92a85bce456a	2B	2	B	2025-12-03 11:35:18.934766
2ecc0606-6b65-4209-88fd-896a5a6ea09e	3A	3	A	2025-12-03 11:35:18.934766
37197cba-1cb5-43fa-aae3-6815f3b672c1	3B	3	B	2025-12-03 11:35:18.934766
e18d0a80-323a-4cd9-9901-d3387b440046	4A	4	A	2025-12-03 11:35:18.934766
dfc91e52-a815-4f64-9997-fdec726510db	4B	4	B	2025-12-03 11:35:18.934766
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (username, password, role) FROM stdin;
BT24CSE154	BT24CSE154	student
BT24CSE155	BT24CSE155	student
BT24CSE156	BT24CSE156	student
BT24CSE157	BT24CSE157	student
BT24CSE158	BT24CSE158	student
BT24CSE159	BT24CSE159	student
BT24CSE160	BT24CSE160	student
BT24CSE161	BT24CSE161	student
BT24CSE162	BT24CSE162	student
BT24CSE163	BT24CSE163	student
BT24CSE164	BT24CSE164	student
teacher1	teacher1	teacher
teacher2	teacher2	teacher
teacher3	teacher3	teacher
teacher4	teacher4	teacher
teacher5	teacher5	teacher
admin1	admin1	admin
teacher6	teacher6	teacher
BT25CSE001	BT25CSE001	student
hr1	hr1	HR
hod1	hod1	hod
\.


--
-- Data for Name: events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.events (id, title, description, event_type, event_date, start_time, end_time, location, organizer, target_audience, status, created_by, created_at, updated_at) FROM stdin;
23e695e1-a956-4b4b-b35d-c83aa5c86d4d	Hackathon	Hackathon in college	other	2025-12-04	10:12:00	22:12:00	Shivalik College	CSE Department	{all}	upcoming	hod1	2025-12-04 04:43:12.628184	2025-12-04 04:43:12.628184
\.


--
-- Data for Name: fee_payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fee_payments (payment_id, student_id, razorpay_order_id, razorpay_payment_id, razorpay_signature, amount, fee_type, payment_status, academic_year, payment_date, created_at) FROM stdin;
\.


--
-- Data for Name: fee_transactions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fee_transactions (transaction_id, student_id, amount, payment_method, razorpay_order_id, razorpay_payment_id, razorpay_signature, payment_status, academic_year, payment_date, created_at) FROM stdin;
1	BT24CSE154	1000.00	razorpay	\N	pay_Rj8v4kocsY5TND	\N	success	2024-25	2025-11-23 15:37:51.286559	2025-11-23 10:07:22.459758
2	BT24CSE154	133000.00	razorpay	\N	\N	\N	pending	2024-25	2025-12-04 04:47:50.69947	2025-12-04 04:47:50.69947
\.


--
-- Data for Name: holidays; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.holidays (holiday_id, holiday_name, holiday_date, description, holiday_type, is_holiday, is_working_day, created_by, created_at, updated_at) FROM stdin;
1	New Year	2025-01-01	New Year Day	National	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
2	Republic Day	2025-01-26	Republic Day of India	National	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
3	Holi	2025-03-14	Festival of Colors	Religious	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
4	Eid ul-Fitr	2025-03-31	End of Ramadan	Religious	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
5	Good Friday	2025-04-18	Good Friday	Religious	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
6	Independence Day	2025-08-15	Independence Day of India	National	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
7	Janmashtami	2025-08-16	Birth of Lord Krishna	Religious	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
8	Gandhi Jayanti	2025-10-02	Birth of Mahatma Gandhi	National	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
10	Diwali	2025-10-20	Festival of Lights	Religious	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
11	Guru Nanak Jayanti	2025-11-05	Birth of Guru Nanak	Religious	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
12	Christmas	2025-12-25	Birth of Jesus Christ	Religious	t	f	\N	2025-12-02 15:54:33.736776+00	2025-12-02 15:54:33.736776+00
13	aaa	2025-12-11		Custom	t	f	hr1	2025-12-03 05:24:22.079995+00	2025-12-03 05:24:22.079995+00
\.


--
-- Data for Name: hostel_fee_enrollment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.hostel_fee_enrollment (student_id, hostel_fee, enrolled_date) FROM stdin;
BT24CSE158	100000.00	2025-11-23 10:00:53.870105
BT24CSE159	100000.00	2025-11-23 10:00:53.870105
BT24CSE160	100000.00	2025-11-23 10:00:53.870105
\.


--
-- Data for Name: student_details; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_details (student_id, name, father_name, year, semester, department, section, profile_photo_url, created_at, updated_at, class_id) FROM stdin;
BT25CSE001	divyansh kapoor	ujjwal srivastav	1	1	CSE	B	\N	2025-12-01 18:09:42.73566+00	2025-12-01 18:09:42.738226+00	\N
BT24CSE154	Aarav Sharma	Rajesh Sharma	1	1	CSE	A	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd
BT24CSE155	Vivaan Patel	Mahesh Patel	1	1	CSE	A	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd
BT24CSE156	Aditya Kumar	Suresh Kumar	1	1	CSE	B	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd
BT24CSE157	Vihaan Singh	Ramesh Singh	1	1	CSE	B	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd
BT24CSE158	Arjun Verma	Dinesh Verma	2	3	CSE	A	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd
BT24CSE159	Sai Reddy	Venkat Reddy	2	3	CSE	A	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	8af8a5d0-f6e7-4c08-b2e0-3ec619cd2abd
BT24CSE160	Reyansh Gupta	Anil Gupta	2	4	CSE	B	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	7364690c-7a5b-4fdb-a546-64d07041d03a
BT24CSE161	Ayaan Khan	Salman Khan	3	5	CSE	A	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	7364690c-7a5b-4fdb-a546-64d07041d03a
BT24CSE163	Ishaan Joshi	Prakash Joshi	4	7	CSE	A	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	7364690c-7a5b-4fdb-a546-64d07041d03a
BT24CSE164	Shaurya Nair	Mohan Nair	4	8	CSE	B	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	7364690c-7a5b-4fdb-a546-64d07041d03a
BT24CSE162	Krishna Iyer	Ravi Iyer	3	6	CSE	B	\N	2025-11-20 14:55:58.716768+00	2025-12-03 11:35:18.934766+00	7364690c-7a5b-4fdb-a546-64d07041d03a
\.


--
-- Data for Name: marks; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks (id, student_id, subject_id, exam_type, marks_obtained, total_marks, teacher_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year1_sectiona_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year1_sectiona_assignment (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year1_sectiona_endsem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year1_sectiona_endsem (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
68b5aa5e-72f4-4ebe-8411-3357c247a635	BT24CSE154	SUB001	teacher1	33.00	100.00	\N	\N	2025-11-22 08:41:06.084247+00	2025-11-22 14:11:04.869945+00
3a581c23-7f13-4b87-bb3d-1102ffab03f7	BT24CSE155	SUB001	teacher1	33.00	100.00	\N	\N	2025-11-22 08:41:06.584724+00	2025-11-22 14:11:06.220399+00
\.


--
-- Data for Name: marks_year1_sectiona_midterm; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year1_sectiona_midterm (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year1_sectiona_quiz; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year1_sectiona_quiz (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year1_sectionb_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year1_sectionb_assignment (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year1_sectionb_endsem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year1_sectionb_endsem (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year1_sectionb_midterm; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year1_sectionb_midterm (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year1_sectionb_quiz; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year1_sectionb_quiz (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year2_sectiona_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year2_sectiona_assignment (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year2_sectiona_endsem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year2_sectiona_endsem (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year2_sectiona_midterm; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year2_sectiona_midterm (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year2_sectiona_quiz; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year2_sectiona_quiz (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year2_sectionb_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year2_sectionb_assignment (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year2_sectionb_endsem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year2_sectionb_endsem (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year2_sectionb_midterm; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year2_sectionb_midterm (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year2_sectionb_quiz; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year2_sectionb_quiz (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year3_sectiona_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year3_sectiona_assignment (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year3_sectiona_endsem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year3_sectiona_endsem (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year3_sectiona_midterm; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year3_sectiona_midterm (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year3_sectiona_quiz; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year3_sectiona_quiz (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year3_sectionb_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year3_sectionb_assignment (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year3_sectionb_endsem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year3_sectionb_endsem (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year3_sectionb_midterm; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year3_sectionb_midterm (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year3_sectionb_quiz; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year3_sectionb_quiz (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year4_sectiona_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year4_sectiona_assignment (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year4_sectiona_endsem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year4_sectiona_endsem (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year4_sectiona_midterm; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year4_sectiona_midterm (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year4_sectiona_quiz; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year4_sectiona_quiz (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year4_sectionb_assignment; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year4_sectionb_assignment (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year4_sectionb_endsem; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year4_sectionb_endsem (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year4_sectionb_midterm; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year4_sectionb_midterm (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: marks_year4_sectionb_quiz; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.marks_year4_sectionb_quiz (id, student_id, subject_id, teacher_id, marks_obtained, total_marks, grade, remarks, uploaded_at, updated_at) FROM stdin;
\.


--
-- Data for Name: student_fees; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_fees (student_id, base_fee, total_fee, paid_amount, pending_amount, academic_year, last_payment_date, created_at, updated_at) FROM stdin;
BT24CSE155	134000.00	134000.00	0.00	134000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE156	134000.00	134000.00	0.00	134000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE157	134000.00	134000.00	0.00	134000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE158	134000.00	234000.00	0.00	234000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE159	134000.00	234000.00	0.00	234000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE160	134000.00	234000.00	0.00	234000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE161	134000.00	154000.00	0.00	154000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE162	134000.00	154000.00	0.00	154000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE163	134000.00	134000.00	0.00	134000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE164	134000.00	134000.00	0.00	134000.00	2024-25	\N	2025-11-23 10:00:53.870105	2025-11-23 10:00:53.870105
BT24CSE154	134000.00	134000.00	1000.00	133000.00	2024-25	2025-11-23 15:37:51.286559	2025-11-23 10:00:53.870105	2025-11-23 10:07:50.837414
\.


--
-- Data for Name: student_subjects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.student_subjects (id, student_id, subject_id, teacher_id, created_at) FROM stdin;
\.


--
-- Data for Name: study_materials; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.study_materials (id, title, description, material_type, subject_id, teacher_id, file_url, year, section, created_at, updated_at) FROM stdin;
aa80766b-d9a9-46ad-9294-493dd222381d	ch1 notes		Notes	SUB001	teacher1	https://rvyzfqffjgwadxtbiuvr.supabase.co/storage/v1/object/public/study-materials/study-materials/study_material_1764667411998_639002219451027353.pdf	1	A	2025-12-02 14:53:34.857807+00	2025-12-02 09:23:35.401893+00
\.


--
-- Data for Name: teacher_leave_balance; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teacher_leave_balance (balance_id, teacher_id, employee_id, month, year, sick_leaves_total, sick_leaves_used, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: teacher_leaves; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teacher_leaves (leave_id, teacher_id, employee_id, leave_type, start_date, end_date, total_days, reason, document_url, status, approved_by, approved_at, rejection_reason, created_at, updated_at, deduction_amount, is_salary_deducted) FROM stdin;
\.


--
-- Data for Name: teacher_salary; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teacher_salary (salary_id, employee_id, basic_salary, hra, travel_allowance, medical_allowance, special_allowance, other_allowances, provident_fund, professional_tax, income_tax, other_deductions, bank_name, account_number, ifsc_code, branch_name, payment_mode, effective_from, effective_to, is_active, created_at, updated_at, created_by, updated_by) FROM stdin;
\.


--
-- Data for Name: timetable; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.timetable (id, day_of_week, time_slot, start_time, end_time, subject_id, teacher_id, room_number, created_at, class_id) FROM stdin;
\.


--
-- Name: assignments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.assignments_id_seq', 1, true);


--
-- Name: fee_transactions_transaction_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.fee_transactions_transaction_id_seq', 2, true);


--
-- Name: holidays_holiday_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.holidays_holiday_id_seq', 13, true);


--
-- Name: marks_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.marks_id_seq', 2, true);


--
-- Name: student_subjects_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.student_subjects_id_seq', 55, true);


--
-- Name: teacher_leave_balance_balance_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.teacher_leave_balance_balance_id_seq', 24, true);


--
-- Name: teacher_leaves_leave_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.teacher_leaves_leave_id_seq', 3, true);


--
-- Name: teacher_salary_salary_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.teacher_salary_salary_id_seq', 5, true);


--
-- Name: timetable_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.timetable_id_seq', 75, true);


--
-- PostgreSQL database dump complete
--

\unrestrict kqJbYnVe9AAZELHKd3EokOxXi8RXKbU0UhmMCY4PwpQou4xQgMEQJHxud27hNLD

