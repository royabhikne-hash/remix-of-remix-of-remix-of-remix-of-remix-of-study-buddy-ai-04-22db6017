import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface StudentReport {
  studentId: string;
  studentName: string;
  parentWhatsapp: string;
  studyConsistency: number;
  topicsCovered: string[];
  weakSubjects: string[];
  improvementSummary: string;
  totalSessions: number;
  totalMinutes: number;
  avgScore: number;
}

interface QuizStats {
  totalAttempts: number;
  avgAccuracy: number;
  bestScore: number;
  questionsAttempted: number;
}

const getPerformanceEmoji = (score: number): string => {
  if (score >= 80) return "🌟";
  if (score >= 60) return "👍";
  if (score >= 40) return "📈";
  return "💪";
};

const getConsistencyEmoji = (consistency: number): string => {
  if (consistency >= 80) return "🔥";
  if (consistency >= 60) return "⭐";
  if (consistency >= 40) return "📅";
  return "⏰";
};

const generatePDFContent = (report: StudentReport, quizStats?: QuizStats): string => {
  const dateRange = `${new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toLocaleDateString('hi-IN')} - ${new Date().toLocaleDateString('hi-IN')}`;
  const performanceEmoji = getPerformanceEmoji(report.avgScore);
  const consistencyEmoji = getConsistencyEmoji(report.studyConsistency);
  
  // Calculate grade
  const overallScore = (report.avgScore * 0.4) + (report.studyConsistency * 0.3) + ((quizStats?.avgAccuracy || 0) * 0.3);
  let grade = "D";
  if (overallScore >= 85) grade = "A+";
  else if (overallScore >= 75) grade = "A";
  else if (overallScore >= 65) grade = "B+";
  else if (overallScore >= 55) grade = "B";
  else if (overallScore >= 45) grade = "C";
  
  let message = `🎓 *${report.studentName} का Weekly Report*
━━━━━━━━━━━━━━━━━━━━
📅 *Period:* ${dateRange}
🏆 *Overall Grade:* ${grade} ${performanceEmoji}

📊 *Study Summary:*
┌────────────────────
│ 📚 Sessions: ${report.totalSessions}
│ ⏱️ Time: ${Math.floor(report.totalMinutes / 60)}h ${report.totalMinutes % 60}m
│ ${consistencyEmoji} Consistency: ${report.studyConsistency}%
│ 📈 Avg Score: ${report.avgScore}%
└────────────────────`;

  // Add quiz stats if available
  if (quizStats && quizStats.totalAttempts > 0) {
    message += `

🧠 *Quiz Performance:*
┌────────────────────
│ 📝 Quizzes: ${quizStats.totalAttempts}
│ ✅ Accuracy: ${quizStats.avgAccuracy}%
│ 🎯 Best Score: ${quizStats.bestScore}%
│ ❓ Questions: ${quizStats.questionsAttempted}
└────────────────────`;
  }

  message += `

📖 *Topics Padhe:*
${report.topicsCovered.length > 0 ? report.topicsCovered.slice(0, 5).map(t => `  ✓ ${t}`).join('\n') : '  • Koi topic record nahi hua'}`;

  if (report.weakSubjects.length > 0) {
    message += `

⚠️ *Improvement Areas:*
${report.weakSubjects.slice(0, 3).map(s => `  → ${s}`).join('\n')}`;
  } else {
    message += `

✨ *No Weak Areas!* Bahut badhiya progress!`;
  }

  message += `

💡 *AI Feedback:*
"${report.improvementSummary}"

━━━━━━━━━━━━━━━━━━━━
📱 _EduImprove AI - Aapke bachche ka study partner_
🌐 Daily progress track karein app mein!`;

  return message;
};

