/* =====================================================================
   BILIMDOS — Stage 1 (plain JS, no build step)
   1) Put your Supabase values below (anon key is public by design; RLS protects data)
   ===================================================================== */
const SUPABASE_URL = 'https://qisaqqyjkrbkabempgue.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_JQ9Ju2KI7sgamWfPgT3-nw_kajuBwDk';

const sb = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce' }
});

/* ---------- i18n [kk, ru, en] ---------- */
const IDX = { kk: 0, ru: 1, en: 2 };
const D = {
  tagline: ['Бірге үйренеміз. Бір-бірімізге үйретеміз.', 'Учимся вместе. Учим друг друга.', 'Learn Together. Teach Each Other.'],
  email: ['Электрондық пошта', 'Эл. почта', 'Email'], password: ['Құпиясөз', 'Пароль', 'Password'],
  fullName: ['Аты-жөні', 'Имя и фамилия', 'Full name'], username: ['Пайдаланушы аты', 'Имя пользователя', 'Username'],
  school: ['Мектеп', 'Школа', 'School'], grade: ['Сынып', 'Класс', 'Grade'], city: ['Қала', 'Город', 'City'],
  login: ['Кіру', 'Войти', 'Sign in'], register: ['Тіркелу', 'Регистрация', 'Sign up'],
  google: ['Google арқылы жалғастыру', 'Продолжить через Google', 'Continue with Google'],
  forgot: ['Құпиясөзді ұмыттыңыз ба?', 'Забыли пароль?', 'Forgot password?'],
  haveAcc: ['Аккаунт бар ма? Кіру', 'Есть аккаунт? Войти', 'Have an account? Sign in'],
  noAcc: ['Аккаунт жоқ па? Тіркелу', 'Нет аккаунта? Регистрация', 'No account? Sign up'],
  or: ['немесе', 'или', 'or'],
  checkEmail: ['Поштаңызды тексеріп, сілтемені басыңыз.', 'Проверьте почту и перейдите по ссылке.', 'Check your email and click the link.'],
  sendReset: ['Сілтеме жіберу', 'Отправить ссылку', 'Send reset link'], newPass: ['Жаңа құпиясөз', 'Новый пароль', 'New password'],
  save: ['Сақтау', 'Сохранить', 'Save'], saved: ['Сақталды ✓', 'Сохранено ✓', 'Saved ✓'],
  next: ['Әрі қарай', 'Далее', 'Next'], back: ['Артқа', 'Назад', 'Back'], finish: ['Аяқтау', 'Завершить', 'Finish'],
  iKnow: ['Мен нені білемін?', 'Что я знаю?', 'What I know'], iWant: ['Мен нені үйренгім келеді?', 'Что я хочу изучить?', 'What I want to learn'],
  iKnowHint: ['Басқаларға түсіндіре алатын пәндерді таңдаңыз', 'Выберите, что можете объяснить другим', 'Pick what you can explain to others'],
  iWantHint: ['Басқа студенттерден үйренгіңіз келетін пәндер', 'Что хотите изучить у других', 'Pick what you want to learn'],
  beginner: ['Бастаушы', 'Начинающий', 'Beginner'], intermediate: ['Орта', 'Средний', 'Intermediate'],
  advanced: ['Жоғары', 'Продвинутый', 'Advanced'], ready_to_teach: ['Үйретуге дайын', 'Готов учить', 'Ready to teach'],
  matches: ['Сәйкестік', 'Совпадения', 'Matches'], requests: ['Сұраулар', 'Запросы', 'Requests'], profile: ['Профиль', 'Профиль', 'Profile'],
  signout: ['Шығу', 'Выйти', 'Sign out'], search: ['Іздеу', 'Поиск', 'Search'],
  noMatches: ['Әзірге сәйкестік жоқ. Көбірек пән таңдаңыз немесе кейінірек қараңыз.', 'Совпадений пока нет. Добавьте больше предметов или загляните позже.', 'No matches yet. Add more subjects or check back later.'],
  send: ['Жіберу', 'Отправить', 'Send'], cancel: ['Бас тарту', 'Отмена', 'Cancel'],
  message: ['Хабарлама (міндетті емес)', 'Сообщение (необязательно)', 'Message (optional)'],
  theyTeach: ['Ол сізге үйрете алады', 'Может научить вас', 'Can teach you'], iTeach: ['Сіз оған үйрете аласыз', 'Вы можете научить', 'You can teach'],
  accept: ['Қабылдау', 'Принять', 'Accept'], decline: ['Қабылдамау', 'Отклонить', 'Decline'],
  complete: ['Аяқталды деп белгілеу', 'Отметить завершённым', 'Mark completed'],
  pending: ['Күтуде', 'Ожидает', 'Pending'], accepted: ['Қабылданды', 'Принят', 'Accepted'], declined: ['Қабылданбады', 'Отклонён', 'Declined'],
  completed: ['Аяқталды', 'Завершён', 'Completed'], cancelled: ['Бас тартылды', 'Отменён', 'Cancelled'],
  incoming: ['Кіріс', 'Входящие', 'Incoming'], outgoing: ['Шығыс', 'Исходящие', 'Outgoing'], none: ['Бос', 'Пусто', 'Nothing here'],
  needHelp: ['Маған көмек керек', 'Мне нужна помощь', 'I need help'], canHelp: ['Мен көмектесе аламын', 'Я могу помочь', 'I can help'],
  showSchool: ['Мектебімді көрсету', 'Показывать школу', 'Show my school'], showCity: ['Қаламды көрсету', 'Показывать город', 'Show my city'],
  publicProfile: ['Профиль ашық (сәйкестікте көрінемін)', 'Профиль открыт (виден в совпадениях)', 'Public profile (appear in matches)'],
  avatar: ['Профиль суреті', 'Фото профиля', 'Profile picture'],
  installTitle: ['Қолданбаны орнату', 'Установить приложение', 'Install the app'],
  installIOS: ['iPhone: Safari-де «Бөлісу» → «Басты экранға қосу».', 'iPhone: в Safari «Поделиться» → «На экран Домой».', 'iPhone: in Safari tap Share → Add to Home Screen.'],
  installAndroid: ['Android: Chrome мәзірі → «Қолданбаны орнату».', 'Android: меню Chrome → «Установить приложение».', 'Android: Chrome menu → Install app.'],
  installBtn: ['Орнату', 'Установить', 'Install'], loading: ['Жүктелуде…', 'Загрузка…', 'Loading…'], step: ['Қадам', 'Шаг', 'Step'],
  invalidUsername: ['3–24 таңба: a-z, 0-9, _', '3–24 символа: a-z, 0-9, _', '3–24 chars: a-z, 0-9, _'],
  shortPass: ['Құпиясөз кемінде 8 таңба', 'Пароль минимум 8 символов', 'Password must be 8+ characters'],
  needOne: ['Кемінде бір пән таңдаңыз', 'Выберите хотя бы один предмет', 'Pick at least one subject'],
  alreadySent: ['Бұл сұрау бұрын жіберілген', 'Такой запрос уже отправлен', 'You already sent this request'],
  sent: ['Сұрау жіберілді ✓', 'Запрос отправлен ✓', 'Request sent ✓'], match: ['сәйкес', 'совпадение', 'match'], refresh: ['Жаңарту', 'Обновить', 'Refresh'],
  gradeRange: ['Сынып 1–12 аралығында', 'Класс от 1 до 12', 'Grade must be 1–12'], bio: ['Өзім туралы', 'О себе', 'About me']
};
const LEVELS = ['beginner', 'intermediate', 'advanced', 'ready_to_teach'];

