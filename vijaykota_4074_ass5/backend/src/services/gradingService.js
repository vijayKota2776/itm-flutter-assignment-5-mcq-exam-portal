/**
 * Determines letter grade according to standard academic percentage scale
 */
const calculateGrade = (percentage) => {
  if (percentage >= 90) return 'O';    // Outstanding
  if (percentage >= 80) return 'A+';   // Excellent
  if (percentage >= 70) return 'A';    // Very Good
  if (percentage >= 60) return 'B+';   // Good
  if (percentage >= 50) return 'B';    // Above Average
  if (percentage >= 40) return 'C';    // Pass
  return 'F';                          // Fail
};

/**
 * Server-Side Exam Grading Engine
 * Evaluates student answers against official questions stored in database.
 * 
 * @param {Array} questions - Array of official question documents with correctAnswer
 * @param {Object} studentAnswers - Map of { questionId: 'A' | 'B' | 'C' | 'D' }
 * @param {Object} examConfig - Exam metadata (marksPerQuestion, negativeMarking, passingMarks, totalMarks, duration)
 * @param {number} timeTakenSeconds - Seconds spent on exam
 * @returns {Object} Graded evaluation result with detailed question breakdown
 */
const gradeExamAttempt = (questions, studentAnswers = {}, examConfig = {}, timeTakenSeconds = 0) => {
  const marksPerQuestion = Number(examConfig.marksPerQuestion) || 1;
  const negativeMarking = Number(examConfig.negativeMarking) || 0;
  const totalQuestions = questions.length;
  const totalMarks = Number(examConfig.totalMarks) || (totalQuestions * marksPerQuestion);
  const passingMarks = Number(examConfig.passingMarks) || (totalMarks * 0.4);

  let attempted = 0;
  let correct = 0;
  let wrong = 0;
  let unattempted = 0;

  const questionAnalysis = [];

  questions.forEach((q, idx) => {
    const qId = q.id || String(q.questionNo || idx + 1);
    const studentAns = (studentAnswers[qId] || studentAnswers[String(q.questionNo)] || '').trim().toUpperCase();
    const correctAns = String(q.correctAnswer || '').trim().toUpperCase();

    let questionStatus = 'UNATTEMPTED';
    let marksAwarded = 0;

    if (!studentAns) {
      unattempted++;
      questionStatus = 'UNATTEMPTED';
      marksAwarded = 0;
    } else {
      attempted++;
      if (studentAns === correctAns) {
        correct++;
        questionStatus = 'CORRECT';
        marksAwarded = marksPerQuestion;
      } else {
        wrong++;
        questionStatus = 'WRONG';
        marksAwarded = -negativeMarking;
      }
    }

    questionAnalysis.push({
      questionId: qId,
      questionNo: q.questionNo || idx + 1,
      question: q.question,
      options: q.options || {},
      studentAnswer: studentAns || null,
      correctAnswer: correctAns,
      status: questionStatus,
      marksAwarded: Number(marksAwarded.toFixed(2))
    });
  });

  const correctMarks = correct * marksPerQuestion;
  const negativeMarks = wrong * negativeMarking;
  let rawScore = correctMarks - negativeMarks;

  // University policy: prevent score from going below zero, or keep as rounded float
  const finalScore = Number(Math.max(0, rawScore).toFixed(2));
  const percentage = totalMarks > 0 ? Number(((finalScore / totalMarks) * 100).toFixed(2)) : 0;
  const isPass = finalScore >= passingMarks;
  const grade = calculateGrade(percentage);

  return {
    totalQuestions,
    attempted,
    correct,
    wrong,
    unattempted,
    marksPerQuestion,
    negativeMarking,
    totalMarks,
    passingMarks,
    score: finalScore,
    percentage,
    status: isPass ? 'PASS' : 'FAIL',
    grade,
    timeTaken: Math.max(0, Math.floor(timeTakenSeconds)),
    questionAnalysis
  };
};

module.exports = {
  gradeExamAttempt,
  calculateGrade
};
