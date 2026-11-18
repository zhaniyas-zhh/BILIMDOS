-- =====================================================================
-- BILIMDOS — Stage 1: schema, RLS, matching, seed (45 subjects)
-- Run in Supabase SQL Editor (or as a migration). Idempotent where practical.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- ENUMS ----------
do $$ begin
  create type app_role      as enum ('student','moderator','admin');
  create type skill_level   as enum ('beginner','intermediate','advanced','ready_to_teach');
  create type request_kind  as enum ('need_help','can_help');
  create type request_status as enum ('pending','accepted','declined','cancelled','completed');
  create type post_kind     as enum ('lesson','note','explanation','presentation','video','exercise','resource','question','discussion','project');
  create type content_status as enum ('published','hidden','removed');
  create type report_status as enum ('open','reviewed','actioned','dismissed');
  create type session_status as enum ('active','completed','abandoned');
  create type room_visibility as enum ('public','private');
exception when duplicate_object then null; end $$;

-- ---------- CATALOG ----------
create table if not exists subject_categories (
  id        smallint generated always as identity primary key,
  slug      text not null unique,
  name_kk   text not null, name_ru text not null, name_en text not null,
  sort_order smallint not null default 0
);

create table if not exists subjects (
  id          smallint generated always as identity primary key,
  category_id smallint not null references subject_categories(id) on update cascade,
  slug        text not null unique,
  name_kk     text not null, name_ru text not null, name_en text not null,
  is_active   boolean not null default true,
  sort_order  smallint not null default 0
);
create index if not exists subjects_category_idx on subjects(category_id);

-- ---------- PROFILES ----------
create table if not exists profiles (
  id             uuid primary key references auth.users(id) on delete cascade,
  username       text not null,
  full_name      text not null,
  avatar_url     text,
  bio            text check (char_length(bio) <= 500),
  school         text,
  grade          smallint check (grade between 1 and 12),
  city           text,
  language       text not null default 'kk' check (language in ('kk','ru','en')),
  role           app_role not null default 'student',
  -- privacy
  profile_public boolean not null default true,
  show_school    boolean not null default false,
  show_city      boolean not null default false,
  -- availability slots e.g. {'mon_evening','sat_morning'}
  availability   text[] not null default '{}',
  onboarding_done boolean not null default false,
  is_banned      boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint username_format check (username ~ '^[a-z0-9_]{3,24}$')
);
create unique index if not exists profiles_username_uq on profiles (lower(username));
create index if not exists profiles_grade_idx on profiles(grade);

create table if not exists student_known_subjects (
  student_id uuid not null references profiles(id) on delete cascade,
  subject_id smallint not null references subjects(id) on delete cascade,
  level      skill_level not null default 'intermediate',
  created_at timestamptz not null default now(),
  primary key (student_id, subject_id)
);
create index if not exists sks_subject_idx on student_known_subjects(subject_id);

create table if not exists student_learning_interests (
  student_id uuid not null references profiles(id) on delete cascade,
  subject_id smallint not null references subjects(id) on delete cascade,
  level      skill_level not null default 'beginner',
  created_at timestamptz not null default now(),
  primary key (student_id, subject_id)
);
create index if not exists sli_subject_idx on student_learning_interests(subject_id);

-- ---------- SOCIAL GRAPH ----------
create table if not exists follows (
  follower_id uuid not null references profiles(id) on delete cascade,
  followee_id uuid not null references profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);
create table if not exists blocks (
  blocker_id uuid not null references profiles(id) on delete cascade,
  blocked_id uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ---------- PEER LEARNING ----------
create table if not exists learning_requests (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(id) on delete cascade,
  recipient_id uuid not null references profiles(id) on delete cascade,
  subject_id   smallint not null references subjects(id),
  kind         request_kind not null,
  topic        text check (char_length(topic) <= 120),
  message      text check (char_length(message) <= 1000),
  status       request_status not null default 'pending',
  is_solved    boolean not null default false,
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> recipient_id)
);
-- no duplicate open requests between the same pair for the same subject/kind
create unique index if not exists lr_no_dup_pending
  on learning_requests(requester_id, recipient_id, subject_id, kind) where status = 'pending';
create index if not exists lr_recipient_idx on learning_requests(recipient_id, status);
create index if not exists lr_requester_idx on learning_requests(requester_id, status);

create table if not exists reviews (
  id          uuid primary key default gen_random_uuid(),
  request_id  uuid not null references learning_requests(id) on delete cascade,
  reviewer_id uuid not null references profiles(id) on delete cascade,
  reviewee_id uuid not null references profiles(id) on delete cascade,
  rating      smallint not null check (rating between 1 and 5),
  comment     text check (char_length(comment) <= 500),
  created_at  timestamptz not null default now(),
  unique (request_id, reviewer_id),
  check (reviewer_id <> reviewee_id)
);
create index if not exists reviews_reviewee_idx on reviews(reviewee_id);

