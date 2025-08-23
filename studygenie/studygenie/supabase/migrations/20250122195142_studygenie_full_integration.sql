-- Location: supabase/migrations/20250122195142_studygenie_full_integration.sql
-- StudyGenie - Complete Supabase Integration
-- Authentication, User Management, Progress Tracking, Study Materials & Gamification

-- ================================
-- 1. CUSTOM TYPES
-- ================================
CREATE TYPE public.user_role AS ENUM ('admin', 'instructor', 'student');
CREATE TYPE public.academic_level AS ENUM ('high-school', 'undergraduate', 'graduate', 'postgraduate', 'professional');
CREATE TYPE public.study_material_type AS ENUM ('pdf', 'image', 'handwritten_notes', 'text');
CREATE TYPE public.difficulty_level AS ENUM ('kid-friendly', 'simple', 'exam-mode');
CREATE TYPE public.quiz_type AS ENUM ('multiple_choice', 'true_false', 'short_answer', 'essay');
CREATE TYPE public.content_type AS ENUM ('summary', 'flashcard', 'quiz', 'note');
CREATE TYPE public.processing_status AS ENUM ('pending', 'processing', 'completed', 'failed');

-- ================================
-- 2. CORE TABLES
-- ================================

-- User profiles table (critical intermediary for PostgREST compatibility)
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT NOT NULL,
    role public.user_role DEFAULT 'student'::public.user_role,
    academic_level public.academic_level,
    avatar_url TEXT,
    xp_points INTEGER DEFAULT 0,
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_study_date DATE,
    is_active BOOLEAN DEFAULT true,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Study materials (PDFs, images, notes uploaded by users)
CREATE TABLE public.study_materials (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    file_path TEXT, -- Path to storage bucket
    material_type public.study_material_type NOT NULL,
    processing_status public.processing_status DEFAULT 'pending',
    extracted_text TEXT, -- OCR extracted text
    word_count INTEGER DEFAULT 0,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- AI-generated content (summaries, flashcards, quizzes)
CREATE TABLE public.generated_content (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    material_id UUID REFERENCES public.study_materials(id) ON DELETE CASCADE,
    content_type public.content_type NOT NULL,
    difficulty_level public.difficulty_level NOT NULL,
    title TEXT NOT NULL,
    content JSONB NOT NULL, -- Flexible content storage
    tags TEXT[] DEFAULT '{}',
    is_favorite BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Quizzes and assessments
CREATE TABLE public.quizzes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    material_id UUID REFERENCES public.study_materials(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    quiz_type public.quiz_type NOT NULL,
    questions JSONB NOT NULL, -- Array of question objects
    time_limit INTEGER, -- In minutes
    passing_score INTEGER DEFAULT 70,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Quiz attempts and results
CREATE TABLE public.quiz_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    quiz_id UUID REFERENCES public.quizzes(id) ON DELETE CASCADE,
    answers JSONB NOT NULL, -- User answers
    score INTEGER NOT NULL,
    time_taken INTEGER, -- In seconds
    completed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Study sessions tracking
CREATE TABLE public.study_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    material_id UUID REFERENCES public.study_materials(id) ON DELETE SET NULL,
    session_type TEXT NOT NULL, -- 'reading', 'quiz', 'flashcards', etc.
    duration INTEGER NOT NULL, -- In seconds
    xp_earned INTEGER DEFAULT 0,
    session_data JSONB DEFAULT '{}', -- Additional session metadata
    started_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMPTZ
);

-- Achievements system
CREATE TABLE public.achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    icon TEXT,
    xp_reward INTEGER DEFAULT 0,
    criteria JSONB NOT NULL, -- Achievement unlock criteria
    category TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- User achievements (junction table)
CREATE TABLE public.user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    achievement_id UUID REFERENCES public.achievements(id) ON DELETE CASCADE,
    earned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, achievement_id)
);

-- Flashcards for spaced repetition
CREATE TABLE public.flashcards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    material_id UUID REFERENCES public.study_materials(id) ON DELETE CASCADE,
    front_text TEXT NOT NULL,
    back_text TEXT NOT NULL,
    difficulty_score DECIMAL(3,2) DEFAULT 1.0, -- For spaced repetition algorithm
    next_review_date DATE DEFAULT CURRENT_DATE,
    review_count INTEGER DEFAULT 0,
    correct_count INTEGER DEFAULT 0,
    tags TEXT[] DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Learning analytics
