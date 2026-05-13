import { Router } from 'express';

const manifest = {
  version: 1,
  workflow: [
    {
      id: 'input',
      title_zh: '阅读输入',
      title_en: 'Read (input)',
      body_zh: '适龄分级读物、拍照读页与跟读，建立语言输入。',
      body_en: 'Age-leveled texts, page photo-reading, and read-along for rich input.',
    },
    {
      id: 'internalize',
      title_zh: '内化理解',
      title_en: 'Understand (internalize)',
      body_zh: 'AI 开放式提问检验理解，少依赖单纯选择题。',
      body_en: 'Open-ended AI questions to check comprehension—not only multiple choice.',
    },
    {
      id: 'output',
      title_zh: '表达输出',
      title_en: 'Retell (output)',
      body_zh: '录音复述与发音反馈；鼓励中英双语表达。',
      body_en: 'Voice retelling and pronunciation feedback; Chinese and English expression.',
    },
  ],
  engagement: {
    title_zh: '趣味与坚持',
    body_zh: '动画、关卡与小成就，贴合儿童注意力特点；建议每周亲子/师生角色扮演，巩固复述与表达。',
    title_en: 'Engagement',
    body_en: 'Animation, levels, and badges; weekly parent- or teacher-led role-play for retelling skills.',
  },
  offerings: [
    {
      tier: 'trial',
      name_zh: '入门体验',
      name_en: 'Free trial',
      bullets_zh: ['基础流量与核心读-问-复述闭环', '适合初次体验家庭'],
      bullets_en: ['Core read-question-retell loop', 'Great for first-time families'],
    },
    {
      tier: 'paid',
      name_zh: '进阶与陪练',
      name_en: 'Paid coaching',
      bullets_zh: [
        '在线老师辅导、纠错与陪练对练',
        '支持单次课、月卡与次卡（多买多折）',
      ],
      bullets_en: [
        'Live tutoring, corrections, and practice partners',
        'Single sessions, monthly passes, and prepaid bundles',
      ],
    },
  ],
  tutor_ops: {
    title_zh: '师资与结算',
    body_zh: '平台可对接多校老师资源，统一签约与向老师结算；学校侧无需介入商务细节。',
    body_en: 'Central contracting and payouts to tutors across schools; schools stay out of billing ops.',
  },
};

const router = Router();

router.get('/manifest', (_req, res) => {
  res.json(manifest);
});

export default router;
