import { Router } from 'express';
import { query } from '../db.js';
import { v4 as uuidv4 } from 'uuid';
import { authMiddleware } from '../middleware/auth.js';

const router = Router();

router.post('/', authMiddleware, async (req, res, next) => {
  try {
    const { book_id, audio_url, transcript, ai_feedback, language, session_type } = req.body || {};
    if (!book_id) {
      return res.status(400).json({ error: 'missing_book_id', message: '需要 book_id' });
    }

    const id = uuidv4();
    await query(
      `INSERT INTO read_logs (id, user_id, book_id, audio_url, transcript, ai_feedback, language, session_type)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        id,
        req.userId,
        book_id,
        audio_url || null,
        transcript || null,
        ai_feedback || null,
        language || null,
        session_type || 'retelling',
      ]
    );

    const result = await query(
      'SELECT id, user_id, book_id, audio_url, transcript, ai_feedback, language, session_type, created_at FROM read_logs WHERE id = $1',
      [id]
    );
    const row = result.rows[0];
    res.status(201).json({
      id: row.id,
      user_id: row.user_id,
      book_id: row.book_id,
      audio_url: row.audio_url,
      transcript: row.transcript,
      ai_feedback: row.ai_feedback,
      language: row.language,
      session_type: row.session_type,
      created_at: row.created_at,
    });
  } catch (e) {
    next(e);
  }
});

router.patch('/:id', authMiddleware, async (req, res, next) => {
  try {
    const { id } = req.params;
    const { ai_feedback } = req.body || {};
    if (!ai_feedback) {
      return res.status(400).json({ error: 'missing_ai_feedback', message: '需要 ai_feedback' });
    }

    const result = await query(
      'UPDATE read_logs SET ai_feedback = $1 WHERE id = $2 AND user_id = $3 RETURNING id',
      [ai_feedback, id, req.userId]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'not_found', message: '记录不存在或无权修改' });
    }
    res.json({ ok: true });
  } catch (e) {
    next(e);
  }
});

router.get('/', authMiddleware, async (req, res, next) => {
  try {
    const result = await query(
      `SELECT
         r.id,
         r.user_id,
         r.book_id,
         r.audio_url,
         r.transcript,
         r.ai_feedback,
         r.language,
         r.session_type,
         r.created_at,
         CASE
           WHEN b.id IS NULL THEN NULL
           ELSE json_build_object(
             'id', b.id,
             'isbn', b.isbn,
             'title', b.title,
             'author', b.author,
             'cover_url', b.cover_url,
             'summary', b.summary
           )
         END AS book
       FROM read_logs r
       LEFT JOIN books b ON b.id = r.book_id
       WHERE r.user_id = $1
       ORDER BY r.created_at DESC
       LIMIT 100`,
      [req.userId]
    );
    res.json(result.rows.map((row) => ({
      id: row.id,
      user_id: row.user_id,
      book_id: row.book_id,
      audio_url: row.audio_url,
      transcript: row.transcript,
      ai_feedback: row.ai_feedback,
      language: row.language,
      session_type: row.session_type,
      created_at: row.created_at,
      book: row.book,
    })));
  } catch (e) {
    next(e);
  }
});

export default router;
