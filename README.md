# BILIMDOS — Stage 1 (index + css + js + sql)

Build жоқ, npm жоқ. Файлдар: `index.html`, `style.css`, `app.js`, `schema.sql`, `manifest.json`, `sw.js`, иконкалар.

## 1. Supabase
1. supabase.com → жаңа жоба.
2. SQL Editor → `schema.sql` мазмунын қойып **Run**.
3. Authentication → Providers → **Google** қосу (Google Cloud Console-дан Client ID/Secret).
   Google-дағы Authorized redirect URI: `https://<PROJECT-REF>.supabase.co/auth/v1/callback`
4. Authentication → URL Configuration:
   - Site URL: `https://<USER>.github.io/<REPO>/`
   - Redirect URLs: `https://<USER>.github.io/<REPO>/` және `http://localhost:8000/`
5. Project Settings → API: **Project URL** және **anon public key** көшіріңіз.

## 2. app.js
Файлдың басындағы екі жолды ауыстырыңыз:
```js
const SUPABASE_URL = 'https://xxxx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJ...';
```
(anon key — ашық кілт, қауіпсіздікті RLS қамтамасыз етеді. `service_role` кілтін ЕШҚАШАН қоспаңыз.)

## 3. GitHub Pages
```bash
git init && git add . && git commit -m "BILIMDOS stage 1"
git branch -M main
git remote add origin https://github.com/<USER>/<REPO>.git
git push -u origin main
```
GitHub → Settings → Pages → Branch: `main` / root → Save. Сілтеме: `https://<USER>.github.io/<REPO>/`

## Жергілікті тест
```bash
python3 -m http.server 8000   # http://localhost:8000
```

## Админ болу
Table Editor → `profiles` → өз жолыңыздағы `role` = `admin`.