CREATE TABLE public.learning_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.user_profiles(id) ON DELETE CASCADE,
    date DATE DEFAULT CURRENT_DATE,
    study_time INTEGER DEFAULT 0, -- In seconds
    materials_processed INTEGER DEFAULT 0,
    quizzes_taken INTEGER DEFAULT 0,
    average_score DECIMAL(5,2),
    xp_gained INTEGER DEFAULT 0,
    streak_maintained BOOLEAN DEFAULT false,
    analytics_data JSONB DEFAULT '{}',
    UNIQUE(user_id, date)
);

-- ================================
-- 3. STORAGE BUCKETS
-- ================================

-- Study materials storage (private)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'study-materials',
    'study-materials',
    false,
    52428800, -- 50MB limit
    ARRAY['application/pdf', 'image/jpeg', 'image/png', 'image/webp', 'image/jpg', 'text/plain']
);

-- Profile images storage (public for avatars)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'profile-images',
    'profile-images',
    true,
    5242880, -- 5MB limit
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
);

-- ================================
-- 4. INDEXES
-- ================================
CREATE INDEX idx_user_profiles_email ON public.user_profiles(email);
CREATE INDEX idx_user_profiles_role ON public.user_profiles(role);
CREATE INDEX idx_study_materials_user_id ON public.study_materials(user_id);
CREATE INDEX idx_study_materials_type ON public.study_materials(material_type);
CREATE INDEX idx_study_materials_status ON public.study_materials(processing_status);
CREATE INDEX idx_generated_content_user_id ON public.generated_content(user_id);
CREATE INDEX idx_generated_content_material_id ON public.generated_content(material_id);
CREATE INDEX idx_generated_content_type ON public.generated_content(content_type);
CREATE INDEX idx_quizzes_user_id ON public.quizzes(user_id);
CREATE INDEX idx_quiz_attempts_user_id ON public.quiz_attempts(user_id);
CREATE INDEX idx_quiz_attempts_quiz_id ON public.quiz_attempts(quiz_id);
CREATE INDEX idx_study_sessions_user_id ON public.study_sessions(user_id);
CREATE INDEX idx_study_sessions_date ON public.study_sessions(started_at);
CREATE INDEX idx_user_achievements_user_id ON public.user_achievements(user_id);
CREATE INDEX idx_flashcards_user_id ON public.flashcards(user_id);
CREATE INDEX idx_flashcards_review_date ON public.flashcards(next_review_date);
CREATE INDEX idx_learning_analytics_user_id ON public.learning_analytics(user_id);
CREATE INDEX idx_learning_analytics_date ON public.learning_analytics(date);

-- ================================
-- 5. FUNCTIONS
-- ================================

-- Function for automatic profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO public.user_profiles (id, email, full_name, role, academic_level)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
        COALESCE(NEW.raw_user_meta_data->>'role', 'student')::public.user_role,
        COALESCE(NEW.raw_user_meta_data->>'academic_level', 'undergraduate')::public.academic_level
    );
    RETURN NEW;
END;
$$;

-- Function to update user XP and streaks
CREATE OR REPLACE FUNCTION public.update_user_progress(
    user_uuid UUID,
    xp_to_add INTEGER,
    session_date DATE DEFAULT CURRENT_DATE
)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    last_study DATE;
    current_streak_val INTEGER;
BEGIN
    -- Get current user data
    SELECT last_study_date, current_streak
    INTO last_study, current_streak_val
    FROM public.user_profiles
    WHERE id = user_uuid;

    -- Update XP
    UPDATE public.user_profiles
    SET xp_points = xp_points + xp_to_add,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = user_uuid;

    -- Update streak logic
    IF last_study IS NULL OR last_study < session_date - INTERVAL '1 day' THEN
        -- Reset or start streak
        IF last_study = session_date - INTERVAL '1 day' THEN
            -- Continue streak
            UPDATE public.user_profiles
            SET current_streak = current_streak + 1,
                longest_streak = GREATEST(longest_streak, current_streak + 1),
                last_study_date = session_date
            WHERE id = user_uuid;
        ELSE
            -- Reset streak
            UPDATE public.user_profiles
            SET current_streak = 1,
                longest_streak = GREATEST(longest_streak, 1),
                last_study_date = session_date
            WHERE id = user_uuid;
        END IF;
    END IF;
