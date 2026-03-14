import 'dotenv/config';
import express from 'express';
import http from 'http';
import https from 'https';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import cors from 'cors';
import authRoutes from './routes/auth.js';
import booksRoutes from './routes/books.js';
import readLogsRoutes from './routes/read_logs.js';
import uploadRoutes from './routes/upload.js';
import { attachWsToServer } from './routes/asr_stream.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const UPLOAD_DIR = process.env.UPLOAD_DIR || path.join(__dirname, 'uploads');
const AUDIO_DIR = path.join(UPLOAD_DIR, 'audio');
const WEB_BUILD = path.join(__dirname, '..', 'build', 'web');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Request logging (skip static assets for readability)
app.use((req, res, next) => {
  if (!req.path.startsWith('/auth') && !req.path.startsWith('/books') && !req.path.startsWith('/read-logs') && !req.path.startsWith('/upload') && !req.path.startsWith('/api/') && req.path !== '/health') return next();
  const t = new Date().toISOString();
  console.log(`[${t}] ${req.method} ${req.path}`);
  next();
});

// API routes (must be before static to avoid conflict)
app.use('/auth', authRoutes);
app.use('/books', booksRoutes);
app.use('/read-logs', readLogsRoutes);
app.use('/upload', uploadRoutes);

// Serve uploaded audio files
if (!fs.existsSync(AUDIO_DIR)) fs.mkdirSync(AUDIO_DIR, { recursive: true });
app.use('/audio', express.static(AUDIO_DIR));

app.get('/health', (req, res) => {
  res.json({ ok: true });
});

app.get('/api/asr-stream-ready', (req, res) => {
  const ok = !!(process.env.DOUBAO_ASR_APPID && process.env.DOUBAO_ASR_ACCESS_KEY);
  res.json({ ok });
});

// Serve Flutter web build (UI + API from same origin = Device A always reaches backend)
if (fs.existsSync(path.join(WEB_BUILD, 'index.html'))) {
  app.use(express.static(WEB_BUILD));
  app.get('*', (_req, res) => res.sendFile(path.join(WEB_BUILD, 'index.html')));
}

app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: 'internal_error', message: err.message || '服务器错误' });
});

const useHttps = process.env.HTTPS === '1' || process.env.HTTPS === 'true';
const certDir = path.join(__dirname, 'certs');
const keyPath = path.join(certDir, 'key.pem');
const certPath = path.join(certDir, 'cert.pem');

let server;
if (useHttps && fs.existsSync(keyPath) && fs.existsSync(certPath)) {
  const options = {
    key: fs.readFileSync(keyPath),
    cert: fs.readFileSync(certPath),
    // 兼容 macOS LibreSSL / 老旧客户端
    minVersion: 'TLSv1.2',
    maxVersion: 'TLSv1.3',
  };
  server = https.createServer(options, app);
} else {
  if (useHttps) {
    console.warn('HTTPS requested but certs missing. Run: ./scripts/gen_certs.sh');
  }
  server = http.createServer(app);
}
server.listen(PORT, '0.0.0.0', () => {
  attachWsToServer(server);
  console.log(useHttps
    ? `Hi-Doo HTTPS at https://10.0.0.138:${PORT}`
    : `Hi-Doo API at http://10.0.0.138:${PORT}`);
});