const sendWhatsAppMessage = async (to: string, message: string): Promise<boolean> => {
  const accountSid = Deno.env.get("TWILIO_ACCOUNT_SID");
  const authToken = Deno.env.get("TWILIO_AUTH_TOKEN");
  const fromNumber = Deno.env.get("TWILIO_WHATSAPP_FROM");

  if (!accountSid || !authToken || !fromNumber) {
    console.error("Twilio credentials not configured");
    return false;
  }

  // Format phone number for WhatsApp
  let formattedTo = to.replace(/\D/g, '');
  if (!formattedTo.startsWith('91')) {
    formattedTo = '91' + formattedTo;
  }

  try {
    const url = `https://api.twilio.com/2010-04-01/Accounts/${accountSid}/Messages.json`;
    
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': 'Basic ' + btoa(`${accountSid}:${authToken}`),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        From: `whatsapp:${fromNumber}`,
        To: `whatsapp:+${formattedTo}`,
        Body: message,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("Twilio error:", response.status, errorText);
      return false;
    }

    console.log(`WhatsApp sent successfully to ${formattedTo}`);
    return true;
  } catch (error) {
    console.error("Error sending WhatsApp:", error);
    return false;
  }
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Check if this is a single student test request
    let body: { studentId?: string; testMode?: boolean } = {};
    try {
      body = await req.json();
    } catch {
      // No body provided, process all students
    }

    console.log("Starting report generation...", body.testMode ? "(Test Mode)" : "");

    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    
    // If single student test mode, only fetch that student
    let studentsQuery = supabase.from("students").select("*");
    if (body.studentId && body.testMode) {
      studentsQuery = studentsQuery.eq("id", body.studentId);
    }

    const { data: students, error: studentsError } = await studentsQuery;

    if (studentsError) {
      console.error("Error fetching students:", studentsError);
      throw studentsError;
    }

    console.log(`Found ${students?.length || 0} students`);

    const reports: { studentName: string; sent: boolean }[] = [];

    for (const student of students || []) {
      // Get sessions for this student from the past 7 days
      const { data: sessions } = await supabase
        .from("study_sessions")
        .select("*")
        .eq("student_id", student.id)
        .gte("created_at", sevenDaysAgo)
        .order("created_at", { ascending: false });

      // Get quiz attempts for this student
      const { data: quizzes } = await supabase
        .from("quiz_attempts")
        .select("*")
        .eq("student_id", student.id)
        .gte("created_at", sevenDaysAgo);

      const sessionList = sessions || [];
      const quizList = quizzes || [];
      
      // Calculate quiz stats
      const quizStats: QuizStats = {
        totalAttempts: quizList.length,
        avgAccuracy: quizList.length > 0 
          ? Math.round(quizList.reduce((acc, q) => acc + (q.accuracy_percentage || 0), 0) / quizList.length)
          : 0,
        bestScore: quizList.length > 0 
          ? Math.max(...quizList.map(q => q.accuracy_percentage || 0))
          : 0,
        questionsAttempted: quizList.reduce((acc, q) => acc + (q.total_questions || 0), 0)
      };
      
      // Calculate metrics
      const totalSessions = sessionList.length;
      const totalMinutes = sessionList.reduce((acc, s) => acc + (s.time_spent || 0), 0);
      const avgScore = totalSessions > 0 
        ? Math.round(sessionList.reduce((acc, s) => acc + (s.improvement_score || 50), 0) / totalSessions)
        : 0;
      
      // Calculate study consistency (days studied out of 7)
      const daysStudied = new Set(sessionList.map(s => new Date(s.created_at).toDateString())).size;
      const studyConsistency = Math.round((daysStudied / 7) * 100);
      
      // Get unique topics
      const topicsCovered = [...new Set(sessionList.map(s => s.topic).filter(Boolean))];
      
      // Identify weak areas
      const weakSessions = sessionList.filter(s => 
        s.understanding_level === 'weak' || s.understanding_level === 'average'
      );
      const weakSubjects = [...new Set(weakSessions.map(s => s.subject || s.topic).filter(Boolean))];
      
      // Generate improved Hinglish summary
      let improvementSummary = "";
      if (totalSessions === 0) {
        improvementSummary = `${student.full_name} ne is hafte padhai nahi ki. Please daily app use karne ke liye encourage karein!`;
      } else if (studyConsistency >= 70 && avgScore >= 70) {
        improvementSummary = `Bahut badhiya! ${student.full_name} regular padh raha hai aur achhe marks la raha hai. Keep it up!`;
      } else if (studyConsistency >= 70) {
        improvementSummary = `${student.full_name} ki consistency achhi hai lekin score improve ho sakta hai. Focus on practice!`;
      } else if (avgScore >= 70) {
        improvementSummary = `Jab ${student.full_name} padhta hai toh achha karta hai, par aur regularly padhna chahiye.`;
      } else if (studyConsistency >= 40) {
        improvementSummary = `Effort theek hai. Daily practice se ${student.full_name} aur improve kar sakta hai.`;
      } else {
        improvementSummary = `${student.full_name} ko daily study habit develop karni hogi. Thoda encourage karein!`;
      }

      // Add quiz performance insight
      if (quizStats.totalAttempts > 0) {
        if (quizStats.avgAccuracy >= 70) {
          improvementSummary += ` Quiz mein achhi performance hai! 🌟`;
        } else if (quizStats.avgAccuracy >= 50) {
          improvementSummary += ` Quiz practice se concepts aur clear honge.`;
        }
      }

      const report: StudentReport = {
        studentId: student.id,
        studentName: student.full_name,
        parentWhatsapp: student.parent_whatsapp,
        studyConsistency,
        topicsCovered,
        weakSubjects,
        improvementSummary,
        totalSessions,
        totalMinutes,
        avgScore,
      };

      // Generate and send report with quiz stats
      const messageContent = generatePDFContent(report, quizStats);
      const sent = await sendWhatsAppMessage(student.parent_whatsapp, messageContent);
      
      reports.push({ studentName: student.full_name, sent });
      
      // Small delay between messages to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 500));
    }

    console.log("Weekly reports completed:", reports);

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Processed ${reports.length} students`,
        reports 
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Weekly report error:", error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
