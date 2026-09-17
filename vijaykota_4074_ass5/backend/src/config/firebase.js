const path = require('path');
const fs = require('fs');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });
const admin = require('firebase-admin');

let db = null;
let isMockDb = false;

function initializeFirebase() {
  // 1. Try service account JSON file
  let serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (serviceAccountPath) {
    let resolvedPath = path.isAbsolute(serviceAccountPath)
      ? serviceAccountPath
      : path.resolve(process.cwd(), serviceAccountPath);

    if (fs.existsSync(resolvedPath)) {
      try {
        const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
        admin.initializeApp({
          credential: admin.credential.cert(serviceAccount)
        });
        db = admin.firestore();
        console.log('[Firebase] Initialized with service account file:', resolvedPath);
        return db;
      } catch (err) {
        console.error('[Firebase] Failed to load service account file:', err.message);
      }
    }
  }

  // 2. Try individual environment variables
  const projectId = process.env.FIREBASE_PROJECT_ID;
  const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
  let privateKey = process.env.FIREBASE_PRIVATE_KEY;

  if (projectId && clientEmail && privateKey) {
    try {
      privateKey = privateKey.replace(/\\n/g, '\n');
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey
        })
      });
      db = admin.firestore();
      console.log('[Firebase] Initialized with environment variables for project:', projectId);
      return db;
    } catch (err) {
      console.error('[Firebase] Failed to initialize with environment variables:', err.message);
    }
  }

  // 3. Try GOOGLE_APPLICATION_CREDENTIALS
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS && fs.existsSync(process.env.GOOGLE_APPLICATION_CREDENTIALS)) {
    try {
      admin.initializeApp();
      db = admin.firestore();
      console.log('[Firebase] Initialized with GOOGLE_APPLICATION_CREDENTIALS.');
      return db;
    } catch (err) {
      console.error('[Firebase] Failed with GOOGLE_APPLICATION_CREDENTIALS:', err.message);
    }
  }

  // 4. Resilient In-Memory Firestore-compatible store
  console.warn('\n================================================================');
  console.warn('[Firebase] Running with an in-memory Firestore-compatible store.');
  console.warn('[Firebase] Configure FIREBASE_CLIENT_EMAIL and FIREBASE_PRIVATE_KEY');
  console.warn('           in .env to connect to live Firestore.');
  console.warn('================================================================\n');

  isMockDb = true;
  const memoryStore = new Map();

  const createDocRef = (collName, docId) => {
    const id = docId || ('mem_' + Math.random().toString(36).substring(2, 11) + Date.now().toString(36));
    const fullKey = `${collName}/${id}`;

    return {
      id,
      get: async () => {
        const data = memoryStore.get(fullKey);
        return {
          id,
          exists: !!data,
          data: () => (data ? JSON.parse(JSON.stringify(data)) : undefined)
        };
      },
      set: async (data, options = {}) => {
        if (options.merge) {
          const existing = memoryStore.get(fullKey) || {};
          memoryStore.set(fullKey, { ...existing, ...data });
        } else {
          memoryStore.set(fullKey, { ...data });
        }
        return { writeTime: new Date() };
      },
      update: async (data) => {
        const existing = memoryStore.get(fullKey);
        if (!existing) {
          const error = new Error(`No document to update: ${fullKey}`);
          error.code = 5;
          throw error;
        }
        memoryStore.set(fullKey, { ...existing, ...data });
        return { writeTime: new Date() };
      },
      delete: async () => {
        memoryStore.delete(fullKey);
        return { writeTime: new Date() };
      }
    };
  };

  const createQuery = (collName, filters = [], orderBys = [], limitCount = null) => {
    return {
      where: (field, op, value) => {
        return createQuery(collName, [...filters, { field, op, value }], orderBys, limitCount);
      },
      orderBy: (field, direction = 'asc') => {
        return createQuery(collName, filters, [...orderBys, { field, direction }], limitCount);
      },
      limit: (n) => {
        return createQuery(collName, filters, orderBys, n);
      },
      get: async () => {
        let results = [];
        for (const [key, value] of memoryStore.entries()) {
          if (key.startsWith(`${collName}/`)) {
            const id = key.substring(collName.length + 1);
            let matches = true;

            for (const f of filters) {
              const val = value[f.field];
              if (f.op === '==' && val !== f.value) matches = false;
              if (f.op === '!=' && val === f.value) matches = false;
              if (f.op === '>' && !(val > f.value)) matches = false;
              if (f.op === '>=' && !(val >= f.value)) matches = false;
              if (f.op === '<' && !(val < f.value)) matches = false;
              if (f.op === '<=' && !(val <= f.value)) matches = false;
              if (f.op === 'array-contains' && (!Array.isArray(val) || !val.includes(f.value))) matches = false;
              if (f.op === 'in' && (!Array.isArray(f.value) || !f.value.includes(val))) matches = false;
            }

            if (matches) {
              results.push({
                id,
                data: () => JSON.parse(JSON.stringify(value))
              });
            }
          }
        }

        // Apply orderBys
        for (const ob of orderBys) {
          results.sort((a, b) => {
            const valA = a.data()[ob.field];
            const valB = b.data()[ob.field];
            if (valA < valB) return ob.direction === 'desc' ? 1 : -1;
            if (valA > valB) return ob.direction === 'desc' ? -1 : 1;
            return 0;
          });
        }

        // Apply limit
        if (limitCount !== null && limitCount >= 0) {
          results = results.slice(0, limitCount);
        }

        return {
          docs: results,
          empty: results.length === 0,
          size: results.length
        };
      }
    };
  };

  db = {
    collection: (collName) => ({
      doc: (docId) => createDocRef(collName, docId),
      add: async (data) => {
        const id = 'mem_' + Math.random().toString(36).substring(2, 11) + Date.now().toString(36);
        memoryStore.set(`${collName}/${id}`, { ...data });
        return createDocRef(collName, id);
      },
      ...createQuery(collName)
    }),
    batch: () => {
      const operations = [];
      return {
        set: (docRef, data, options) => {
          operations.push(async () => docRef.set(data, options));
        },
        update: (docRef, data) => {
          operations.push(async () => docRef.update(data));
        },
        delete: (docRef) => {
          operations.push(async () => docRef.delete());
        },
        commit: async () => {
          for (const op of operations) {
            await op();
          }
          return [];
        }
      };
    },
    runTransaction: async (updateFunction) => {
      const transaction = {
        get: async (docRef) => docRef.get(),
        set: (docRef, data, options) => docRef.set(data, options),
        update: (docRef, data) => docRef.update(data),
        delete: (docRef) => docRef.delete()
      };
      return await updateFunction(transaction);
    }
  };

  return db;
}

db = initializeFirebase();

module.exports = {
  getDb: () => db,
  isMockDb: () => isMockDb,
  admin
};