-- cached compatibility (user_a < user_b); refreshed by refresh_my_matches()
create table if not exists matches (
  user_a     uuid not null references profiles(id) on delete cascade,
  user_b     uuid not null references profiles(id) on delete cascade,
  score      smallint not null check (score between 0 and 100),
  a_can_teach_b smallint[] not null default '{}',   -- subject ids A teaches that B wants
  b_can_teach_a smallint[] not null default '{}',
  computed_at timestamptz not null default now(),
  primary key (user_a, user_b),
  check (user_a < user_b)
);
create index if not exists matches_b_idx on matches(user_b, score desc);
create index if not exists matches_a_idx on matches(user_a, score desc);

create table if not exists conversations (
  id         uuid primary key default gen_random_uuid(),
  user_a     uuid not null references profiles(id) on delete cascade,
  user_b     uuid not null references profiles(id) on delete cascade,
  request_id uuid references learning_requests(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (user_a, user_b),
  check (user_a < user_b)
);

create table if not exists messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id       uuid not null references profiles(id) on delete cascade,
  body            text check (char_length(body) <= 4000),
  attachment_url  text,
  read_at         timestamptz,
  created_at      timestamptz not null default now(),
  check (body is not null or attachment_url is not null)
);
create index if not exists messages_conv_idx on messages(conversation_id, created_at desc);

-- ---------- CONTENT ----------
create table if not exists posts (
  id          uuid primary key default gen_random_uuid(),
  author_id   uuid not null references profiles(id) on delete cascade,
  kind        post_kind not null,
  subject_id  smallint references subjects(id),
  topic       text,
  title       text not null check (char_length(title) between 3 and 160),
  body        text,
  media_url   text,
  status      content_status not null default 'published',
  created_at  timestamptz not null default now(),
  is_solved   boolean not null default false
);
create index if not exists posts_subject_idx on posts(subject_id, created_at desc);
create index if not exists posts_author_idx  on posts(author_id, created_at desc);
create index if not exists posts_search_idx  on posts using gin (to_tsvector('simple', coalesce(title,'')||' '||coalesce(body,'')||' '||coalesce(topic,'')));

create table if not exists comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references posts(id) on delete cascade,
  author_id  uuid not null references profiles(id) on delete cascade,
  parent_id  uuid references comments(id) on delete cascade,
  body       text not null check (char_length(body) between 1 and 2000),
  status     content_status not null default 'published',
  is_accepted_answer boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists comments_post_idx on comments(post_id, created_at);

create table if not exists reactions (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,
  post_id    uuid references posts(id) on delete cascade,
  comment_id uuid references comments(id) on delete cascade,
  type       text not null default 'like' check (type in ('like','helpful','insightful')),
  created_at timestamptz not null default now(),
  check ((post_id is null) <> (comment_id is null))
);
create unique index if not exists reactions_post_uq    on reactions(user_id, post_id, type)    where post_id is not null;
create unique index if not exists reactions_comment_uq on reactions(user_id, comment_id, type) where comment_id is not null;

create table if not exists saved_posts (
  user_id uuid not null references profiles(id) on delete cascade,
  post_id uuid not null references posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, post_id)
);