/* ---------- state & helpers ---------- */
const S = { session: null, profile: null, subjects: [], cats: [], lang: localStorage.getItem('lang') || 'kk',
  known: {}, want: {}, step: 1, file: null, tab: 'know', rtab: 'in', installEvt: null,
  form: { full_name: '', school: '', grade: '', city: '', bio: '', show_school: false, show_city: false, profile_public: true } };
const $ = (s) => document.querySelector(s);
const t = (k) => (D[k] || [k, k, k])[IDX[S.lang]];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const nm = (o) => o['name_' + S.lang];
const sname = (id) => { const s = S.subjects.find((x) => x.id === id); return s ? esc(nm(s)) : '…'; };
const base = () => location.origin + location.pathname;
const avatar = (url, name, size = 48) => url
  ? `<img class="avatar" src="${esc(url)}" alt="" style="width:${size}px;height:${size}px">`
  : `<div class="avatar ph" style="width:${size}px;height:${size}px;font-size:${size * 0.4}px">${esc((name || '?').trim().charAt(0).toUpperCase())}</div>`;
const langSwitch = () => `<div class="langs">${['kk', 'ru', 'en'].map((l) => `<button class="${S.lang === l ? 'on' : ''}" data-act="lang" data-v="${l}">${l}</button>`).join('')}</div>`;
const go = (h) => { if (location.hash === h) render(); else location.hash = h; };

