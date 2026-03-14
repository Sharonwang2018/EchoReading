/**
 * 豆包大模型流式语音识别 WebSocket 代理
 * 文档: https://www.volcengine.com/docs/6561/1354869
 * 使用 X-Api-App-Key / X-Api-Access-Key 鉴权（与录音文件识别相同）
 */
import { WebSocketServer } from 'ws';
import WebSocket from 'ws';
import { randomUUID } from 'crypto';

// 双向流式优化版（推荐，RTF 和首尾字时延更优）
const DOUBAO_ASR_WS = 'wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async';
const APP_ID = process.env.DOUBAO_ASR_APPID || '';
const ACCESS_KEY = process.env.DOUBAO_ASR_ACCESS_KEY || '';
const RESOURCE_ID = process.env.DOUBAO_ASR_RESOURCE_ID || 'volc.seedasr.sauc.duration';

function isConfigured() {
  return APP_ID && ACCESS_KEY;
}

// 协议: 4B header + 4B payload_size (big endian) + payload
function buildHeader(msgType, flags = 0, serialization = 1, compression = 0) {
  const buf = Buffer.alloc(4);
  buf[0] = 0x11;
  buf[1] = ((msgType << 4) | flags) & 0xff;
  buf[2] = ((serialization << 4) | compression) & 0xff;
  buf[3] = 0;
  return buf;
}

export function attachWsToServer(httpServer) {
  const wss = new WebSocketServer({ server: httpServer, path: '/ws/asr-stream' });
  if (!isConfigured()) {
    console.warn('[ASR] 边说边识别未配置: 需 DOUBAO_ASR_APPID, DOUBAO_ASR_ACCESS_KEY');
  }

  wss.on('connection', (clientWs, req) => {
    if (!isConfigured()) {
      clientWs.send(JSON.stringify({ type: 'error', message: '流式识别未配置' }));
      clientWs.close();
      return;
    }
    const url = req.url || '';
    let doubaoWs = null;
    const connectId = randomUUID();

    const connectToDoubao = () => {
      doubaoWs = new WebSocket(DOUBAO_ASR_WS, {
        headers: {
          'X-Api-App-Key': APP_ID,
          'X-Api-Access-Key': ACCESS_KEY,
          'X-Api-Resource-Id': RESOURCE_ID,
          'X-Api-Connect-Id': connectId,
        },
      });

      doubaoWs.on('open', () => {
        const langParam = (url.match(/[?&]lang=([^&]+)/) || [])[1] || 'zh-CN';
        const language = langParam === 'en-US' ? 'en-US' : 'zh-CN';
        const fullRequest = {
          user: { uid: `web_${Date.now()}` },
          audio: {
            format: 'pcm',
            codec: 'raw',
            rate: 16000,
            bits: 16,
            channel: 1,
            language,
          },
          request: {
            model_name: 'bigmodel',
            enable_itn: true,
            enable_punc: true,
            show_utterances: true,
          },
        };
        const payload = Buffer.from(JSON.stringify(fullRequest), 'utf8');
        const header = buildHeader(0x01, 0, 1, 0);
        const sizeBuf = Buffer.alloc(4);
        sizeBuf.writeUInt32BE(payload.length, 0);
        doubaoWs.send(Buffer.concat([header, sizeBuf, payload]));
      });

      doubaoWs.on('message', (data) => {
        if (!Buffer.isBuffer(data) || data.length < 12) return;
        const msgType = (data[1] >> 4) & 0x0f;
        if (msgType === 0x09) {
          const payloadSize = data.readUInt32BE(8);
          const payload = data.slice(12, 12 + payloadSize);
          if (payload.length > 0 && clientWs.readyState === 1) {
            try {
              const json = JSON.parse(payload.toString('utf8'));
              const result = json.result;
              const text = typeof result === 'object'
                ? (result?.text || (result?.utterances?.map((u) => u?.text).filter(Boolean).join('') || ''))
                : '';
              if (text && text.trim()) {
                clientWs.send(JSON.stringify({ type: 'result', text: text.trim() }));
              }
            } catch (_) {}
          }
        } else if (msgType === 0x0f) {
          const errSize = data.readUInt32BE(8);
          const errMsg = data.slice(12, 12 + errSize).toString('utf8');
          if (clientWs.readyState === 1) {
            clientWs.send(JSON.stringify({ type: 'error', message: errMsg || '识别错误' }));
          }
        }
      });

      doubaoWs.on('error', (err) => {
        if (clientWs.readyState === 1) {
          clientWs.send(JSON.stringify({ type: 'error', message: err.message }));
        }
      });

      doubaoWs.on('close', () => {
        if (clientWs.readyState === 1) {
          clientWs.send(JSON.stringify({ type: 'done' }));
        }
      });
    };

    connectToDoubao();

    clientWs.on('message', (data) => {
      if (doubaoWs?.readyState !== 1) return;
      if (typeof data === 'string') {
        try {
          const msg = JSON.parse(data);
          if (msg.type === 'end') {
            const header = buildHeader(0x02, 0x02, 0, 0);
            const sizeBuf = Buffer.alloc(4);
            sizeBuf.writeUInt32BE(0, 0);
            doubaoWs.send(Buffer.concat([header, sizeBuf]));
          }
        } catch (_) {}
        return;
      }
      if (Buffer.isBuffer(data) && data.length > 0) {
        const header = buildHeader(0x02, 0, 0, 0);
        const sizeBuf = Buffer.alloc(4);
        sizeBuf.writeUInt32BE(data.length, 0);
        doubaoWs.send(Buffer.concat([header, sizeBuf, data]));
      }
    });

    clientWs.on('close', () => {
      doubaoWs?.close();
    });
  });
}