-- ---------- YPT STUDY ----------
create table if not exists study_rooms (
  id         uuid primary key default gen_random_uuid(),
  owner_id   uuid not null references profiles(id) on delete cascade,
  name       text not null check (char_length(name) between 2 and 80),
  subject_id smallint references subjects(id),
  visibility room_visibility not null default 'public',
  created_at timestamptz not null default now()
);
create table if not exists study_room_members (
  room_id uuid not null references study_rooms(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (room_id, user_id)
);
create table if not exists study_sessions (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references profiles(id) on delete cascade,
  subject_id       smallint references subjects(id),
  room_id          uuid references study_rooms(id) on delete set null,
  goal             text check (char_length(goal) <= 200),
  planned_minutes  smallint not null check (planned_minutes between 5 and 240),
  started_at       timestamptz not null default now(),
  ended_at         timestamptz,
  duration_seconds integer check (duration_seconds >= 0),
  status           session_status not null default 'active'
);
create index if not exists ss_user_idx on study_sessions(user_id, started_at desc);
-- one active session per user
create unique index if not exists ss_one_active on study_sessions(user_id) where status = 'active';

-- ---------- POINTS / ACHIEVEMENTS ----------
create table if not exists point_events (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,
  kind       text not null,
  ref_id     uuid not null,                       -- source row; prevents double-awards
  subject_id smallint references subjects(id),
  points     integer not null check (points > 0),
  created_at timestamptz not null default now(),
  unique (user_id, kind, ref_id)
);
create index if not exists pe_user_idx on point_events(user_id, created_at desc);
create index if not exists pe_subject_idx on point_events(subject_id, created_at desc);

create table if not exists achievements (
  id        smallint generated always as identity primary key,
  slug      text not null unique,
  name_kk   text not null, name_ru text not null, name_en text not null,
  description_en text,
  icon      text
);
create table if not exists student_achievements (
  student_id     uuid not null references profiles(id) on delete cascade,
  achievement_id smallint not null references achievements(id) on delete cascade,
  earned_at      timestamptz not null default now(),
  primary key (student_id, achievement_id)
);

-- ---------- NOTIFICATIONS / REPORTS ----------
create table if not exists notifications (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references profiles(id) on delete cascade,
  type       text not null,   -- request_new, request_accepted, message, comment, reply, match, achievement
  payload    jsonb not null default '{}',
  read_at    timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notif_user_idx on notifications(user_id, read_at, created_at desc);

create table if not exists reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  post_id     uuid references posts(id) on delete cascade,
  comment_id  uuid references comments(id) on delete cascade,
  user_id     uuid references profiles(id) on delete cascade,
  reason      text not null check (char_length(reason) between 3 and 500),
  status      report_status not null default 'open',
  reviewed_by uuid references profiles(id),
  created_at  timestamptz not null default now(),
  check (num_nonnulls(post_id, comment_id, user_id) = 1)
);
create unique index if not exists reports_no_dup on reports(reporter_id, coalesce(post_id, comment_id, user_id));

-- =====================================================================
-- HELPERS
-- =====================================================================
create or replace function is_admin() returns boolean
language sql stable security definer set search_path = public as
$$ select exists (select 1 from profiles where id = auth.uid() and role = 'admin' and not is_banned) $$;

create or replace function is_staff() returns boolean
language sql stable security definer set search_path = public as
$$ select exists (select 1 from profiles where id = auth.uid() and role in ('admin','moderator') and not is_banned) $$;

create or replace function is_blocked_between(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as
$$ select exists (select 1 from blocks where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)) $$;

create or replace function touch_updated_at() returns trigger language plpgsql as
$$ begin new.updated_at = now(); return new; end $$;
drop trigger if exists profiles_touch on profiles;
create trigger profiles_touch before update on profiles for each row execute function touch_updated_at();

-- Create profile automatically from auth signup (email or Google)
create or replace function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare base text; uname text; n int := 0;
begin
  base := lower(regexp_replace(coalesce(new.raw_user_meta_data->>'username', split_part(new.email,'@',1)), '[^a-z0-9_]', '', 'g'));
  if char_length(base) < 3 then base := 'user' || substr(replace(new.id::text,'-',''),1,6); end if;
  base := left(base, 20); uname := base;
  while exists (select 1 from profiles where lower(username) = uname) loop
    n := n + 1; uname := base || n::text;
  end loop;
  insert into profiles (id, username, full_name, avatar_url, school, grade, city)
  values (new.id, uname,
    coalesce(nullif(new.raw_user_meta_data->>'full_name',''), nullif(new.raw_user_meta_data->>'name',''), base),
    coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture'),
    new.raw_user_meta_data->>'school',
    nullif(new.raw_user_meta_data->>'grade','')::smallint,
    new.raw_user_meta_data->>'city');
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- Block privilege escalation from the client
create or replace function guard_profile_update() returns trigger language plpgsql as $$
begin
  if not is_admin() and (new.role <> old.role or new.is_banned <> old.is_banned) then
    raise exception 'not allowed to change role or ban status';
  end if;
  return new;
end $$;
drop trigger if exists profiles_guard on profiles;
create trigger profiles_guard before update on profiles for each row execute function guard_profile_update();

-- Safe public view: masks school/city per privacy, hides banned / private profiles
create or replace view public_profiles as
select p.id, p.username, p.full_name, p.avatar_url, p.bio, p.grade, p.language,
       case when p.show_school then p.school end as school,
       case when p.show_city   then p.city   end as city,
       p.availability, p.created_at
from profiles p
where not p.is_banned and p.profile_public
  and not is_blocked_between(auth.uid(), p.id);
grant select on public_profiles to authenticated;

-- =====================================================================
-- MATCHING  (real data only; score 0..100)
--   60  mutual coverage  : share of each side's wants the other can teach
--   15  level fit        : teacher level >= learner's current level
--   15  grade closeness  : within 4 grades scales linearly
--    5  availability     : overlapping slots
--    5  history          : prior completed exchange
-- A pair needs at least one teachable overlap to match.
-- =====================================================================
create or replace function level_rank(l skill_level) returns int language sql immutable as
$$ select case l when 'beginner' then 1 when 'intermediate' then 2 when 'advanced' then 3 else 4 end $$;

create or replace function compute_match(a uuid, b uuid)
returns table (score smallint, a_teaches smallint[], b_teaches smallint[])
language plpgsql stable security definer set search_path = public as $$
declare
  a_want int; b_want int; a_get int; b_get int;
  a_t smallint[]; b_t smallint[];
  lvl_ok int; lvl_all int; gr int; ga smallint; gb smallint; sc numeric;
  avail boolean; hist boolean;
begin
  -- subjects B knows that A wants
  select coalesce(array_agg(i.subject_id),'{}') into b_t
    from student_learning_interests i
    join student_known_subjects k on k.subject_id = i.subject_id and k.student_id = b
   where i.student_id = a;
  select coalesce(array_agg(i.subject_id),'{}') into a_t
    from student_learning_interests i
    join student_known_subjects k on k.subject_id = i.subject_id and k.student_id = a
   where i.student_id = b;
  if cardinality(a_t) + cardinality(b_t) = 0 then return; end if;

  select count(*) into a_want from student_learning_interests where student_id = a;
  select count(*) into b_want from student_learning_interests where student_id = b;
  a_get := cardinality(b_t); b_get := cardinality(a_t);

  -- level fit
  select count(*) filter (where level_rank(k.level) >= level_rank(i.level)), count(*)
    into lvl_ok, lvl_all
    from student_learning_interests i
    join student_known_subjects k on k.subject_id = i.subject_id
     and k.student_id = case when i.student_id = a then b else a end
   where i.student_id in (a,b);

  select grade into ga from profiles where id = a;
  select grade into gb from profiles where id = b;
  gr := case when ga is null or gb is null then 8 else round(15 * greatest(0, 1 - abs(ga - gb)/4.0)) end;

  select exists (select 1 from profiles pa, profiles pb where pa.id = a and pb.id = b and pa.availability && pb.availability) into avail;
  select exists (select 1 from learning_requests where status = 'completed'
                  and ((requester_id = a and recipient_id = b) or (requester_id = b and recipient_id = a))) into hist;

  sc := 60 * ( (a_get::numeric / greatest(a_want,1)) + (b_get::numeric / greatest(b_want,1)) ) / 2
      + 15 * (lvl_ok::numeric / greatest(lvl_all,1))
      + gr + (case when avail then 5 else 0 end) + (case when hist then 5 else 0 end);

  return query select least(100, round(sc))::smallint, a_t, b_t;
end $$;

-- Recompute caller's matches against all eligible students
create or replace function refresh_my_matches() returns int
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); n int := 0; r record; ua uuid; ub uuid;
begin
  if me is null then raise exception 'not authenticated'; end if;
  delete from matches where user_a = me or user_b = me;
  for r in
    select p.id from profiles p
     where p.id <> me and not p.is_banned and p.profile_public and p.onboarding_done
       and not is_blocked_between(me, p.id)
  loop
    ua := least(me, r.id); ub := greatest(me, r.id);
    insert into matches (user_a, user_b, score, a_can_teach_b, b_can_teach_a)
      select c.score,
             case when ua = me then c.a_teaches else c.b_teaches end,
             case when ua = me then c.b_teaches else c.a_teaches end
        from compute_match(ua, ub) c
      on conflict (user_a, user_b) do update
        set score = excluded.score, a_can_teach_b = excluded.a_can_teach_b,
            b_can_teach_a = excluded.b_can_teach_a, computed_at = now();
    if found then n := n + 1; end if;
  end loop;
  return n;
