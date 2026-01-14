import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface AnalyzeRequest {
  question: string;
  correctAnswer: string;
  studentAnswer: string;
  topic: string;
  questionType: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const { question, correctAnswer, studentAnswer, topic, questionType }: AnalyzeRequest = await req.json();
    const LOVABLE_API_KEY = Deno.env.get("LOVABLE_API_KEY");

    if (!LOVABLE_API_KEY) {
      console.error("LOVABLE_API_KEY is not configured");
      throw new Error("AI service is not configured");
    }

    console.log("Analyzing answer for topic:", topic);
    console.log("Question:", question.substring(0, 100));
    console.log("Student answer:", studentAnswer);
    console.log("Correct answer:", correctAnswer);

    const systemPrompt = `You are an intelligent answer analyzer for Indian students studying in Hinglish.

Your job is to determine if the student's answer is CORRECT, even if they expressed it differently than the expected answer.

ANALYSIS RULES:
1. Focus on MEANING and UNDERSTANDING, not exact wording
2. Accept synonyms, paraphrasing, and different ways of expressing the same concept
3. Accept partial answers if they capture the key concept
4. Be lenient with spelling mistakes if the intent is clear
5. For MCQ/True-False: The answer must match the correct option
6. For short answers: Accept any answer that demonstrates understanding of the concept
7. Consider cultural context - Indian students may use Hindi words mixed with English

EXAMPLES OF EQUIVALENT ANSWERS:
- "Photosynthesis" = "Plants make food from sunlight" = "Paudhon mein khaana banana" ✓
- "H2O" = "Water" = "Paani" ✓
- "Velocity = Distance/Time" = "Speed = Door/Samay" = "V equals D by T" ✓
- "Mitochondria" = "Cell ka powerhouse" = "Energy factory of cell" ✓

OUTPUT FORMAT (strictly JSON):
{
  "isCorrect": true | false,
  "confidence": 0-100,
  "reasoning": "Brief explanation in Hinglish of why the answer is correct/incorrect",
  "feedback": "Encouraging feedback for the student in Hinglish",
  "keyConceptMatched": true | false,
  "partialCredit": 0-100
}`;

    const userPrompt = `Analyze this student's answer:

Question: ${question}
Question Type: ${questionType}
Topic: ${topic}
Expected Answer: ${correctAnswer}
Student's Answer: ${studentAnswer}

Is the student's answer correct or equivalent to the expected answer? Consider meaning over exact wording.`;

    const PRIMARY_MODEL = "openai/gpt-5-nano";
    const FALLBACK_MODEL = "google/gemini-2.5-flash-lite";

    const analyzeMessages = [
      { role: "system", content: systemPrompt },
      { role: "user", content: userPrompt }
    ];

    const callLovableAI = async (model: string) => {
      const body: Record<string, unknown> = {
        model,
        messages: analyzeMessages,
      };

      if (model.startsWith("openai/")) {
        body.max_completion_tokens = 500;
      } else {
        body.max_tokens = 500;
      }

      console.log(`Calling Lovable AI for answer analysis with model: ${model}`);

      const resp = await fetch("https://ai.gateway.lovable.dev/v1/chat/completions", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${LOVABLE_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
      });

      if (!resp.ok) {
        const errorText = await resp.text();
        console.error("AI gateway error:", resp.status, errorText);

        if (resp.status === 429) {
          const isCorrect = studentAnswer.toLowerCase().trim() === correctAnswer.toLowerCase().trim();
          return { 
            fallbackResult: { 
              isCorrect, 
              confidence: 100, 
              reasoning: isCorrect ? "Answer matches" : "Answer doesn't match",
              feedback: isCorrect ? "Sahi jawab!" : "Galat jawab",
              fallback: true
            }
          };
        }

        throw new Error(`AI service error: ${resp.status}`);
      }

      const data = await resp.json();
      return { data };
    };

    let data: any;

    // Primary call
    {
      const result = await callLovableAI(PRIMARY_MODEL);
      if (result.fallbackResult) {
        return new Response(
          JSON.stringify(result.fallbackResult),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      data = result.data;
    }

    let aiResponse = data?.choices?.[0]?.message?.content;

    // Fallback if empty response
    if (typeof aiResponse !== "string" || aiResponse.trim().length === 0) {
      console.error("No response from primary AI, trying fallback:", data);
      
      const result2 = await callLovableAI(FALLBACK_MODEL);
      if (result2.fallbackResult) {
        return new Response(
          JSON.stringify(result2.fallbackResult),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
      
      const data2 = result2.data;
      aiResponse = data2?.choices?.[0]?.message?.content;
    }

    if (typeof aiResponse !== "string" || aiResponse.trim().length === 0) {
      console.error("No response from AI");
      throw new Error("No AI response");
    }

    // Parse JSON from response
    let analysisResult;
    try {
      const jsonMatch = aiResponse.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        analysisResult = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error("No JSON found");
      }
    } catch (e) {
      console.error("Failed to parse analysis:", e);
      // Fallback
      const isCorrect = studentAnswer.toLowerCase().trim() === correctAnswer.toLowerCase().trim();
      analysisResult = {
        isCorrect,
        confidence: 80,
        reasoning: "Analysis completed",
        feedback: isCorrect ? "Sahi jawab!" : "Koi baat nahi, next time better!",
      };
    }

    console.log("Analysis result:", analysisResult);

    return new Response(
      JSON.stringify(analysisResult),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Answer analysis error:", error);
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : "Unknown error",
        isCorrect: false,
        confidence: 0,
        feedback: "Could not analyze answer"
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
