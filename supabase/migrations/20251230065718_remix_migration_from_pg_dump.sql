CREATE EXTENSION IF NOT EXISTS "pg_cron" WITH SCHEMA "pg_catalog";
CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";
CREATE EXTENSION IF NOT EXISTS "pg_net" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";
CREATE EXTENSION IF NOT EXISTS "plpgsql" WITH SCHEMA "pg_catalog";
CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";
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
-- Name: schools; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schools (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name text NOT NULL,
    school_id text NOT NULL,
    password_hash text NOT NULL,
    district text,
    state text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
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
    updated_at timestamp with time zone DEFAULT now() NOT NULL
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
-- Name: chat_messages chat_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_pkey PRIMARY KEY (id);


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
-- Name: students update_students_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_students_updated_at BEFORE UPDATE ON public.students FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: chat_messages chat_messages_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.chat_messages
    ADD CONSTRAINT chat_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.study_sessions(id) ON DELETE CASCADE;


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
-- Name: study_sessions Students can view own sessions; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Students can view own sessions" ON public.study_sessions FOR SELECT USING ((student_id IN ( SELECT students.id
   FROM public.students
  WHERE (students.user_id = auth.uid()))));


--
-- Name: chat_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

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