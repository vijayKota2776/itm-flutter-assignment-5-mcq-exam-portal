const fs = require('fs');
const path = require('path');
const assert = require('assert');
const { parseAndValidateQuestionsFile } = require('../src/services/excelService');
const { gradeExamAttempt } = require('../src/services/gradingService');
const { generateResultPDF, generateAdminReportPDF } = require('../src/services/pdfService');

async function runTests() {
  console.log('--- Starting Backend Unit & Service Tests ---');

  // Test 1: Excel Parsing with valid sample file
  console.log('\n[Test 1] Parsing sample_exam_questions.xlsx...');
  const xlsxPath = path.resolve(__dirname, '../../sample_exam_questions.xlsx');
  assert(fs.existsSync(xlsxPath), 'sample_exam_questions.xlsx should exist');
  const xlsxBuffer = fs.readFileSync(xlsxPath);
  const parseResult = parseAndValidateQuestionsFile(xlsxBuffer);

  assert.strictEqual(parseResult.isValid, true, 'Parsing should be valid');
  assert.strictEqual(parseResult.validCount, 10, 'Should have 10 valid questions');
  assert.strictEqual(parseResult.errorCount, 0, 'Should have 0 errors');
  assert.strictEqual(parseResult.questions[0].correctAnswer, 'B', 'Question 1 correct answer should be B');
  console.log('✓ Test 1 Passed: Valid Excel parsed with 10 questions successfully');

  // Test 2: Excel Parsing with CSV version
  console.log('\n[Test 2] Parsing sample_exam_questions.csv...');
  const csvPath = path.resolve(__dirname, '../../sample_exam_questions.csv');
  assert(fs.existsSync(csvPath), 'sample_exam_questions.csv should exist');
  const csvBuffer = fs.readFileSync(csvPath);
  const csvResult = parseAndValidateQuestionsFile(csvBuffer);

  assert.strictEqual(csvResult.isValid, true, 'CSV Parsing should be valid');
  assert.strictEqual(csvResult.validCount, 10, 'CSV Should have 10 valid questions');
  console.log('✓ Test 2 Passed: CSV parsed successfully');

  // Test 3: Excel Parsing validation error for invalid options
  console.log('\n[Test 3] Testing Excel row-level validation errors...');
  const invalidBuffer = Buffer.from('Question No.,Question,Option A,Option B,Option C,Option D,Correct Answer\n1,Test Question,A,B,C,D,Z\n', 'utf8');
  const invalidResult = parseAndValidateQuestionsFile(invalidBuffer);
  assert.strictEqual(invalidResult.isValid, false, 'Invalid row should fail validation');
  assert.strictEqual(invalidResult.errorCount, 1, 'Should have 1 row error');
  assert(invalidResult.errors[0].errors[0].includes("Invalid Correct Answer 'Z'"), 'Should report invalid correct answer');
  console.log('✓ Test 3 Passed: Detected invalid correct answer (Z) properly');

  // Test 4: Server-Side Grading Engine with Negative Marking
  console.log('\n[Test 4] Testing Server-side Grading Engine...');
  const sampleQuestions = [
    { id: 'q1', questionNo: 1, question: 'Q1', options: { A: '1', B: '2', C: '3', D: '4' }, correctAnswer: 'A' },
    { id: 'q2', questionNo: 2, question: 'Q2', options: { A: '1', B: '2', C: '3', D: '4' }, correctAnswer: 'B' },
    { id: 'q3', questionNo: 3, question: 'Q3', options: { A: '1', B: '2', C: '3', D: '4' }, correctAnswer: 'C' },
    { id: 'q4', questionNo: 4, question: 'Q4', options: { A: '1', B: '2', C: '3', D: '4' }, correctAnswer: 'D' }
  ];

  // Student answers: Q1: A (Correct, +1), Q2: C (Wrong, -0.25), Q3: unattempted (0), Q4: D (Correct, +1)
  // Expected: Correct=2, Wrong=1, Unattempted=1. Score = 2*1 - 1*0.25 = 1.75
  const studentAnswers = { q1: 'A', q2: 'C', q4: 'D' };
  const examConfig = {
    totalMarks: 4,
    marksPerQuestion: 1,
    negativeMarking: 0.25,
    passingMarks: 2
  };

  const gradeResult = gradeExamAttempt(sampleQuestions, studentAnswers, examConfig, 120);
  assert.strictEqual(gradeResult.totalQuestions, 4);
  assert.strictEqual(gradeResult.attempted, 3);
  assert.strictEqual(gradeResult.correct, 2);
  assert.strictEqual(gradeResult.wrong, 1);
  assert.strictEqual(gradeResult.unattempted, 1);
  assert.strictEqual(gradeResult.score, 1.75);
  assert.strictEqual(gradeResult.percentage, 43.75);
  assert.strictEqual(gradeResult.status, 'FAIL'); // 1.75 < 2 passing marks
  assert.strictEqual(gradeResult.grade, 'C'); // 43.75% is grade C
  assert.strictEqual(gradeResult.questionAnalysis.length, 4);
  console.log('✓ Test 4 Passed: Server-side grading math and negative marking verified');

  // Test 5: PDF Generation
  console.log('\n[Test 5] Testing Result and Report PDF generation...');
  const resultPdf = await generateResultPDF({
    student: { name: 'Amitabh Morey', email: 'amitabh@itm.edu' },
    exam: { title: 'General Knowledge 2026', subject: 'GK', duration: 30 },
    result: gradeResult,
    submittedAt: new Date().toISOString()
  });
  assert(Buffer.isBuffer(resultPdf), 'Result PDF should be a buffer');
  assert(resultPdf.length > 1000, 'Result PDF buffer should have valid size');

  const adminReportPdf = await generateAdminReportPDF({
    exam: { title: 'General Knowledge 2026', subject: 'GK', duration: 30, passingMarks: 2 },
    stats: { totalAttempts: 1, averageScore: 1.75, highestScore: 1.75, lowestScore: 1.75, passPercentage: 0 },
    students: [{ studentName: 'Amitabh Morey', email: 'amitabh@itm.edu', score: 1.75, percentage: 43.75, status: 'FAIL', grade: 'C' }]
  });
  assert(Buffer.isBuffer(adminReportPdf), 'Admin Report PDF should be a buffer');
  assert(adminReportPdf.length > 1000, 'Admin Report PDF buffer should have valid size');
  console.log('✓ Test 5 Passed: Result & Admin report PDFs generated successfully');

  console.log('\n========================================');
  console.log('ALL BACKEND TESTS COMPLETED SUCCESSFULLY');
  console.log('========================================');
}

runTests().catch(err => {
  console.error('Test run failed:', err);
  process.exit(1);
});
