import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { action, session_token, user_type, school_id, student_id, student_class } = await req.json();

    // Create admin client to bypass RLS
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // Handle student report data request
    if (action === 'get_student_report') {
      // Verify session - either school or admin
      let isAuthorized = false;
      
      if (user_type === 'school' && school_id) {
        const { data: school } = await supabaseAdmin
          .from('schools')
          .select('id')
          .eq('id', school_id)
          .maybeSingle();
        isAuthorized = !!school;
      } else if (user_type === 'admin') {
        const adminId = session_token?.split('_')[1];
        const { data: admin } = await supabaseAdmin
          .from('admins')
          .select('id')
          .eq('id', adminId)
          .maybeSingle();
        isAuthorized = !!admin;
      }

      if (!isAuthorized) {
        return new Response(
          JSON.stringify({ error: 'Unauthorized' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Load student info with school
      const { data: studentData } = await supabaseAdmin
        .from('students')
        .select('*, schools(*)')
        .eq('id', student_id)
        .maybeSingle();

      // Load study sessions from last 7 days
      const weekAgo = new Date();
      weekAgo.setDate(weekAgo.getDate() - 7);

      const { data: sessionsData } = await supabaseAdmin
        .from('study_sessions')
        .select('*')
        .eq('student_id', student_id)
        .gte('created_at', weekAgo.toISOString())
        .order('created_at', { ascending: false });

      const { data: quizzesData } = await supabaseAdmin
        .from('quiz_attempts')
        .select('*')
        .eq('student_id', student_id)
        .gte('created_at', weekAgo.toISOString())
        .order('created_at', { ascending: false });

      // Load class averages for comparison
      let classAverages = null;
      if (student_class) {
        const { data: classStudents } = await supabaseAdmin
          .from('students')
          .select('id')
          .eq('class', student_class);

        if (classStudents && classStudents.length > 0) {
          const studentIds = classStudents.map((s: any) => s.id);

          const { data: classSessions } = await supabaseAdmin
            .from('study_sessions')
            .select('*')
            .in('student_id', studentIds)
            .gte('created_at', weekAgo.toISOString());

          const { data: classQuizzes } = await supabaseAdmin
            .from('quiz_attempts')
            .select('*')
            .in('student_id', studentIds)
            .gte('created_at', weekAgo.toISOString());

          const studentCount = classStudents.length;
          const totalSessions = classSessions?.length || 0;
          const totalQuizzes = classQuizzes?.length || 0;
          const totalTimeSpent = classSessions?.reduce((acc: number, s: any) => acc + (s.time_spent || 0), 0) || 0;
          const totalAccuracy = classQuizzes?.reduce((acc: number, q: any) => acc + (q.accuracy_percentage || 0), 0) || 0;
          const totalImprovementScore = classSessions?.reduce((acc: number, s: any) => acc + (s.improvement_score || 50), 0) || 0;

          classAverages = {
            avgSessions: Math.round((totalSessions / studentCount) * 10) / 10,
            avgTimeSpent: Math.round(totalTimeSpent / studentCount),
            avgAccuracy: totalQuizzes > 0 ? Math.round(totalAccuracy / totalQuizzes) : 0,
            avgQuizzes: Math.round((totalQuizzes / studentCount) * 10) / 10,
            avgImprovementScore: totalSessions > 0 ? Math.round(totalImprovementScore / totalSessions) : 50,
          };
        }
      }

      return new Response(
        JSON.stringify({
          student: studentData,
          sessions: sessionsData || [],
          quizzes: quizzesData || [],
          classAverages,
        }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Verify session token for list operations
    if (user_type === 'school') {
      // Verify school session
      const { data: school, error } = await supabaseAdmin
        .from('schools')
        .select('id, name, is_banned, fee_paid')
        .eq('id', school_id)
        .maybeSingle();

      if (error || !school) {
        return new Response(
          JSON.stringify({ error: 'Invalid school session' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      if (school.is_banned) {
        return new Response(
          JSON.stringify({ error: 'School is banned' }),
          { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Fetch students for this school
      const { data: students, error: studentsError } = await supabaseAdmin
        .from('students')
        .select('*')
        .eq('school_id', school_id)
        .eq('is_banned', false)
        .order('created_at', { ascending: false });

      if (studentsError) {
        console.error('Error fetching students:', studentsError);
        return new Response(
          JSON.stringify({ error: 'Failed to fetch students' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Fetch study sessions for each student to calculate trends
      const studentsWithSessions = await Promise.all(
        (students || []).map(async (student) => {
          const { data: sessions } = await supabaseAdmin
            .from('study_sessions')
            .select('*')
            .eq('student_id', student.id)
            .order('created_at', { ascending: false })
            .limit(10);

          return {
            ...student,
            study_sessions: sessions || []
          };
        })
      );

      return new Response(
        JSON.stringify({ students: studentsWithSessions, school }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );

    } else if (user_type === 'admin') {
      // Verify admin session (basic check - in production use proper JWT)
      const adminId = session_token?.split('_')[1];
      
      const { data: admin, error: adminError } = await supabaseAdmin
        .from('admins')
        .select('id, name, role')
        .eq('id', adminId)
        .maybeSingle();

      if (adminError || !admin) {
        return new Response(
          JSON.stringify({ error: 'Invalid admin session' }),
          { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Fetch all students with school info
      const { data: students, error: studentsError } = await supabaseAdmin
        .from('students')
        .select('*, schools(name)')
        .order('created_at', { ascending: false });

      if (studentsError) {
        console.error('Error fetching students:', studentsError);
        return new Response(
          JSON.stringify({ error: 'Failed to fetch students' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      // Fetch all schools
      const { data: schools, error: schoolsError } = await supabaseAdmin
        .from('schools')
        .select('*')
        .order('created_at', { ascending: false });

      if (schoolsError) {
        console.error('Error fetching schools:', schoolsError);
        return new Response(
          JSON.stringify({ error: 'Failed to fetch schools' }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      return new Response(
        JSON.stringify({ students: students || [], schools: schools || [] }),
        { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    return new Response(
      JSON.stringify({ error: 'Invalid user type' }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});