END;
$$;

-- Function to check achievements
CREATE OR REPLACE FUNCTION public.check_achievements(user_uuid UUID)
RETURNS VOID
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    achievement_record RECORD;
    user_data RECORD;
    criteria_met BOOLEAN;
BEGIN
    -- Get user data
    SELECT up.*, 
           COUNT(sm.id) as material_count,
           COUNT(qa.id) as quiz_count,
           AVG(qa.score) as avg_score
    INTO user_data
    FROM public.user_profiles up
    LEFT JOIN public.study_materials sm ON up.id = sm.user_id
    LEFT JOIN public.quiz_attempts qa ON up.id = qa.user_id
    WHERE up.id = user_uuid
    GROUP BY up.id;

    -- Check each achievement
    FOR achievement_record IN 
        SELECT a.*
        FROM public.achievements a
        WHERE a.is_active = true
        AND a.id NOT IN (
            SELECT ua.achievement_id
            FROM public.user_achievements ua
            WHERE ua.user_id = user_uuid
        )
    LOOP
        criteria_met := false;

        -- Simple criteria checking (extend as needed)
        CASE achievement_record.category
            WHEN 'xp' THEN
                IF user_data.xp_points >= (achievement_record.criteria->>'required_xp')::INTEGER THEN
                    criteria_met := true;
                END IF;
            WHEN 'streak' THEN
                IF user_data.current_streak >= (achievement_record.criteria->>'required_streak')::INTEGER THEN
                    criteria_met := true;
                END IF;
            WHEN 'materials' THEN
                IF user_data.material_count >= (achievement_record.criteria->>'required_materials')::INTEGER THEN
                    criteria_met := true;
                END IF;
        END CASE;

        -- Award achievement if criteria met
        IF criteria_met THEN
            INSERT INTO public.user_achievements (user_id, achievement_id)
            VALUES (user_uuid, achievement_record.id);

            -- Award XP if specified
            IF achievement_record.xp_reward > 0 THEN
                UPDATE public.user_profiles
                SET xp_points = xp_points + achievement_record.xp_reward
                WHERE id = user_uuid;
            END IF;
        END IF;
    END LOOP;
END;
$$;

-- ================================
-- 6. TRIGGERS
-- ================================

-- Trigger for new user creation
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Trigger to update user profiles timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_study_materials_updated_at
    BEFORE UPDATE ON public.study_materials
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- ================================
-- 7. ROW LEVEL SECURITY
-- ================================
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.generated_content ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.flashcards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.learning_analytics ENABLE ROW LEVEL SECURITY;

-- ================================
-- 8. RLS POLICIES
-- ================================

-- Pattern 1: Core user table (user_profiles)
CREATE POLICY "users_manage_own_user_profiles"
ON public.user_profiles
FOR ALL
TO authenticated
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Pattern 2: Simple user ownership for most tables
CREATE POLICY "users_manage_own_study_materials"
ON public.study_materials
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_generated_content"
ON public.generated_content
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_quizzes"
ON public.quizzes
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_quiz_attempts"
ON public.quiz_attempts
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_study_sessions"
ON public.study_sessions
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_user_achievements"
ON public.user_achievements
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_flashcards"
ON public.flashcards
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "users_manage_own_learning_analytics"
ON public.learning_analytics
FOR ALL
TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Pattern 4: Public read for achievements (everyone can see available achievements)
CREATE POLICY "public_can_read_achievements"
ON public.achievements
FOR SELECT
TO public
USING (true);

-- Admin can manage achievements
CREATE OR REPLACE FUNCTION public.is_admin_from_auth()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
SELECT EXISTS (
    SELECT 1 FROM auth.users au
    WHERE au.id = auth.uid() 
    AND (au.raw_user_meta_data->>'role' = 'admin' 
         OR au.raw_app_meta_data->>'role' = 'admin')
)
$$;