/* ---------- data ---------- */
async function loadCatalog() {
  if (S.subjects.length) return;
  const [s, c] = await Promise.all([
    sb.from('subjects').select('*').eq('is_active', true).order('sort_order'),
    sb.from('subject_categories').select('*').order('sort_order')]);
  S.subjects = s.data || []; S.cats = c.data || [];
}
async function loadProfile() {
  if (!S.session) { S.profile = null; return; }
  for (let i = 0; i < 3; i++) {
    const { data } = await sb.from('profiles').select('*').eq('id', S.session.user.id).maybeSingle();
    if (data) { S.profile = data; fillForm(); return; }
    await new Promise((r) => setTimeout(r, 500));
  }
  S.profile = null;
}
function fillForm() {
  const p = S.profile;
  S.form = { full_name: p.full_name, school: p.school || '', grade: p.grade ?? '', city: p.city || '', bio: p.bio || '',
    show_school: p.show_school, show_city: p.show_city, profile_public: p.profile_public };
}
async function loadMySubjects() {
  const uid = S.session.user.id;
  const [k, w] = await Promise.all([
    sb.from('student_known_subjects').select('subject_id, level').eq('student_id', uid),
    sb.from('student_learning_interests').select('subject_id, level').eq('student_id', uid)]);
  const m = (r) => Object.fromEntries((r.data || []).map((x) => [x.subject_id, x.level]));
  S.known = m(k); S.want = m(w);
}
async function saveMySubjects() {
  const uid = S.session.user.id;
  for (const [table, map] of [['student_known_subjects', S.known], ['student_learning_interests', S.want]]) {
    const d = await sb.from(table).delete().eq('student_id', uid); if (d.error) throw d.error;
    const rows = Object.entries(map).map(([id, level]) => ({ student_id: uid, subject_id: Number(id), level }));
    if (rows.length) { const i = await sb.from(table).insert(rows); if (i.error) throw i.error; }
  }
}
async function uploadAvatar(file) {
  if (file.size > 3 * 1024 * 1024) throw new Error('Max 3 MB');
  if (!file.type.startsWith('image/')) throw new Error('Image only');
  const uid = S.session.user.id, ext = (file.name.split('.').pop() || 'jpg').toLowerCase().replace(/[^a-z0-9]/g, '');
  const path = `${uid}/avatar.${ext}`;
  const { error } = await sb.storage.from('avatars').upload(path, file, { upsert: true, contentType: file.type });
  if (error) throw error;
  return sb.storage.from('avatars').getPublicUrl(path).data.publicUrl + '?t=' + Date.now();
}
function validateForm() {
  if (!S.form.full_name.trim()) return t('fullName');
  const g = S.form.grade === '' ? null : Number(S.form.grade);
  if (g !== null && (g < 1 || g > 12)) return t('gradeRange');
  return '';
}
async function saveProfile(extra = {}) {
  const uid = S.session.user.id, f = S.form;
  let avatar_url = S.profile.avatar_url;
  if (S.file) avatar_url = await uploadAvatar(S.file);
  const { error } = await sb.from('profiles').update({
    full_name: f.full_name.trim(), school: f.school || null, grade: f.grade === '' ? null : Number(f.grade), city: f.city || null,
    bio: f.bio || null, avatar_url, show_school: f.show_school, show_city: f.show_city, profile_public: f.profile_public, ...extra }).eq('id', uid);
  if (error) throw error;
  await saveMySubjects();
  await sb.rpc('refresh_my_matches');
  S.file = null; await loadProfile();
}

/* ---------- picker ---------- */
function pickerBody(kind) {
  const m = S[kind];
  return `<p class="muted">${Object.keys(m).length} / 45</p>` + S.cats.map((c) => `<h3>${esc(nm(c))}</h3>` +
    S.subjects.filter((s) => s.category_id === c.id).map((s) => {
      const on = m[s.id];
      return `<div class="subj ${on ? 'on' : ''}" data-name="${esc(nm(s).toLowerCase())}">
        <button type="button" data-act="toggle" data-kind="${kind}" data-id="${s.id}"><span class="box"></span>${esc(nm(s))}</button>
        ${on ? `<select data-level data-kind="${kind}" data-id="${s.id}">${LEVELS.map((l) => `<option value="${l}" ${l === on ? 'selected' : ''}>${t(l)}</option>`).join('')}</select>` : ''}</div>`;
    }).join('')).join('');
}
const picker = (kind) => `<input class="input" data-search placeholder="${t('search')}" style="margin-bottom:8px"><div id="picker">${pickerBody(kind)}</div>`;
function applySearch() {
  const q = ($('[data-search]')?.value || '').toLowerCase();
  document.querySelectorAll('#picker .subj').forEach((el) => el.classList.toggle('hidden', !el.dataset.name.includes(q)));
}

