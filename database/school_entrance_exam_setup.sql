-- ============================================================================
-- School Admissions — Entrance Examination setup
-- ============================================================================
-- Adds the entrance exam stage that runs BEFORE document verification:
--
--   Applied → Entrance Exam → Documents Verified → Offer Letter Issued → Enrolled
--
-- Two delivery modes are supported:
--   * offline — the admin desk records the marks obtained in each subject.
--   * online  — an AI-generated question paper is produced from the syllabus
--               topics of the previous class plus the class being applied for.
--
-- Subjects/topics are maintained per class and every subject carries a fixed
-- weightage of 50 marks.
--
-- Safe to run more than once.
-- ============================================================================

-- 1. Subject + topic catalog (admin-editable blueprint) ----------------------
CREATE TABLE IF NOT EXISTS school_entrance_exam_subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  class_name TEXT NOT NULL,
  subject TEXT NOT NULL,
  weightage INT NOT NULL DEFAULT 50,
  topics JSONB NOT NULL DEFAULT '[]'::jsonb,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (class_name, subject)
);

CREATE INDEX IF NOT EXISTS idx_entrance_subjects_class
  ON school_entrance_exam_subjects (class_name);

-- 2. Generated question papers ----------------------------------------------
CREATE TABLE IF NOT EXISTS school_entrance_exam_papers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admission_id UUID,
  class_name TEXT NOT NULL,
  mode TEXT NOT NULL DEFAULT 'online',          -- online | offline
  subjects JSONB NOT NULL DEFAULT '[]'::jsonb,  -- [{subject, weightage, topics, questions:[...]}]
  total_marks INT NOT NULL DEFAULT 0,
  generated_by TEXT,
  ai_model TEXT DEFAULT 'template-fallback',
  status TEXT NOT NULL DEFAULT 'generated',     -- generated | completed
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_entrance_papers_admission
  ON school_entrance_exam_papers (admission_id);
CREATE INDEX IF NOT EXISTS idx_entrance_papers_class
  ON school_entrance_exam_papers (class_name);

