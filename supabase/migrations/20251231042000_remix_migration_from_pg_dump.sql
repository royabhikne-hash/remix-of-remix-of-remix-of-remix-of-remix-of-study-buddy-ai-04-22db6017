CREATE EXTENSION IF NOT EXISTS "pg_cron";
CREATE EXTENSION IF NOT EXISTS "pg_graphql";
CREATE EXTENSION IF NOT EXISTS "pg_net";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "plpgsql";
CREATE EXTENSION IF NOT EXISTS "supabase_vault";
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";
BEGIN;

--
-- PostgreSQL database dump
--


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
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: admin_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.admin_role AS ENUM (
    'super_admin',
    'admin'
);


--
-- Name: board_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.board_type AS ENUM (
    'CBSE',
    'ICSE',
    'Bihar Board',
    'Other'
);


--
-- Name: improvement_trend; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.improvement_trend AS ENUM (
    'up',
    'down',
    'stable'
);


--
-- Name: understanding_level; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.understanding_level AS ENUM (
    'weak',
    'average',
    'good',
    'excellent'
);


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    SET search_path TO 'public'
    AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;


SET default_table_access_method = heap;

--
-- Name: admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    admin_id text NOT NULL,
    password_hash text NOT NULL,
    name text NOT NULL,
    role public.admin_role DEFAULT 'admin'::public.admin_role NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: chat_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.chat_messages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    role text NOT NULL,
    content text NOT NULL,
    image_url text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT chat_messages_role_check CHECK ((role = ANY (ARRAY['user'::text, 'assistant'::text])))
);


--
-- Name: parent_reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.parent_reports (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    student_id uuid NOT NULL,
    report_type text DEFAULT 'weekly'::text NOT NULL,
    report_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    pdf_url text,
    sent_at timestamp with time zone,
    sent_to text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    created_by_type text,
    CONSTRAINT parent_reports_created_by_type_check CHECK ((created_by_type = ANY (ARRAY['admin'::text, 'school'::text])))
);


--
-- Name: quiz_attempts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.quiz_attempts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    session_id uuid NOT NULL,
    student_id uuid NOT NULL,
    questions jsonb DEFAULT '[]'::jsonb NOT NULL,
    answers jsonb DEFAULT '[]'::jsonb NOT NULL,
    correct_count integer DEFAULT 0 NOT NULL,
    total_questions integer DEFAULT 0 NOT NULL,
    accuracy_percentage numeric(5,2) DEFAULT 0,
    understanding_result text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT quiz_attempts_understanding_result_check CHECK ((understanding_result = ANY (ARRAY['strong'::text, 'partial'::text, 'weak'::text])))
);


--
-- Name: schools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schools (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    school_id text NOT NULL,
    password_hash text NOT NULL,
    district text,
    state text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    is_banned boolean DEFAULT false,
    fee_paid boolean DEFAULT true,
    email text,
    contact_whatsapp text
);


--
-- Name: students; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.students (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    photo_url text,
    full_name text NOT NULL,
    phone text NOT NULL,
    parent_whatsapp text NOT NULL,
    class text NOT NULL,
    age integer NOT NULL,
    board public.board_type DEFAULT 'CBSE'::public.board_type NOT NULL,
    school_id uuid,
    district text NOT NULL,
    state text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    is_approved boolean DEFAULT false NOT NULL,
    approved_at timestamp with time zone,
    approved_by uuid,
    rejection_reason text,
    is_banned boolean DEFAULT false
);


--
-- Name: study_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.study_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    student_id uuid NOT NULL,
    start_time timestamp with time zone DEFAULT now() NOT NULL,
    end_time timestamp with time zone,
    topic text DEFAULT 'General Study'::text NOT NULL,
    subject text,
    time_spent integer DEFAULT 0,
    understanding_level public.understanding_level DEFAULT 'average'::public.understanding_level,
    weak_areas text[] DEFAULT '{}'::text[],
    strong_areas text[] DEFAULT '{}'::text[],
    improvement_score integer DEFAULT 50,
    ai_summary text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admins admins_admin_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_admin_id_key UNIQUE (admin_id);


--
-- Name: admins admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admins
    ADD CONSTRAINT admins_pkey PRIMARY KEY (id);


--
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


--
-- Name: parent_reports parent_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_reports
    ADD CONSTRAINT parent_reports_pkey PRIMARY KEY (id);


--
-- Name: quiz_attempts quiz_attempts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quiz_attempts
    ADD CONSTRAINT quiz_attempts_pkey PRIMARY KEY (id);


--
-- Name: schools schools_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT schools_pkey PRIMARY KEY (id);


--
-- Name: schools schools_school_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schools
    ADD CONSTRAINT schools_school_id_key UNIQUE (school_id);


--
-- Name: students students_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_pkey PRIMARY KEY (id);


--
-- Name: students students_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_user_id_key UNIQUE (user_id);