/* ---------- views ---------- */
const NAV = [['matches', 'matches', '🤝'], ['requests', 'requests', '💬'], ['profile', 'profile', '👤']];
function shell(active, inner) {
  const p = S.profile;
  return `<div class="app"><aside class="side"><div class="logo">BILIMDOS</div><div class="tag">${t('tagline')}</div>
    <nav>${NAV.map((n) => `<a href="#/${n[0]}" class="${active === n[0] ? 'act' : ''}">${n[2]} ${t(n[1])}</a>`).join('')}</nav>
    <div class="dark">${langSwitch()}</div>
    <div class="me">${avatar(p.avatar_url, p.full_name, 36)}<div><b>${esc(p.full_name)}</b><br><button class="link" data-act="signout">${t('signout')}</button></div></div></aside>
    <main><div class="topbar"><b>BILIMDOS</b>${langSwitch()}</div><div class="wrap">${inner}</div></main>
    <nav class="bottom">${NAV.map((n) => `<a href="#/${n[0]}" class="${active === n[0] ? 'act' : ''}"><span>${n[2]}</span>${t(n[1])}</a>`).join('')}</nav></div>`;
}

function authView(mode) {
  const reg = mode === 'register';
  return `<div class="authwrap"><div class="authbox"><div class="hd"><h1>BILIMDOS</h1><p>${t('tagline')}</p></div>
    <form id="authForm" class="card" data-mode="${mode}" style="padding:24px">
      <button type="button" class="btn block" data-act="google">
        <svg width="18" height="18" viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.5 0 6.6 1.2 9.1 3.6l6.8-6.8C35.8 2.4 30.3 0 24 0 14.6 0 6.5 5.4 2.6 13.2l7.9 6.1C12.4 13.6 17.7 9.5 24 9.5z"/><path fill="#4285F4" d="M46.5 24.5c0-1.6-.1-3.1-.4-4.5H24v9h12.7c-.6 3-2.3 5.5-4.8 7.2l7.6 5.9c4.4-4.1 7-10.1 7-17.6z"/><path fill="#FBBC05" d="M10.5 28.7a14.5 14.5 0 0 1 0-9.4l-7.9-6.1a24 24 0 0 0 0 21.6l7.9-6.1z"/><path fill="#34A853" d="M24 48c6.5 0 11.9-2.1 15.9-5.8l-7.6-5.9c-2.1 1.4-4.9 2.3-8.3 2.3-6.3 0-11.6-4.1-13.5-9.8l-7.9 6.1C6.5 42.6 14.6 48 24 48z"/></svg>${t('google')}</button>
      <div class="or">${t('or')}</div>
      ${reg ? `<label class="l">${t('fullName')}</label><input class="input" name="full_name" required>
        <label class="l">${t('username')}</label><input class="input" name="username" required autocapitalize="none">` : ''}
      <label class="l">${t('email')}</label><input class="input" type="email" name="email" required autocomplete="email">
      <label class="l">${t('password')}</label><input class="input" type="password" name="password" required autocomplete="${reg ? 'new-password' : 'current-password'}">
      ${reg ? `<label class="l">${t('school')}</label><input class="input" name="school">
        <div class="grid2"><div><label class="l">${t('grade')}</label><input class="input" type="number" min="1" max="12" name="grade"></div>
        <div><label class="l">${t('city')}</label><input class="input" name="city"></div></div>` : ''}
      <p class="err" id="msg"></p>
      <button class="btn primary block" style="margin-top:8px">${reg ? t('register') : t('login')}</button>
      <div class="row" style="margin-top:12px;font-size:14px"><a class="link" href="#/${reg ? 'login' : 'register'}">${reg ? t('haveAcc') : t('noAcc')}</a>
        ${reg ? '' : `<a class="link" style="text-align:right;color:#64748b" href="#/forgot">${t('forgot')}</a>`}</div>
    </form>${langSwitch().replace('class="langs"', 'class="langs dark"')}</div></div>`;
}
const forgotView = () => `<div class="authwrap"><form id="forgotForm" class="card authbox" style="padding:24px"><label class="l">${t('email')}</label>
  <input class="input" type="email" name="email" required><button class="btn primary block" style="margin-top:12px">${t('sendReset')}</button>
  <p id="msg" class="muted"></p><a class="link" href="#/login">${t('login')}</a></form></div>`;