CREATE POLICY "admins_manage_achievements"
ON public.achievements
FOR ALL
TO authenticated
USING (public.is_admin_from_auth())
WITH CHECK (public.is_admin_from_auth());

-- ================================
-- 9. STORAGE RLS POLICIES
-- ================================

-- Study materials storage policies (private)
CREATE POLICY "users_view_own_study_files"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'study-materials' AND owner = auth.uid());

CREATE POLICY "users_upload_own_study_files"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'study-materials' 
    AND owner = auth.uid()
    AND (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "users_update_own_study_files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'study-materials' AND owner = auth.uid())
WITH CHECK (bucket_id = 'study-materials' AND owner = auth.uid());

CREATE POLICY "users_delete_own_study_files"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'study-materials' AND owner = auth.uid());

-- Profile images storage policies (public)
CREATE POLICY "public_can_view_profile_images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'profile-images');

CREATE POLICY "authenticated_users_upload_profile_images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'profile-images');

CREATE POLICY "owners_manage_profile_images"
ON storage.objects
FOR UPDATE, DELETE
TO authenticated
USING (bucket_id = 'profile-images' AND owner = auth.uid());

-- ================================
-- 10. SAMPLE ACHIEVEMENTS
-- ================================
INSERT INTO public.achievements (name, description, icon, xp_reward, criteria, category) VALUES
('First Steps', 'Upload your first study material', '🎯', 50, '{"required_materials": 1}', 'materials'),
('Study Buddy', 'Complete your first quiz', '📚', 100, '{"required_quizzes": 1}', 'quiz'),
('Rising Star', 'Earn 500 XP points', '⭐', 200, '{"required_xp": 500}', 'xp'),
('Consistent Learner', 'Maintain a 7-day study streak', '🔥', 300, '{"required_streak": 7}', 'streak'),
('Knowledge Seeker', 'Upload 10 study materials', '📖', 500, '{"required_materials": 10}', 'materials'),
('Quiz Master', 'Score 90% or higher on 5 quizzes', '🏆', 750, '{"required_score": 90, "required_count": 5}', 'quiz'),
('Dedicated Student', 'Maintain a 30-day study streak', '💎', 1000, '{"required_streak": 30}', 'streak'),
('XP Champion', 'Earn 5000 XP points', '👑', 1500, '{"required_xp": 5000}', 'xp');

-- ================================
-- 11. MOCK DATA
-- ================================
DO $$
DECLARE
    student_uuid UUID := gen_random_uuid();
    instructor_uuid UUID := gen_random_uuid();
    material_uuid UUID := gen_random_uuid();
    quiz_uuid UUID := gen_random_uuid();