end $$;

-- Matches page feed: respects privacy via public_profiles; teach/learn lists use subject ids
create or replace function get_my_matches(min_score int default 1, lim int default 50)
returns table (student_id uuid, username text, full_name text, avatar_url text, grade smallint,
               school text, score smallint, they_teach_me smallint[], i_teach_them smallint[])
language sql stable security definer set search_path = public as $$
  select pp.id, pp.username, pp.full_name, pp.avatar_url, pp.grade, pp.school, m.score,
         case when m.user_a = auth.uid() then m.b_can_teach_a else m.a_can_teach_b end,
         case when m.user_a = auth.uid() then m.a_can_teach_b else m.b_can_teach_a end
    from matches m
    join public_profiles pp on pp.id = case when m.user_a = auth.uid() then m.user_b else m.user_a end
   where auth.uid() in (m.user_a, m.user_b) and m.score >= min_score
   order by m.score desc limit lim
$$;

-- =====================================================================
-- POINTS (server-side only, capped to resist spam)
-- =====================================================================
create or replace function award_points(uid uuid, k text, ref uuid, pts int, subj smallint, daily_cap int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if (select coalesce(sum(points),0) from point_events
       where user_id = uid and kind = k and created_at > now() - interval '1 day') + pts > daily_cap then
    return;
  end if;
  insert into point_events(user_id, kind, ref_id, subject_id, points) values (uid, k, ref, subj, pts)
  on conflict (user_id, kind, ref_id) do nothing;
end $$;

-- study session: finish => points only if >= 10 min of real time
create or replace function finish_study_session(sid uuid) returns void
language plpgsql security definer set search_path = public as $$
declare s study_sessions; secs int;
begin
  select * into s from study_sessions where id = sid and user_id = auth.uid() and status = 'active';
  if not found then raise exception 'no active session'; end if;
  secs := least(extract(epoch from (now() - s.started_at))::int, s.planned_minutes * 60 + 300);
  update study_sessions set ended_at = now(), duration_seconds = secs,
         status = case when secs >= 600 then 'completed' else 'abandoned' end where id = sid;
  if secs >= 600 then
    perform award_points(s.user_id, 'study', sid, least(secs / 300, 24), s.subject_id, 120);
  end if;
end $$;

create or replace function on_post_created() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.kind <> 'question' and new.kind <> 'discussion' then
    perform award_points(new.author_id, 'post', new.id, 10, new.subject_id, 30);
  end if; return new;
end $$;
drop trigger if exists posts_points on posts;
create trigger posts_points after insert on posts for each row execute function on_post_created();

-- helper rewarded when reviewed >= 4 stars by someone else
create or replace function on_review_created() returns trigger language plpgsql security definer set search_path = public as $$
declare subj smallint;
begin
  select subject_id into subj from learning_requests where id = new.request_id;
  if new.rating >= 4 then perform award_points(new.reviewee_id, 'review', new.id, new.rating * 3, subj, 60); end if;
  insert into notifications(user_id, type, payload) values (new.reviewee_id, 'review', jsonb_build_object('request_id', new.request_id, 'rating', new.rating));
  return new;
end $$;
drop trigger if exists reviews_points on reviews;
create trigger reviews_points after insert on reviews for each row execute function on_review_created();

create or replace function leaderboard(period text default 'week', subj smallint default null, lim int default 50)
returns table (user_id uuid, username text, full_name text, avatar_url text, points bigint)
language sql stable security definer set search_path = public as $$
  select pp.id, pp.username, pp.full_name, pp.avatar_url, sum(e.points)
    from point_events e join public_profiles pp on pp.id = e.user_id
   where (subj is null or e.subject_id = subj)
     and (period = 'all'
          or (period = 'week'  and e.created_at > date_trunc('week',  now()))
          or (period = 'month' and e.created_at > date_trunc('month', now())))
   group by pp.id, pp.username, pp.full_name, pp.avatar_url
   order by 5 desc limit lim
$$;

-- =====================================================================
-- WORKFLOW TRIGGERS: requests, conversations, notifications, anti-spam
-- =====================================================================
create or replace function request_rules() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    if is_blocked_between(new.requester_id, new.recipient_id) then raise exception 'blocked'; end if;
    if (select count(*) from learning_requests where requester_id = new.requester_id and created_at > now() - interval '1 day') >= 20 then
      raise exception 'daily request limit reached';
    end if;
    insert into notifications(user_id, type, payload)
      values (new.recipient_id, 'request_new', jsonb_build_object('request_id', new.id, 'from', new.requester_id, 'subject_id', new.subject_id));
  else
    if (new.requester_id, new.recipient_id, new.subject_id, new.kind) is distinct from (old.requester_id, old.recipient_id, old.subject_id, old.kind) then
      raise exception 'immutable fields';
    end if;
    if new.status is distinct from old.status then
      new.responded_at := now();
      if new.status in ('accepted','declined') and auth.uid() <> old.recipient_id then raise exception 'only recipient can respond'; end if;
      if new.status = 'cancelled' and auth.uid() <> old.requester_id then raise exception 'only requester can cancel'; end if;
      if old.status <> 'pending' and new.status <> 'completed' then raise exception 'invalid transition'; end if;
      if new.status = 'accepted' then
        insert into conversations(user_a, user_b, request_id)
          values (least(old.requester_id, old.recipient_id), greatest(old.requester_id, old.recipient_id), old.id)
          on conflict (user_a, user_b) do nothing;
        insert into notifications(user_id, type, payload) values (old.requester_id, 'request_accepted', jsonb_build_object('request_id', old.id));
      end if;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists lr_rules_ins on learning_requests;
drop trigger if exists lr_rules_upd on learning_requests;
create trigger lr_rules_ins before insert on learning_requests for each row execute function request_rules();
create trigger lr_rules_upd before update on learning_requests for each row execute function request_rules();

create or replace function message_rules() returns trigger language plpgsql security definer set search_path = public as $$
declare c conversations; other uuid;
begin
  select * into c from conversations where id = new.conversation_id;
  if new.sender_id not in (c.user_a, c.user_b) then raise exception 'not a participant'; end if;
  other := case when c.user_a = new.sender_id then c.user_b else c.user_a end;
  if is_blocked_between(new.sender_id, other) then raise exception 'blocked'; end if;
  if (select count(*) from messages where sender_id = new.sender_id and created_at > now() - interval '1 minute') >= 20 then
    raise exception 'slow down';
  end if;
  insert into notifications(user_id, type, payload) values (other, 'message', jsonb_build_object('conversation_id', c.id));
  return new;
end $$;
drop trigger if exists messages_rules on messages;
create trigger messages_rules before insert on messages for each row execute function message_rules();

create or replace function comment_notify() returns trigger language plpgsql security definer set search_path = public as $$
declare owner uuid;
begin
  select author_id into owner from posts where id = new.post_id;
  if owner <> new.author_id then
    insert into notifications(user_id, type, payload) values (owner, 'comment', jsonb_build_object('post_id', new.post_id));
  end if;
  if new.parent_id is not null then
    insert into notifications(user_id, type, payload)
      select author_id, 'reply', jsonb_build_object('post_id', new.post_id) from comments where id = new.parent_id and author_id <> new.author_id;
  end if;
  return new;
end $$;
drop trigger if exists comments_notify on comments;
create trigger comments_notify after insert on comments for each row execute function comment_notify();

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
alter table subject_categories        enable row level security;
alter table subjects                  enable row level security;
alter table profiles                  enable row level security;
alter table student_known_subjects    enable row level security;
alter table student_learning_interests enable row level security;
alter table follows                   enable row level security;
alter table blocks                    enable row level security;
alter table learning_requests         enable row level security;
alter table reviews                   enable row level security;
alter table matches                   enable row level security;
alter table conversations             enable row level security;
alter table messages                  enable row level security;
alter table posts                     enable row level security;
alter table comments                  enable row level security;
alter table reactions                 enable row level security;
alter table saved_posts               enable row level security;
alter table study_rooms               enable row level security;
alter table study_room_members        enable row level security;
alter table study_sessions            enable row level security;
alter table point_events              enable row level security;
alter table achievements              enable row level security;
alter table student_achievements      enable row level security;
alter table notifications             enable row level security;
alter table reports                   enable row level security;

-- catalog: everyone reads, admin writes
create policy cat_read   on subject_categories for select using (true);
create policy cat_admin  on subject_categories for all using (is_admin()) with check (is_admin());
create policy subj_read  on subjects for select using (true);
create policy subj_admin on subjects for all using (is_admin()) with check (is_admin());
create policy ach_read   on achievements for select using (true);
create policy ach_admin  on achievements for all using (is_admin()) with check (is_admin());

-- profiles: base table = own row or staff; everyone else uses public_profiles view
create policy prof_self_read  on profiles for select using (id = auth.uid() or is_staff());
create policy prof_self_upd   on profiles for update using (id = auth.uid() or is_admin()) with check (id = auth.uid() or is_admin());
create policy prof_admin_del  on profiles for delete using (is_admin());

-- subjects known / wanted: owner manages; visible to others if profile public & not blocked
create policy sks_read on student_known_subjects for select using (
  student_id = auth.uid() or is_staff() or exists (select 1 from public_profiles p where p.id = student_id));
create policy sks_write on student_known_subjects for all using (student_id = auth.uid()) with check (student_id = auth.uid());
create policy sli_read on student_learning_interests for select using (
  student_id = auth.uid() or is_staff() or exists (select 1 from public_profiles p where p.id = student_id));
create policy sli_write on student_learning_interests for all using (student_id = auth.uid()) with check (student_id = auth.uid());

-- follows / blocks
create policy follows_read  on follows for select using (follower_id = auth.uid() or followee_id = auth.uid());
create policy follows_write on follows for insert with check (follower_id = auth.uid() and not is_blocked_between(follower_id, followee_id));
create policy follows_del   on follows for delete using (follower_id = auth.uid());
create policy blocks_own    on blocks for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- requests: participants only
create policy lr_read on learning_requests for select using (auth.uid() in (requester_id, recipient_id) or is_staff());
create policy lr_ins  on learning_requests for insert with check (
  requester_id = auth.uid() and status = 'pending'
  and not exists (select 1 from profiles where id = auth.uid() and is_banned));
create policy lr_upd  on learning_requests for update using (auth.uid() in (requester_id, recipient_id));

-- reviews: participants of a completed request, once, about the other party
create policy rev_read on reviews for select using (
  reviewee_id = auth.uid() or reviewer_id = auth.uid() or is_staff()
  or exists (select 1 from public_profiles p where p.id = reviewee_id));
create policy rev_ins on reviews for insert with check (
  reviewer_id = auth.uid() and exists (
    select 1 from learning_requests r where r.id = request_id and r.status = 'completed'
      and auth.uid() in (r.requester_id, r.recipient_id)
      and reviewee_id = case when r.requester_id = auth.uid() then r.recipient_id else r.requester_id end));

-- matches: members read only (written by SECURITY DEFINER function)
create policy matches_read on matches for select using (auth.uid() in (user_a, user_b));

-- conversations / messages: participants only
create policy conv_read on conversations for select using (auth.uid() in (user_a, user_b));
create policy msg_read  on messages for select using (exists (
  select 1 from conversations c where c.id = conversation_id and auth.uid() in (c.user_a, c.user_b)));
create policy msg_ins   on messages for insert with check (sender_id = auth.uid());
create policy msg_read_mark on messages for update using (exists (
  select 1 from conversations c where c.id = conversation_id and auth.uid() in (c.user_a, c.user_b)) and sender_id <> auth.uid());

-- posts / comments / reactions
create policy posts_read on posts for select using (
  (status = 'published' and not is_blocked_between(auth.uid(), author_id)) or author_id = auth.uid() or is_staff());
create policy posts_ins  on posts for insert with check (author_id = auth.uid()
  and not exists (select 1 from profiles where id = auth.uid() and is_banned));
create policy posts_upd  on posts for update using (author_id = auth.uid() or is_staff()) with check (author_id = auth.uid() or is_staff());
create policy posts_del  on posts for delete using (author_id = auth.uid() or is_admin());

create policy com_read on comments for select using (
  (status = 'published' and not is_blocked_between(auth.uid(), author_id)) or author_id = auth.uid() or is_staff());
create policy com_ins  on comments for insert with check (author_id = auth.uid()
  and not exists (select 1 from profiles where id = auth.uid() and is_banned));
create policy com_upd  on comments for update using (author_id = auth.uid() or is_staff());
create policy com_del  on comments for delete using (author_id = auth.uid() or is_admin());

create policy react_read on reactions for select using (true);
create policy react_ins  on reactions for insert with check (user_id = auth.uid());
create policy react_del  on reactions for delete using (user_id = auth.uid());

create policy saved_own on saved_posts for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- study rooms / sessions
create policy room_read on study_rooms for select using (
  visibility = 'public' or owner_id = auth.uid()
  or exists (select 1 from study_room_members m where m.room_id = id and m.user_id = auth.uid()));
create policy room_ins  on study_rooms for insert with check (owner_id = auth.uid());
create policy room_upd  on study_rooms for update using (owner_id = auth.uid() or is_admin());
create policy room_del  on study_rooms for delete using (owner_id = auth.uid() or is_admin());
create policy rm_read   on study_room_members for select using (
  user_id = auth.uid() or exists (select 1 from study_rooms r where r.id = room_id and (r.visibility = 'public' or r.owner_id = auth.uid())));
create policy rm_join   on study_room_members for insert with check (user_id = auth.uid()
  and exists (select 1 from study_rooms r where r.id = room_id and r.visibility = 'public'));
create policy rm_leave  on study_room_members for delete using (user_id = auth.uid());
-- sessions: start only via insert; finishing goes through finish_study_session()
create policy ss_read on study_sessions for select using (user_id = auth.uid() or is_staff());
create policy ss_ins  on study_sessions for insert with check (user_id = auth.uid() and status = 'active');

-- points: read own; no client writes at all
create policy pe_read on point_events for select using (user_id = auth.uid() or is_staff());
create policy sa_read on student_achievements for select using (
  student_id = auth.uid() or exists (select 1 from public_profiles p where p.id = student_id));

-- notifications: own only
create policy notif_read on notifications for select using (user_id = auth.uid());
create policy notif_upd  on notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- reports: anyone files; reporter sees own; staff handle
create policy rep_ins  on reports for insert with check (reporter_id = auth.uid());
create policy rep_read on reports for select using (reporter_id = auth.uid() or is_staff());
create policy rep_upd  on reports for update using (is_staff());

-- function privileges
revoke all on function award_points(uuid,text,uuid,int,smallint,int) from public, anon, authenticated;
grant execute on function refresh_my_matches(), get_my_matches(int,int), finish_study_session(uuid),
                          leaderboard(text,smallint,int) to authenticated;

-- realtime for chat + notifications
do $$ begin
  alter publication supabase_realtime add table messages;
  alter publication supabase_realtime add table notifications;
exception when others then null; end $$;

-- storage buckets (avatars public-read, materials/chat private-ish)
insert into storage.buckets (id, name, public) values
  ('avatars','avatars',true), ('materials','materials',true), ('chat','chat',false)
on conflict (id) do nothing;
create policy avatars_write on storage.objects for insert to authenticated
  with check (bucket_id in ('avatars','materials','chat') and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id in ('avatars','materials','chat') and (storage.foldername(name))[1] = auth.uid()::text);
create policy public_buckets_read on storage.objects for select using (bucket_id in ('avatars','materials'));
create policy chat_read on storage.objects for select to authenticated using (bucket_id = 'chat');

-- =====================================================================
-- SEED: 6 categories + 45 learning directions
-- =====================================================================
insert into subject_categories (slug, name_kk, name_ru, name_en, sort_order) values
 ('languages','Тілдер және әдебиет','Языки и литература','Languages and Literature',1),
 ('history','Тарих және қоғам','История и общество','History and Society',2),
 ('science','Математика және ғылым','Математика и наука','Mathematics and Science',3),
 ('it','IT және жасанды интеллект','IT и искусственный интеллект','IT and Artificial Intelligence',4),
 ('design','Дизайн және шығармашылық','Дизайн и творчество','Design and Creativity',5),
 ('skills','Практикалық және кәсіби дағдылар','Практические и профессиональные навыки','Practical and Professional Skills',6)
on conflict (slug) do nothing;

insert into subjects (category_id, slug, name_kk, name_ru, name_en, sort_order)
select c.id, v.slug, v.kk, v.ru, v.en, v.n
from (values
 ('languages','kazakh','Қазақ тілі және әдебиеті','Казахский язык и литература','Kazakh Language and Literature',1),
 ('languages','russian','Русский язык и литература','Русский язык и литература','Russian Language and Literature',2),
 ('languages','english','Ағылшын тілі','Английский язык','English',3),
 ('languages','german','Неміс тілі','Немецкий язык','German',4),
 ('languages','chinese','Қытай тілі','Китайский язык','Chinese',5),
 ('languages','turkish','Түрік тілі','Турецкий язык','Turkish',6),
 ('languages','speech','Сөйлеу және коммуникация','Речь и коммуникация','Speech and Communication',7),
 ('history','kz-history','Қазақстан тарихы','История Казахстана','History of Kazakhstan',8),
 ('history','world-history','Дүниежүзі тарихы','Всемирная история','World History',9),
 ('history','law','Құқық негіздері','Основы права','Fundamentals of Law',10),
 ('history','social-studies','Қоғамтану','Обществознание','Social Studies',11),
 ('history','politics','Саясаттану негіздері','Основы политологии','Political Science Basics',12),
 ('history','culture','Мәдениеттану','Культурология','Cultural Studies',13),
 ('science','algebra','Алгебра','Алгебра','Algebra',14),
 ('science','geometry','Геометрия','Геометрия','Geometry',15),
 ('science','physics','Физика','Физика','Physics',16),
 ('science','chemistry','Химия','Химия','Chemistry',17),
 ('science','biology','Биология','Биология','Biology',18),
 ('science','geography','География','География','Geography',19),
 ('science','astronomy','Астрономия','Астрономия','Astronomy',20),
 ('science','ecology','Экология','Экология','Ecology',21),
 ('science','statistics','Статистика және ықтималдық','Статистика и вероятность','Statistics and Probability',22),
 ('science','fin-math','Қаржылық математика','Финансовая математика','Financial Mathematics',23),
 ('it','programming','Программалау','Программирование','Programming',24),
 ('it','web-dev','Веб-әзірлеу','Веб-разработка','Web Development',25),
 ('it','ai','ЖИ-мен жұмыс','Работа с ИИ','Working with AI',26),
 ('it','robotics','Робототехника','Робототехника','Robotics',27),
 ('it','cybersecurity','Киберқауіпсіздік негіздері','Основы кибербезопасности','Cybersecurity Basics',28),
 ('it','data-analysis','Деректерді талдау','Анализ данных','Data Analysis',29),
 ('it','digital-literacy','Цифрлық сауаттылық','Цифровая грамотность','Digital Literacy',30),
 ('design','graphic-design','Графикалық дизайн','Графический дизайн','Graphic Design',31),
 ('design','ui-ux','UI/UX дизайн','UI/UX дизайн','UI/UX Design',32),
 ('design','video-editing','Видеомонтаж','Видеомонтаж','Video Editing',33),
 ('design','photography','Фотография','Фотография','Photography',34),
 ('design','music-art','Музыка және өнер','Музыка и искусство','Music and Art',35),
 ('skills','presentations','Презентациямен жұмыс','Работа с презентациями','Presentations',36),
 ('skills','excel','Excel және Google Sheets','Excel и Google Sheets','Excel and Google Sheets',37),
 ('skills','project-mgmt','Жобаларды басқару','Управление проектами','Project Management',38),
 ('skills','entrepreneurship','Кәсіпкерлік негіздері','Основы предпринимательства','Entrepreneurship Basics',39),
 ('skills','public-speaking','Көпшілік алдында сөйлеу','Публичные выступления','Public Speaking',40),
 ('skills','critical-thinking','Сыни ойлау','Критическое мышление','Critical Thinking',41),
 ('skills','media-literacy','Медиасауаттылық','Медиаграмотность','Media Literacy',42),
 ('skills','time-mgmt','Уақытты басқару','Тайм-менеджмент','Time Management',43),
 ('skills','research','Зерттеу және ғылыми жоба','Исследования и научный проект','Research and Science Projects',44),
 ('skills','leadership','Көшбасшылық және командалық жұмыс','Лидерство и командная работа','Leadership and Teamwork',45)
) as v(cat, slug, kk, ru, en, n)
join subject_categories c on c.slug = v.cat
on conflict (slug) do nothing;

insert into achievements (slug, name_kk, name_ru, name_en, description_en, icon) values
 ('first-post','Алғашқы жарияланым','Первая публикация','First Post','Publish your first material','📝'),
 ('first-help','Алғашқы көмек','Первая помощь','First Help','Complete your first help exchange','🤝'),
 ('focus-10','10 сағат фокус','10 часов фокуса','10 Focus Hours','Study 10 hours in total','⏱️'),
 ('top-rated','Үздік бағалау','Высокая оценка','Top Rated','Receive five 5-star reviews','⭐')
on conflict (slug) do nothing;
