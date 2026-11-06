-- Optional persistent demo quiz for the School ERP student practice area.
-- The app also includes this quiz as an offline-safe fallback.
INSERT INTO public.school_quizzes
  (id, class_id, class_name, subject, title, duration_minutes,
   total_questions, weightage_percent, questions, created_by)
VALUES
  (
    '00000000-0000-4000-8000-000000000001',
    'demo',
    'All Classes',
    'Science',
    'Science Basics: Demo Practice Quiz',
    5,
    5,
    0,
    '[
      {"question":"Which part of a plant absorbs water from the soil?","options":["Leaf","Root","Flower","Stem"],"correct_index":1},
      {"question":"What is the main source of energy for Earth?","options":["The Moon","The Sun","Wind","Coal"],"correct_index":1},
      {"question":"Water changes into vapour during which process?","options":["Freezing","Melting","Evaporation","Condensation"],"correct_index":2},
      {"question":"Which organ pumps blood around the human body?","options":["Lungs","Brain","Heart","Stomach"],"correct_index":2},
      {"question":"Which material is attracted to a magnet?","options":["Wood","Plastic","Iron","Glass"],"correct_index":2}
    ]'::jsonb,
    'system'
  )
ON CONFLICT (id) DO UPDATE SET
  title = EXCLUDED.title,
  questions = EXCLUDED.questions,
  duration_minutes = EXCLUDED.duration_minutes,
  total_questions = EXCLUDED.total_questions;