BEGIN
    -- Create complete auth.users records with all fields
    INSERT INTO auth.users (
        id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
        created_at, updated_at, raw_user_meta_data, raw_app_meta_data,
        is_sso_user, is_anonymous, confirmation_token, confirmation_sent_at,
        recovery_token, recovery_sent_at, email_change_token_new, email_change,
        email_change_sent_at, email_change_token_current, email_change_confirm_status,
        reauthentication_token, reauthentication_sent_at, phone, phone_change,
        phone_change_token, phone_change_sent_at
    ) VALUES
        (student_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'student@studygenie.com', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "John Student", "academic_level": "undergraduate"}'::jsonb, 
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null),
        (instructor_uuid, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
         'instructor@studygenie.com', crypt('password123', gen_salt('bf', 10)), now(), now(), now(),
         '{"full_name": "Dr. Sarah Wilson", "role": "instructor"}'::jsonb, 
         '{"provider": "email", "providers": ["email"]}'::jsonb,
         false, false, '', null, '', null, '', '', null, '', 0, '', null, null, '', '', null);

    -- Create sample study material
    INSERT INTO public.study_materials (id, user_id, title, description, material_type, processing_status, extracted_text, word_count)
    VALUES (
        material_uuid,
        student_uuid,
        'Introduction to Machine Learning',
        'Comprehensive guide to ML fundamentals',
        'pdf',
        'completed',
        'Machine learning is a subset of artificial intelligence that focuses on algorithms that can learn from data...',
        1500
    );

    -- Create sample generated content
    INSERT INTO public.generated_content (user_id, material_id, content_type, difficulty_level, title, content, tags)
    VALUES
        (student_uuid, material_uuid, 'summary', 'simple', 'ML Basics Summary',
         '{"summary": "Machine learning uses algorithms to find patterns in data and make predictions..."}'::jsonb,
         ARRAY['machine-learning', 'ai', 'algorithms']),
        (student_uuid, material_uuid, 'flashcard', 'simple', 'ML Flashcards',
         '{"cards": [{"front": "What is Machine Learning?", "back": "A subset of AI that learns from data"}]}'::jsonb,
         ARRAY['machine-learning', 'definitions']);

    -- Create sample quiz
    INSERT INTO public.quizzes (id, user_id, material_id, title, description, quiz_type, questions)
    VALUES (
        quiz_uuid,
        student_uuid,
        material_uuid,
        'ML Fundamentals Quiz',
        'Test your knowledge of machine learning basics',
        'multiple_choice',
        '{"questions": [{"question": "What is Machine Learning?", "options": ["A type of hardware", "A subset of AI", "A programming language", "A database"], "correct": 1, "explanation": "Machine learning is indeed a subset of artificial intelligence."}]}'::jsonb
    );

    -- Create sample quiz attempt
    INSERT INTO public.quiz_attempts (user_id, quiz_id, answers, score, time_taken)
    VALUES (
        student_uuid,
        quiz_uuid,
        '{"answers": [1]}'::jsonb,
        100,
        120
    );

    -- Create sample study session
    INSERT INTO public.study_sessions (user_id, material_id, session_type, duration, xp_earned)
    VALUES (
        student_uuid,
        material_uuid,
        'reading',
        1800, -- 30 minutes
        150
    );

    -- Create sample flashcards
    INSERT INTO public.flashcards (user_id, material_id, front_text, back_text, tags)
    VALUES
        (student_uuid, material_uuid, 'What is supervised learning?', 'Learning with labeled training data', ARRAY['supervised-learning']),
        (student_uuid, material_uuid, 'What is unsupervised learning?', 'Learning patterns from unlabeled data', ARRAY['unsupervised-learning']);

    -- Award some achievements
    INSERT INTO public.user_achievements (user_id, achievement_id)
    SELECT student_uuid, id
    FROM public.achievements
    WHERE name IN ('First Steps', 'Study Buddy');

    -- Update user XP and progress
    PERFORM public.update_user_progress(student_uuid, 500, CURRENT_DATE);

    -- Create learning analytics entry
    INSERT INTO public.learning_analytics (user_id, date, study_time, materials_processed, quizzes_taken, average_score, xp_gained)
    VALUES (
        student_uuid,
        CURRENT_DATE,
        1800, -- 30 minutes
        1,
        1,
        100.0,
        500
    );

EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key error: %', SQLERRM;
    WHEN unique_violation THEN
        RAISE NOTICE 'Unique constraint error: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Unexpected error: %', SQLERRM;
END $$;

-- ================================
-- 12. UTILITY FUNCTIONS FOR CLEANUP (DEVELOPMENT ONLY)
-- ================================
CREATE OR REPLACE FUNCTION public.cleanup_studygenie_data()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    auth_user_ids_to_delete UUID[];
BEGIN
    -- Get StudyGenie test user IDs
    SELECT ARRAY_AGG(id) INTO auth_user_ids_to_delete
    FROM auth.users
    WHERE email LIKE '%@studygenie.com';

    -- Delete in dependency order (children first)
    DELETE FROM public.learning_analytics WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.flashcards WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.user_achievements WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.study_sessions WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.quiz_attempts WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.quizzes WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.generated_content WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.study_materials WHERE user_id = ANY(auth_user_ids_to_delete);
    DELETE FROM public.user_profiles WHERE id = ANY(auth_user_ids_to_delete);
    
    -- Delete auth.users last
    DELETE FROM auth.users WHERE id = ANY(auth_user_ids_to_delete);

    RAISE NOTICE 'StudyGenie test data cleanup completed';
EXCEPTION
    WHEN foreign_key_violation THEN
        RAISE NOTICE 'Foreign key constraint prevents deletion: %', SQLERRM;
    WHEN OTHERS THEN
        RAISE NOTICE 'Cleanup failed: %', SQLERRM;
END;
$$;