const resetView = () => `<div class="authwrap"><form id="resetForm" class="card authbox" style="padding:24px"><label class="l">${t('newPass')}</label>
  <input class="input" type="password" name="password" required autocomplete="new-password"><p class="err" id="msg"></p>
  <button class="btn primary block">${t('save')}</button></form></div>`;

const profileFields = () => `
  <div class="row" style="margin-bottom:8px">${avatar(S.file ? URL.createObjectURL(S.file) : S.profile.avatar_url, S.form.full_name, 64)}
    <div><label class="l">${t('avatar')}</label><input type="file" accept="image/*" data-file></div></div>
  <label class="l">${t('fullName')}</label><input class="input" data-f="full_name" value="${esc(S.form.full_name)}">
  <label class="l">${t('school')}</label><input class="input" data-f="school" value="${esc(S.form.school)}">
  <div class="grid2"><div><label class="l">${t('grade')}</label><input class="input" type="number" min="1" max="12" data-f="grade" value="${esc(S.form.grade)}"></div>
  <div><label class="l">${t('city')}</label><input class="input" data-f="city" value="${esc(S.form.city)}"></div></div>`;
const privacyFields = () => [['show_school', 'showSchool'], ['show_city', 'showCity'], ['profile_public', 'publicProfile']]
  .map(([k, l]) => `<label class="chk"><input type="checkbox" data-f="${k}" ${S.form[k] ? 'checked' : ''}>${t(l)}</label>`).join('');

function onboardingView() {
  const s = S.step;
  const body = s === 1 ? `<div class="card">${profileFields()}${privacyFields()}</div>`
    : s === 2 ? `<h2>${t('iKnow')}</h2><p class="muted">${t('iKnowHint')}</p>${picker('known')}`
    : `<h2>${t('iWant')}</h2><p class="muted">${t('iWantHint')}</p>${picker('want')}`;
  return `<div class="wrap" style="max-width:560px"><div class="row"><b style="color:var(--navy)">BILIMDOS</b><div class="auto">${langSwitch()}</div></div>
    <p class="muted" style="color:var(--royal);font-weight:600">${t('step')} ${s}/3</p><div class="progress"><i style="width:${s / 3 * 100}%"></i></div>
    ${body}<p class="err" id="msg"></p></div>
    <div class="footbar"><div>${s > 1 ? `<button class="btn" data-act="back">${t('back')}</button>` : ''}
    ${s < 3 ? `<button class="btn primary" data-act="next">${t('next')}</button>` : `<button class="btn primary" data-act="finish">${t('finish')}</button>`}</div></div>`;
}

