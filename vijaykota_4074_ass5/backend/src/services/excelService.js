const XLSX = require('xlsx');

/**
 * Normalizes header keys to handle slight whitespace, casing, or punctuation variations
 */
const normalizeHeader = (header) => {
  return String(header || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');
};

const REQUIRED_HEADERS = [
  'questionno',
  'question',
  'optiona',
  'optionb',
  'optionc',
  'optiond',
  'correctanswer'
];

/**
 * Parses an Excel or CSV file buffer and validates its columns and row values
 * @param {Buffer} buffer - File buffer
 * @returns {{ isValid: boolean, totalRows: number, validCount: number, errorCount: number, errors: Array, questions: Array }}
 */
const parseAndValidateQuestionsFile = (buffer) => {
  let workbook;
  try {
    workbook = XLSX.read(buffer, { type: 'buffer', cellDates: false });
  } catch (err) {
    return {
      isValid: false,
      totalRows: 0,
      validCount: 0,
      errorCount: 1,
      errors: [`Unable to parse file. The document is either corrupted or is not a valid Excel/CSV file: ${err.message}`],
      questions: []
    };
  }

  const sheetName = workbook.SheetNames[0];
  if (!sheetName) {
    return {
      isValid: false,
      totalRows: 0,
      validCount: 0,
      errorCount: 1,
      errors: ['The workbook does not contain any sheets.'],
      questions: []
    };
  }

  const worksheet = workbook.Sheets[sheetName];
  // Parse rows as raw JSON objects
  const rawRows = XLSX.utils.sheet_to_json(worksheet, { defval: '', raw: false });

  if (!rawRows || rawRows.length === 0) {
    return {
      isValid: false,
      totalRows: 0,
      validCount: 0,
      errorCount: 1,
      errors: ['The selected spreadsheet is empty. Please ensure the file has header row and question rows.'],
      questions: []
    };
  }

  // Check header row validity from the first row keys
  const firstRowKeys = Object.keys(rawRows[0]);
  const normalizedKeyMap = {};
  for (const key of firstRowKeys) {
    normalizedKeyMap[normalizeHeader(key)] = key;
  }

  const missingHeaders = [];
  for (const req of REQUIRED_HEADERS) {
    if (!normalizedKeyMap[req]) {
      // Find a readable name
      let readable = req;
      if (req === 'questionno') readable = 'Question No.';
      else if (req === 'question') readable = 'Question';
      else if (req === 'optiona') readable = 'Option A';
      else if (req === 'optionb') readable = 'Option B';
      else if (req === 'optionc') readable = 'Option C';
      else if (req === 'optiond') readable = 'Option D';
      else if (req === 'correctanswer') readable = 'Correct Answer';
      missingHeaders.push(readable);
    }
  }

  if (missingHeaders.length > 0) {
    return {
      isValid: false,
      totalRows: rawRows.length,
      validCount: 0,
      errorCount: missingHeaders.length,
      errors: [
        `Missing required column headers: ${missingHeaders.join(', ')}. ` +
        `Expected columns are: Question No., Question, Option A, Option B, Option C, Option D, Correct Answer.`
      ],
      questions: []
    };
  }

  const errors = [];
  const validQuestions = [];

  rawRows.forEach((row, index) => {
    const rowNumber = index + 2; // +1 for 0-index, +1 for header row
    const questionNo = row[normalizedKeyMap['questionno']] || rowNumber - 1;
    const questionText = String(row[normalizedKeyMap['question']] || '').trim();
    const optA = String(row[normalizedKeyMap['optiona']] || '').trim();
    const optB = String(row[normalizedKeyMap['optionb']] || '').trim();
    const optC = String(row[normalizedKeyMap['optionc']] || '').trim();
    const optD = String(row[normalizedKeyMap['optiond']] || '').trim();
    const rawCorrect = String(row[normalizedKeyMap['correctanswer']] || '').trim().toUpperCase();

    const rowErrors = [];

    if (!questionText) {
      rowErrors.push('Question text cannot be blank');
    }
    if (!optA) rowErrors.push('Option A is missing');
    if (!optB) rowErrors.push('Option B is missing');
    if (!optC) rowErrors.push('Option C is missing');
    if (!optD) rowErrors.push('Option D is missing');

    if (!['A', 'B', 'C', 'D'].includes(rawCorrect)) {
      rowErrors.push(`Invalid Correct Answer '${rawCorrect || 'EMPTY'}'. Must be strictly 'A', 'B', 'C', or 'D'`);
    }

    if (rowErrors.length > 0) {
      errors.push({
        row: rowNumber,
        questionNo,
        errors: rowErrors
      });
    } else {
      validQuestions.push({
        questionNo: Number(questionNo) || index + 1,
        question: questionText,
        imageUrl: '',
        options: {
          A: optA,
          B: optB,
          C: optC,
          D: optD
        },
        correctAnswer: rawCorrect
      });
    }
  });

  return {
    isValid: errors.length === 0 && validQuestions.length > 0,
    totalRows: rawRows.length,
    validCount: validQuestions.length,
    errorCount: errors.length,
    errors,
    questions: validQuestions
  };
};

module.exports = {
  parseAndValidateQuestionsFile
};
