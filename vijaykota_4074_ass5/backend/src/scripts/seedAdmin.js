const path = require('path');
require('dotenv').config({ path: path.resolve(__dirname, '../../.env') });
const { getDb, admin } = require('../config/firebase');

async function seedAdmin() {
  const adminEmail = process.argv[2] || process.env.DEFAULT_ADMIN_EMAIL || 'admin@itm.edu';
  const adminName = process.argv[3] || 'ITM Head Administrator';

  console.log(`[SeedAdmin] Seeding administrator with email: ${adminEmail}...`);

  const db = getDb();

  // Look for existing user with this email
  const snap = await db.collection('users').where('email', '==', adminEmail.toLowerCase().trim()).get();

  if (!snap.empty) {
    const userDoc = snap.docs[0];
    await db.collection('users').doc(userDoc.id).update({
      role: 'admin',
      updatedAt: new Date().toISOString()
    });
    console.log(`[SeedAdmin] Updated existing user (${userDoc.id}) role to: ADMIN`);
  } else {
    const uid = 'admin_' + Math.random().toString(36).substring(2, 10);
    await db.collection('users').doc(uid).set({
      uid,
      email: adminEmail.toLowerCase().trim(),
      name: adminName,
      role: 'admin',
      photoUrl: '',
      createdAt: new Date().toISOString(),
      lastLogin: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    });
    console.log(`[SeedAdmin] Created new administrator record with ID: ${uid}`);
  }

  console.log('[SeedAdmin] Admin seeding successfully completed.');
  process.exit(0);
}

seedAdmin().catch(err => {
  console.error('[SeedAdmin] Error seeding administrator:', err);
  process.exit(1);
});