function matchCard(m) {
  const needHelp = m.they_teach_me.length > 0, opts = needHelp ? m.they_teach_me : m.i_teach_them;
  const chips = (ids) => ids.map((id) => `<span class="chip">${sname(id)}</span>`).join('');
  return `<div class="card" data-mid="${esc(m.student_id)}" data-kind="${needHelp ? 'need_help' : 'can_help'}">
    <div class="mhead">${avatar(m.avatar_url, m.full_name)}<div class="info"><b>${esc(m.full_name)}</b>
      <div class="muted">@${esc(m.username)}${m.grade ? ' · ' + m.grade + ' ' + t('grade').toLowerCase() : ''}${m.school ? ' · ' + esc(m.school) : ''}</div></div>
      <div class="score"><b>${m.score}%</b><small>${t('match')}</small></div></div>
    ${m.they_teach_me.length ? `<div class="sub">${t('theyTeach')}</div>${chips(m.they_teach_me)}` : ''}
    ${m.i_teach_them.length ? `<div class="sub">${t('iTeach')}</div>${chips(m.i_teach_them)}` : ''}
    <button class="btn primary block" data-act="openreq" style="margin-top:8px">${t(needHelp ? 'needHelp' : 'canHelp')} →</button>
    <div class="reqform hidden" style="margin-top:8px">
      <select class="input" name="subject">${opts.map((id) => `<option value="${id}">${sname(id)}</option>`).join('')}</select>
      <textarea class="input" name="message" rows="2" maxlength="1000" placeholder="${t('message')}" style="margin-top:8px"></textarea>
      <div class="row" style="margin-top:8px"><button class="btn primary" data-act="sendreq">${t('send')}</button><button class="btn" data-act="closereq">${t('cancel')}</button></div></div>
    <p class="muted reqmsg"></p></div>`;
}
async function matchesView() {
  $('#app').innerHTML = shell('matches', `<div class="row" style="margin-bottom:16px"><h1>${t('matches')}</h1><div class="auto"><button class="btn" data-act="refreshm">${t('refresh')}</button></div></div><p class="muted">${t('loading')}</p>`);
  const r = await sb.rpc('refresh_my_matches');
  const { data, error } = r.error ? { error: r.error } : await sb.rpc('get_my_matches', { min_score: 1, lim: 50 });
  const list = data || [];
  $('.wrap').innerHTML = `<div class="row" style="margin-bottom:16px"><h1>${t('matches')}</h1><div class="auto"><button class="btn" data-act="refreshm">${t('refresh')}</button></div></div>
    ${error ? `<p class="err">${esc(error.message)}</p>` : ''}
    ${!list.length && !error ? `<div class="card muted">${t('noMatches')}</div>` : list.map(matchCard).join('')}`;
}
async function requestsView() {
  const uid = S.session.user.id;
  $('#app').innerHTML = shell('requests', `<h1>${t('requests')}</h1><p class="muted">${t('loading')}</p>`);
  const { data, error } = await sb.from('learning_requests').select('*').or(`requester_id.eq.${uid},recipient_id.eq.${uid}`).order('created_at', { ascending: false });
  const rows = data || [];
  const ids = [...new Set(rows.map((r) => (r.requester_id === uid ? r.recipient_id : r.requester_id)))];
  let people = {};
  if (ids.length) { const { data: ps } = await sb.from('public_profiles').select('id, full_name, avatar_url').in('id', ids); people = Object.fromEntries((ps || []).map((p) => [p.id, p])); }
  const shown = rows.filter((r) => (S.rtab === 'in' ? r.recipient_id === uid : r.requester_id === uid));
  $('.wrap').innerHTML = `<h1 style="margin-bottom:12px">${t('requests')}</h1>
    <div class="tabs">${['in', 'out'].map((k) => `<button class="btn ${S.rtab === k ? 'dark' : ''}" data-act="rtab" data-v="${k}">${t(k === 'in' ? 'incoming' : 'outgoing')}</button>`).join('')}</div>
    <p class="err" id="msg">${error ? esc(error.message) : ''}</p>
    ${shown.length ? shown.map((r) => {
      const o = people[r.requester_id === uid ? r.recipient_id : r.requester_id] || {}, inc = r.recipient_id === uid;
      return `<div class="card" data-rid="${r.id}"><div class="mhead">${avatar(o.avatar_url, o.full_name, 40)}<div class="info"><b>${esc(o.full_name || '—')}</b>
        <div class="muted">${t(r.kind === 'need_help' ? 'needHelp' : 'canHelp')} · ${sname(r.subject_id)}</div></div><span class="chip">${t(r.status)}</span></div>
        ${r.message ? `<p style="font-size:14px;margin:0 0 8px">${esc(r.message)}</p>` : ''}
        <div class="row">${inc && r.status === 'pending' ? `<button class="btn primary" data-act="setstatus" data-v="accepted">${t('accept')}</button><button class="btn" data-act="setstatus" data-v="declined">${t('decline')}</button>` : ''}
        ${!inc && r.status === 'pending' ? `<button class="btn" data-act="setstatus" data-v="cancelled">${t('cancel')}</button>` : ''}
        ${r.status === 'accepted' ? `<button class="btn" data-act="setstatus" data-v="completed">${t('complete')}</button>` : ''}</div></div>`;
    }).join('') : `<div class="card muted">${t('none')}</div>`}`;
}
function profileView() {
  const p = S.profile, kind = S.tab === 'know' ? 'known' : 'want';
  $('#app').innerHTML = shell('profile', `<h1 style="margin-bottom:12px">${t('profile')}</h1>
    <div class="card"><p class="muted" style="margin:0 0 8px">@${esc(p.username)}</p>${profileFields()}
    <label class="l">${t('bio')}</label><textarea class="input" rows="2" maxlength="500" data-f="bio">${esc(S.form.bio)}</textarea>${privacyFields()}</div>
    <div class="tabs">${['know', 'want'].map((k) => `<button class="btn ${S.tab === k ? 'dark' : ''}" data-act="ptab" data-v="${k}">${t(k === 'know' ? 'iKnow' : 'iWant')}</button>`).join('')}</div>
    ${picker(kind)}
    <div class="sticky"><button class="btn primary" data-act="saveprofile">${t('save')}</button><span class="muted" id="msg"></span></div>
    ${window.matchMedia('(display-mode: standalone)').matches ? '' : `<div class="card"><b>${t('installTitle')}</b><p class="muted">${t('installIOS')}</p><p class="muted">${t('installAndroid')}</p>
      ${S.installEvt ? `<button class="btn primary" data-act="install">${t('installBtn')}</button>` : ''}</div>`}
    <button class="btn block" data-act="signout">${t('signout')}</button>`);
}