--
-- Name: study_sessions study_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_sessions
    ADD CONSTRAINT study_sessions_pkey PRIMARY KEY (id);


--
-- Name: idx_schools_banned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_schools_banned ON public.schools USING btree (is_banned);


--
-- Name: idx_schools_fee_paid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_schools_fee_paid ON public.schools USING btree (fee_paid);


--
-- Name: idx_students_approval; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_students_approval ON public.students USING btree (school_id, is_approved);


--
-- Name: idx_students_banned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_students_banned ON public.students USING btree (is_banned);


--
-- Name: students update_students_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_students_updated_at BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: chat_messages chat_messages_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.study_sessions(id) ON DELETE CASCADE;


--
-- Name: parent_reports parent_reports_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.parent_reports
    ADD CONSTRAINT parent_reports_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: quiz_attempts quiz_attempts_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quiz_attempts
    ADD CONSTRAINT quiz_attempts_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.study_sessions(id) ON DELETE CASCADE;


--
-- Name: quiz_attempts quiz_attempts_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.quiz_attempts
    ADD CONSTRAINT quiz_attempts_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: students students_school_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.students
    ADD CONSTRAINT students_school_id_fkey FOREIGN KEY (school_id) REFERENCES public.schools(id);


--
-- Name: study_sessions study_sessions_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.study_sessions
    ADD CONSTRAINT study_sessions_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE;


--
-- Name: admins Admins viewable for login; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Admins viewable for login" ON public.admins FOR SELECT USING (true);


--
-- Name: parent_reports Anyone can insert parent reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can insert parent reports" ON public.parent_reports FOR INSERT WITH CHECK (true);


--
-- Name: parent_reports Anyone can update parent reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can update parent reports" ON public.parent_reports FOR UPDATE USING (true);


--
-- Name: parent_reports Anyone can view parent reports; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view parent reports" ON public.parent_reports FOR SELECT USING (true);


--
-- Name: quiz_attempts Anyone can view quiz attempts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view quiz attempts" ON public.quiz_attempts FOR SELECT USING (true);


--
-- Name: study_sessions Anyone can view sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view sessions" ON public.study_sessions FOR SELECT USING (true);


--
-- Name: schools Schools are viewable by everyone; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Schools are viewable by everyone" ON public.schools FOR SELECT USING (true);


--
-- Name: students Schools can view their students; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Schools can view their students" ON public.students FOR SELECT USING (true);


--
-- Name: students Students can insert own data; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can insert own data" ON public.students FOR INSERT WITH CHECK ((auth.uid() = user_id));


--
-- Name: chat_messages Students can insert own messages; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can insert own messages" ON public.chat_messages FOR INSERT WITH CHECK ((session_id IN ( SELECT ss.id
   FROM (public.study_sessions ss
     JOIN public.students s ON ((ss.student_id = s.id)))
  WHERE (s.user_id = auth.uid()))));


--
-- Name: quiz_attempts Students can insert own quiz attempts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can insert own quiz attempts" ON public.quiz_attempts FOR INSERT WITH CHECK ((student_id IN ( SELECT students.id
   FROM public.students
  WHERE (students.user_id = auth.uid()))));


--
-- Name: study_sessions Students can insert own sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can insert own sessions" ON public.study_sessions FOR INSERT WITH CHECK ((student_id IN ( SELECT students.id
   FROM public.students
  WHERE (students.user_id = auth.uid()))));


--
-- Name: students Students can update own data; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can update own data" ON public.students FOR UPDATE USING ((auth.uid() = user_id));


--
-- Name: study_sessions Students can update own sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can update own sessions" ON public.study_sessions FOR UPDATE USING ((student_id IN ( SELECT students.id
   FROM public.students
  WHERE (students.user_id = auth.uid()))));


--
-- Name: students Students can view own data; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can view own data" ON public.students FOR SELECT USING ((auth.uid() = user_id));


--
-- Name: chat_messages Students can view own messages; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can view own messages" ON public.chat_messages FOR SELECT USING ((session_id IN ( SELECT ss.id
   FROM (public.study_sessions ss
     JOIN public.students s ON ((ss.student_id = s.id)))
  WHERE (s.user_id = auth.uid()))));


--
-- Name: quiz_attempts Students can view own quiz attempts; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can view own quiz attempts" ON public.quiz_attempts FOR SELECT USING ((student_id IN ( SELECT students.id
   FROM public.students
  WHERE (students.user_id = auth.uid()))));


--
-- Name: study_sessions Students can view own sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can view own sessions" ON public.study_sessions FOR SELECT USING ((student_id IN ( SELECT students.id
   FROM public.students
  WHERE (students.user_id = auth.uid()))));


--
-- Name: admins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;

--
-- Name: chat_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: parent_reports; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.parent_reports ENABLE ROW LEVEL SECURITY;

--
-- Name: quiz_attempts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;

--
-- Name: schools; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;

--
-- Name: students; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

--
-- Name: study_sessions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.study_sessions ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--




COMMIT;