-- 3. Recorded results --------------------------------------------------------
CREATE TABLE IF NOT EXISTS school_entrance_exam_results (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  admission_id UUID NOT NULL,
  paper_id UUID,
  class_name TEXT,
  mode TEXT NOT NULL DEFAULT 'offline',
  subject_scores JSONB NOT NULL DEFAULT '[]'::jsonb, -- [{subject, marks, max}]
  total_score NUMERIC NOT NULL DEFAULT 0,
  max_score NUMERIC NOT NULL DEFAULT 0,
  percentage NUMERIC NOT NULL DEFAULT 0,
  grade TEXT,
  recorded_by TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_entrance_results_admission
  ON school_entrance_exam_results (admission_id);

-- 4. Denormalised columns on the admission row ------------------------------
ALTER TABLE school_admissions
  ADD COLUMN IF NOT EXISTS entrance_exam_status TEXT DEFAULT 'Pending',
  ADD COLUMN IF NOT EXISTS entrance_exam_mode TEXT,
  ADD COLUMN IF NOT EXISTS entrance_score NUMERIC,
  ADD COLUMN IF NOT EXISTS entrance_max_score NUMERIC,
  ADD COLUMN IF NOT EXISTS entrance_percentage NUMERIC,
  ADD COLUMN IF NOT EXISTS entrance_subjects JSONB,
  ADD COLUMN IF NOT EXISTS entrance_exam_at TIMESTAMPTZ;

-- 5. Permissive access consistent with the rest of the school modules -------
ALTER TABLE school_entrance_exam_subjects DISABLE ROW LEVEL SECURITY;
ALTER TABLE school_entrance_exam_papers DISABLE ROW LEVEL SECURITY;
ALTER TABLE school_entrance_exam_results DISABLE ROW LEVEL SECURITY;

GRANT ALL ON TABLE school_entrance_exam_subjects TO anon, authenticated, service_role;
GRANT ALL ON TABLE school_entrance_exam_papers TO anon, authenticated, service_role;
GRANT ALL ON TABLE school_entrance_exam_results TO anon, authenticated, service_role;

-- 6. Seed a default blueprint for the common CBSE classes -------------------
--    Only inserted when the class has no subjects yet. Each subject is worth
--    50 marks. Topics intentionally cover the previous class plus the target
--    class so the AI paper can bridge both syllabi.
INSERT INTO school_entrance_exam_subjects (class_name, subject, weightage, topics)
SELECT v.class_name, v.subject, 50, v.topics::jsonb
FROM (VALUES
  ('Class 1', 'English',   '["Pre-primary phonics","Alphabet and sounds","Simple words","Picture reading","Previous class: rhymes and naming words","Target class: sentence formation and comprehension"]'),
  ('Class 1', 'Mathematics','["Counting 1-100","Number names","Simple addition and subtraction","Shapes and patterns","Previous class: pre-number concepts","Target class: place value and basic word problems"]'),
  ('Class 1', 'EVS',       '["My body","Family and friends","Plants and animals","Safety and hygiene","Previous class: surroundings awareness","Target class: community helpers and seasons"]'),
  ('Class 2', 'English',   '["Reading simple passages","Nouns and verbs","Opposites","Punctuation","Previous class: phonics and sentence formation","Target class: paragraph writing and comprehension"]'),
  ('Class 2', 'Mathematics','["Addition and subtraction with carry","Multiplication tables 2-5","Time and money","Measurement","Previous class: place value","Target class: division basics and word problems"]'),
  ('Class 2', 'EVS',       '["Our neighbourhood","Water and air","Food and nutrition","Transport","Previous class: family and community helpers","Target class: plants, animals and weather"]'),
  ('Class 3', 'English',   '["Reading comprehension","Tenses","Adjectives and adverbs","Picture composition","Previous class: nouns, verbs and punctuation","Target class: paragraph writing and grammar usage"]'),
  ('Class 3', 'Mathematics','["Numbers up to 1000","Multiplication and division","Fractions (intro)","Geometry and measurement","Previous class: addition/subtraction with carry","Target class: word problems and patterns"]'),
  ('Class 3', 'EVS',       '["Living and non-living things","Plants and animals","Our body","Water and weather","Previous class: neighbourhood and transport","Target class: natural resources and conservation"]'),
  ('Class 4', 'English',   '["Comprehension and inference","Grammar: tenses and articles","Vocabulary building","Letter and paragraph writing","Previous class: adjectives, adverbs and composition","Target class: creative writing and editing"]'),
  ('Class 4', 'Mathematics','["Large numbers and place value","Multiplication/division","Fractions and decimals (intro)","Perimeter and area","Previous class: basic geometry","Target class: multi-step word problems"]'),
  ('Class 4', 'Science',   '["Plants and their parts","Animals and habitats","Food and digestion","Matter and materials","Previous class: living/non-living and our body","Target class: force, motion and simple machines"]'),
  ('Class 4', 'Social Studies','["Maps and directions","Our country and states","Community and culture","Early civilisations","Previous class: neighbourhood awareness","Target class: Indian geography and history"]'),
  ('Class 5', 'English',   '["Reading comprehension","Grammar: subject-verb agreement","Idioms and vocabulary","Essay and letter writing","Previous class: tenses and paragraph writing","Target class: advanced composition and literature response"]'),
  ('Class 5', 'Mathematics','["Number system","LCM and HCF","Fractions and decimals","Percentage and averages","Previous class: geometry and measurement","Target class: ratio, simple interest and data handling"]'),
  ('Class 5', 'Science',   '["Human body systems","Plants and photosynthesis","Force and energy","Natural resources","Previous class: matter and materials","Target class: light, sound and electricity"]'),
  ('Class 5', 'Social Studies','["Indian geography","Freedom movement","Democracy and citizenship","World geography (intro)","Previous class: maps and early civilisations","Target class: resources and Indian polity"]'),
  ('Class 6', 'English',   '["Prose and poetry comprehension","Grammar: clauses and voice","Vocabulary and idioms","Notice and letter writing","Previous class: advanced composition","Target class: literary devices and analytical writing"]'),
  ('Class 6', 'Mathematics','["Integers and fractions","Algebra (intro)","Ratio and proportion","Mensuration and data handling","Previous class: percentage and averages","Target class: linear equations and geometry"]'),
  ('Class 6', 'Science',   '["Food and its components","Separation of substances","Plants and body movements","Light and electricity","Previous class: force and energy","Target class: living organisms and magnets"]'),
  ('Class 6', 'Social Studies','["Ancient India","Our past and archaeology","Maps and globe","Local government","Previous class: Indian geography and freedom movement","Target class: early empires and democracy"]'),
  ('Class 7', 'English',   '["Comprehension and summary","Grammar: reported speech","Poetry appreciation","Article and diary writing","Previous class: clauses and voice","Target class: critical reading and debate"]'),
  ('Class 7', 'Mathematics','["Rational numbers","Exponents and powers","Algebraic expressions","Geometry and mensuration","Previous class: linear equations","Target class: percentage, profit/loss and data handling"]'),
  ('Class 7', 'Science',   '["Nutrition in plants and animals","Heat and acids/bases","Motion and time","Light and reproduction in plants","Previous class: living organisms and magnets","Target class: weather, climate and electric current"]'),
  ('Class 7', 'Social Studies','["Medieval India","Environment and geography","State government","Gender and equality","Previous class: ancient India and local government","Target class: regional empires and resources"]'),
  ('Class 8', 'English',   '["Reading comprehension","Grammar: determiners and modals","Letter and story writing","Literature analysis","Previous class: reported speech and debate","Target class: persuasive writing and literary criticism"]'),
  ('Class 8', 'Mathematics','["Rational numbers and squares/cubes","Linear equations","Quadrilaterals and practical geometry","Mensuration and graphs","Previous class: algebraic expressions","Target class: factorisation and compound interest"]'),
  ('Class 8', 'Science',   '["Crop production and microorganisms","Synthetic fibres and metals","Force, pressure and friction","Cell structure and light","Previous class: heat, motion and electricity","Target class: sound, chemical effects and stars"]'),
  ('Class 8', 'Social Studies','["Modern India and British rule","Resources and agriculture","Indian Constitution","Social justice","Previous class: medieval India and state government","Target class: freedom struggle and industrialisation"]'),
  ('Class 9', 'English',   '["Prose, poetry and drama","Grammar and editing","Descriptive and narrative writing","Reading for inference","Previous class: persuasive writing","Target class: literary analysis and formal writing"]'),
  ('Class 9', 'Mathematics','["Number systems and polynomials","Coordinate geometry","Linear equations and triangles","Surface areas and statistics","Previous class: factorisation and mensuration","Target class: quadrilaterals, circles and probability"]'),
  ('Class 9', 'Science',   '["Matter and atoms","Cell and tissues","Motion, force and gravitation","Sound and work/energy","Previous class: light and chemical effects","Target class: diversity in living organisms and natural resources"]'),
  ('Class 9', 'Social Studies','["French Revolution and socialism","Physical features of India","Democracy and elections","Poverty and food security","Previous class: freedom struggle and Constitution","Target class: Nazism, drainage and electoral politics"]'),
  ('Class 10', 'English',  '["Comprehension and literary analysis","Grammar and vocabulary","Formal letter and analytical paragraph","Poetry and drama appreciation","Previous class: literary analysis and narrative writing","Target class: board-style long answers and precis"]'),
  ('Class 10', 'Mathematics','["Real numbers and polynomials","Quadratic equations and arithmetic progressions","Triangles, circles and trigonometry","Statistics and probability","Previous class: coordinate geometry and surface areas","Target class: applications and board-level problems"]'),
  ('Class 10', 'Science',  '["Chemical reactions and acids/bases","Life processes and heredity","Electricity and magnetic effects","Light and human eye","Previous class: matter, motion and natural resources","Target class: carbon compounds and environment"]'),
  ('Class 10', 'Social Studies','["Nationalism in India and Europe","Resources and development","Federalism and political parties","Money, credit and globalisation","Previous class: democracy and social justice","Target class: board-style map work and case studies"]'),
  ('Class 11', 'English',  '["Reading and note-making","Grammar and editing","Essay and report writing","Literature (prose/poetry/drama)","Previous class: board-level analytical writing","Target class: research-based writing and literary criticism"]'),
  ('Class 11', 'Mathematics','["Sets, relations and functions","Trigonometric functions","Complex numbers and sequences","Straight lines and conic sections","Previous class: quadratic equations and probability","Target class: permutations, binomial theorem and limits"]'),
  ('Class 11', 'Physics',  '["Units, motion and laws of motion","Work, energy and rotational motion","Gravitation and thermodynamics","Oscillations and waves","Previous class: mechanics and electricity basics","Target class: kinetic theory and waves"]'),
  ('Class 11', 'Chemistry','["Atomic structure and chemical bonding","States of matter and thermodynamics","Equilibrium and redox reactions","Organic chemistry basics","Previous class: chemical reactions and carbon compounds","Target class: hydrocarbons and environmental chemistry"]'),
  ('Class 11', 'Biology',  '["Diversity of living organisms","Plant and animal physiology","Cell cycle and biomolecules","Human physiology basics","Previous class: life processes and heredity","Target class: transport, respiration and excretion"]'),
  ('Class 12', 'English',  '["Comprehension and inference","Advanced grammar and editing","Essay, report and letter writing","Literature analysis","Previous class: research writing and criticism","Target class: board-style long answers and unseen passages"]'),
  ('Class 12', 'Mathematics','["Relations, functions and inverse trigonometry","Matrices, determinants and continuity","Application of derivatives and integrals","Differential equations and vectors","Previous class: limits and conic sections","Target class: 3D geometry, linear programming and probability"]'),
  ('Class 12', 'Physics',  '["Electrostatics and current electricity","Magnetic effects and alternating current","Optics and dual nature of matter","Atoms, nuclei and semiconductors","Previous class: mechanics, waves and thermodynamics","Target class: modern physics and electronic devices"]'),
  ('Class 12', 'Chemistry','["Solutions and electrochemistry","Chemical kinetics and surface chemistry","p-Block and d-Block elements","Aldehydes, ketones and biomolecules","Previous class: organic basics and equilibrium","Target class: coordination compounds and polymers"]'),
  ('Class 12', 'Biology',  '["Reproduction in plants and humans","Genetics and evolution","Human health and disease","Biotechnology and ecology","Previous class: plant/animal physiology","Target class: applied biology and ecosystem dynamics"]')
) AS v(class_name, subject, topics)
WHERE NOT EXISTS (
  SELECT 1 FROM school_entrance_exam_subjects s
  WHERE s.class_name = v.class_name
);

-- 7. Verification helper -----------------------------------------------------
-- SELECT class_name, subject, weightage, topics
-- FROM school_entrance_exam_subjects
-- ORDER BY class_name, subject;
