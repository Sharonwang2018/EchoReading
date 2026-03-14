import pg from 'pg';

const { Pool } = pg;

const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://localhost:5432/echo_reading',
});

export async function query(text, params) {
  const res = await pool.query(text, params);
  return res;
}

export default pool;