/* ---------- router ---------- */
let booted = false, guesting = false;
async function guestLogin() {
  guesting = true;
  try {
    const id = Math.random().toString(36).slice(2, 10);
    const { data, error } = await sb.auth.signInAnonymously({
      options: { data: { full_name: 'Қонақ', username: 'guest_' + id, school: '', grade: '', city: '' } } });
    if (error || !data.session) return;
    S.session = data.session;
    await loadProfile();
    if (S.profile && !S.profile.onboarding_done) {
      await sb.from('profiles').update({ onboarding_done: true }).eq('id', S.session.user.id);
      await loadProfile();
    }
  } finally { guesting = false; }
}
async function render() {
  if (!booted) return;
  if (guesting) { $('#app').innerHTML = `<p class="center muted" style="padding:40px">${t('loading')}</p>`; return; }
  document.documentElement.lang = S.lang;
  const route = (location.hash.replace('#/', '') || '').split('?')[0];
  const app = $('#app');
  if (!S.session) {
    app.innerHTML = route === 'register' ? authView('register') : route === 'forgot' ? forgotView() : authView('login');
    return;
  }
  if (!S.profile) { app.innerHTML = `<p class="center muted" style="padding:40px">${t('loading')}</p>`; return; }
  if (route === 'reset') { app.innerHTML = resetView(); return; }
  await loadCatalog();
  if (!S.profile.onboarding_done) {
    if (!Object.keys(S.known).length && !Object.keys(S.want).length) await loadMySubjects();
    app.innerHTML = onboardingView(); return;
  }
  if (!Object.keys(S.known).length && !Object.keys(S.want).length) await loadMySubjects();
  if (route === 'requests') return requestsView();
  if (route === 'profile') return profileView();
  if (route !== 'matches') { location.replace('#/matches'); return; }
  return matchesView();
}
window.addEventListener('hashchange', render);

/* ---------- events ---------- */
const msg = (text, ok) => { const m = $('#msg'); if (m) { m.textContent = text; m.className = ok ? 'ok' : 'err'; } };

document.addEventListener('input', (e) => {
  const el = e.target;
  if (el.dataset.f) S.form[el.dataset.f] = el.type === 'checkbox' ? el.checked : el.value;
  if (el.dataset.search !== undefined) applySearch();
});
document.addEventListener('change', (e) => {
  const el = e.target;
  if (el.dataset.f && el.type === 'checkbox') S.form[el.dataset.f] = el.checked;
  if (el.dataset.file !== undefined) { S.file = el.files[0] || null; if (S.file) { const img = el.closest('.row').firstElementChild; img.outerHTML = avatar(URL.createObjectURL(S.file), S.form.full_name, 64); } }
  if (el.dataset.level !== undefined) S[el.dataset.kind][el.dataset.id] = el.value;
});

const A = {
  lang: (el) => { S.lang = el.dataset.v; localStorage.setItem('lang', S.lang); render(); },
  signout: async () => { await sb.auth.signOut(); S.known = {}; S.want = {}; S.step = 1; location.hash = '#/login'; },
  google: async () => {
    const { error } = await sb.auth.signInWithOAuth({ provider: 'google', options: { redirectTo: base() } });
    if (error) msg(error.message);
  },
  toggle: (el) => {
    const m = S[el.dataset.kind], id = el.dataset.id;
    if (m[id]) delete m[id]; else m[id] = el.dataset.kind === 'known' ? 'intermediate' : 'beginner';
    $('#picker').innerHTML = pickerBody(el.dataset.kind); applySearch();
  },
  next: () => { const e = S.step === 1 ? validateForm() : ''; if (e) return msg(e); S.step++; render(); window.scrollTo(0, 0); },
  back: () => { S.step--; render(); window.scrollTo(0, 0); },
  finish: async (el) => {
    if (!Object.keys(S.known).length && !Object.keys(S.want).length) return msg(t('needOne'));
    el.disabled = true;
    try { await saveProfile({ onboarding_done: true }); location.hash = '#/matches'; render(); }
    catch (ex) { msg(ex.message || String(ex)); el.disabled = false; }
  },
  saveprofile: async (el) => {
    const e = validateForm(); if (e) return msg(e);
    el.disabled = true;
    try { await saveProfile(); msg(t('saved'), true); } catch (ex) { msg(ex.message || String(ex)); }
    el.disabled = false;
  },
  ptab: (el) => { S.tab = el.dataset.v; profileView(); },
  rtab: (el) => { S.rtab = el.dataset.v; requestsView(); },
  refreshm: () => matchesView(),
  openreq: (el) => { const c = el.closest('.card'); c.querySelector('.reqform').classList.remove('hidden'); el.classList.add('hidden'); },
  closereq: (el) => { const c = el.closest('.card'); c.querySelector('.reqform').classList.add('hidden'); c.querySelector('[data-act=openreq]').classList.remove('hidden'); },
  sendreq: async (el) => {
    const c = el.closest('.card'), out = c.querySelector('.reqmsg'); el.disabled = true;
    const { error } = await sb.from('learning_requests').insert({
      requester_id: S.session.user.id, recipient_id: c.dataset.mid, subject_id: Number(c.querySelector('[name=subject]').value),
      kind: c.dataset.kind, message: c.querySelector('[name=message]').value.trim() || null });
    el.disabled = false;
    out.textContent = error ? (error.code === '23505' ? t('alreadySent') : error.message) : t('sent');
    if (!error) A.closereq(el);
  },
  setstatus: async (el) => {
    const { error } = await sb.from('learning_requests').update({ status: el.dataset.v }).eq('id', el.closest('.card').dataset.rid);
    if (error) msg(error.message); else requestsView();
  },
  install: () => S.installEvt && S.installEvt.prompt()
};
document.addEventListener('click', (e) => {
  const el = e.target.closest('[data-act]');
  if (el && A[el.dataset.act]) A[el.dataset.act](el);
});

