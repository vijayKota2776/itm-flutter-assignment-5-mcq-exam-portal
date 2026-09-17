const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

const sampleQuestions = [
  {
    "Question No.": 1,
    "Question": "What is the capital city of India?",
    "Option A": "Mumbai",
    "Option B": "New Delhi",
    "Option C": "Kolkata",
    "Option D": "Chennai",
    "Correct Answer": "B"
  },
  {
    "Question No.": 2,
    "Question": "Which planet in our solar system is known as the Red Planet?",
    "Option A": "Venus",
    "Option B": "Mars",
    "Option C": "Jupiter",
    "Option D": "Saturn",
    "Correct Answer": "B"
  },
  {
    "Question No.": 3,
    "Question": "What does HTML stand for in web development?",
    "Option A": "Hyper Text Markup Language",
    "Option B": "High Text Machine Language",
    "Option C": "Hyper Tabular Markup Language",
    "Option D": "None of these",
    "Correct Answer": "A"
  },
  {
    "Question No.": 4,
    "Question": "Which data structure follows the Last-In, First-Out (LIFO) principle?",
    "Option A": "Queue",
    "Option B": "Binary Tree",
    "Option C": "Stack",
    "Option D": "Linked List",
    "Correct Answer": "C"
  },
  {
    "Question No.": 5,
    "Question": "In Flutter, which widget is immutable and does not require mutable state?",
    "Option A": "StatefulWidget",
    "Option B": "StatelessWidget",
    "Option C": "InheritedWidget",
    "Option D": "StreamBuilder",
    "Correct Answer": "B"
  },
  {
    "Question No.": 6,
    "Question": "Which protocol is primarily used for secure communications over the Internet?",
    "Option A": "HTTP",
    "Option B": "FTP",
    "Option C": "HTTPS",
    "Option D": "Telnet",
    "Correct Answer": "C"
  },
  {
    "Question No.": 7,
    "Question": "What is the time complexity of searching in a balanced Binary Search Tree?",
    "Option A": "O(1)",
    "Option B": "O(n)",
    "Option C": "O(log n)",
    "Option D": "O(n log n)",
    "Correct Answer": "C"
  },
  {
    "Question No.": 8,
    "Question": "Which language runtime does Node.js utilize for executing JavaScript code?",
    "Option A": "SpiderMonkey",
    "Option B": "V8 Engine",
    "Option C": "JavaScriptCore",
    "Option D": "Chakra",
    "Correct Answer": "B"
  },
  {
    "Question No.": 9,
    "Question": "In relational databases, which SQL command is used to remove all records from a table without logging individual row deletions?",
    "Option A": "DELETE",
    "Option B": "REMOVE",
    "Option C": "TRUNCATE",
    "Option D": "DROP",
    "Correct Answer": "C"
  },
  {
    "Question No.": 10,
    "Question": "What is the default port commonly used for local Express.js development servers?",
    "Option A": "80",
    "Option B": "443",
    "Option C": "5000",
    "Option D": "8080",
    "Correct Answer": "C"
  }
];

function generateFiles() {
  const rootDir = path.resolve(__dirname, '../../../');
  const xlsxPath = path.join(rootDir, 'sample_exam_questions.xlsx');
  const csvPath = path.join(rootDir, 'sample_exam_questions.csv');

  // 1. Generate XLSX
  const worksheet = XLSX.utils.json_to_sheet(sampleQuestions);
  const workbook = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(workbook, worksheet, 'Questions');
  XLSX.writeFile(workbook, xlsxPath);
  console.log(`[Generated] Excel sample created at: ${xlsxPath}`);

  // 2. Generate CSV
  const csvContent = XLSX.utils.sheet_to_csv(worksheet);
  fs.writeFileSync(csvPath, csvContent, 'utf8');
  console.log(`[Generated] CSV sample created at: ${csvPath}`);
}

generateFiles();