const H = {
  authForm: async (form) => {
    const f = Object.fromEntries(new FormData(form)), reg = form.dataset.mode === 'register';
    if (f.password.length < 8) return msg(t('shortPass'));
    if (reg) {
      if (!/^[a-z0-9_]{3,24}$/.test(f.username)) return msg(t('invalidUsername'));
      if (f.grade && (Number(f.grade) < 1 || Number(f.grade) > 12)) return msg(t('gradeRange'));
    }
    const btn = form.querySelector('.btn.primary'); btn.disabled = true;
    const res = reg
      ? await sb.auth.signUp({ email: f.email.trim(), password: f.password,
          options: { emailRedirectTo: base(), data: { full_name: f.full_name.trim(), username: f.username, school: f.school, grade: f.grade, city: f.city } } })
      : await sb.auth.signInWithPassword({ email: f.email.trim(), password: f.password });
    btn.disabled = false;
    if (res.error) return msg(res.error.message);
    if (reg && !res.data.session) msg(t('checkEmail'), true);
  },
  forgotForm: async (form) => {
    const { error } = await sb.auth.resetPasswordForEmail(new FormData(form).get('email').trim(), { redirectTo: base() });
    msg(error ? error.message : t('checkEmail'), !error);
  },
  resetForm: async (form) => {
    const pw = new FormData(form).get('password');
    if (pw.length < 8) return msg(t('shortPass'));
    const { error } = await sb.auth.updateUser({ password: pw });
    if (error) msg(error.message); else { location.hash = '#/matches'; render(); }
  }
};
document.addEventListener('submit', (e) => { const h = H[e.target.id]; if (h) { e.preventDefault(); h(e.target); } });

window.addEventListener('beforeinstallprompt', (e) => { e.preventDefault(); S.installEvt = e; });

/* ---------- boot ---------- */
(async function boot() {
  if (SUPABASE_URL.includes('YOUR-PROJECT')) {
    $('#app').innerHTML = '<p class="center err" style="padding:40px">app.js: SUPABASE_URL / SUPABASE_ANON_KEY толтырыңыз.</p>'; return;
  }
  sb.auth.onAuthStateChange((event, session) => {
    // defer: never call supabase from inside this callback synchronously
    if (event === 'TOKEN_REFRESHED') { S.session = session; return; }
    if (event === 'SIGNED_IN' && S.profile && session && S.profile.id === session.user.id) { S.session = session; return; }
    setTimeout(async () => {
      S.session = session;
      if (event === 'PASSWORD_RECOVERY') location.hash = '#/reset';
      if (event === 'SIGNED_OUT') { S.profile = null; S.known = {}; S.want = {}; }
      else if (session) await loadProfile();
      booted = true; render();
    }, 0);
  });
  const { data } = await sb.auth.getSession();
  S.session = data.session;
  const r0 = (location.hash.replace('#/', '') || '').split('?')[0];
  if (!S.session && !['login', 'register', 'forgot', 'reset'].includes(r0)) await guestLogin();
  await loadProfile(); booted = true; render();
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
})();
