-- 배너 편집기 v1.1: 관리자가 만든 템플릿을 모든 운영자가 함께 보는 공유 템플릿 저장소
-- Supabase 대시보드 > SQL Editor 에 통째로 붙여 넣고 Run 하세요. (여러 번 실행해도 안전)
-- 기존 schema.sql(배너 공유용)을 먼저 실행해 둔 상태여야 합니다. (banner-images 버킷을 같이 씀)
--
-- 권한 구조
--   읽기  : 누구나 (운영자는 로그인 없이 최신 템플릿을 봄)
--   쓰기  : 관리자 비밀번호가 맞을 때만, 아래 save_template / delete_template 함수로만
--   비밀번호: 원문은 저장하지 않고 SHA-256 해시만 app_admin 테이블에 보관 (브라우저에서는 이 테이블을 읽을 수 없음)

create extension if not exists pgcrypto;

-- 1) 템플릿 테이블 -----------------------------------------------------------
--   id   : 템플릿 ID (편집기에서 만든 값 그대로)
--   data : 템플릿 전체 { name, background{ image(Storage 주소), fill, color, color2, angle }, texts[...] }
create table if not exists public.templates (
  id         text primary key check (char_length(id) between 1 and 64),
  data       jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.templates enable row level security;

drop policy if exists "templates: anyone can read" on public.templates;
create policy "templates: anyone can read" on public.templates
  for select to anon, authenticated using (true);
-- insert / update / delete 정책은 만들지 않음 → 아래 함수로만 바꿀 수 있음

-- 2) 관리자 비밀번호 (해시) -----------------------------------------------------
create table if not exists public.app_admin (
  id       int primary key default 1 check (id = 1),
  key_hash text not null check (key_hash ~ '^[0-9a-f]{64}$')
);
alter table public.app_admin enable row level security;  -- 정책 없음 → 브라우저에서 읽기·쓰기 불가
revoke all on public.app_admin from anon, authenticated;

-- 3) 함수 ----------------------------------------------------------------------
create or replace function public.is_admin(p_key text)
returns boolean
language sql
security definer
set search_path = public, extensions
as $$
  select exists (
    select 1 from public.app_admin
     where key_hash = encode(digest(coalesce(p_key, ''), 'sha256'), 'hex')
  );
$$;

create or replace function public.save_template(p_key text, p_id text, p_data jsonb)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_admin(p_key) then return false; end if;
  if p_id is null or char_length(p_id) not between 1 and 64 then return false; end if;
  if pg_column_size(p_data) >= 1000000 then return false; end if;
  insert into public.templates (id, data) values (p_id, p_data)
  on conflict (id) do update set data = excluded.data, updated_at = now();
  return true;
end $$;

create or replace function public.delete_template(p_key text, p_id text)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if not public.is_admin(p_key) then return false; end if;
  delete from public.templates where id = p_id;
  return true;
end $$;

revoke all on function public.is_admin(text) from public;
revoke all on function public.save_template(text, text, jsonb) from public;
revoke all on function public.delete_template(text, text) from public;
grant execute on function public.is_admin(text) to anon, authenticated;
grant execute on function public.save_template(text, text, jsonb) to anon, authenticated;
grant execute on function public.delete_template(text, text) to anon, authenticated;

-- 4) 관리자 비밀번호 설정 ------------------------------------------------------
-- ⚠ 이 파일에는 비밀번호를 적지 마세요 (깃허브에 공개됩니다).
--    아래 한 줄을 SQL Editor 에만 따로 붙여 넣고, '여기에_비밀번호' 를 바꿔서 실행하세요.
--    비밀번호를 바꿀 때도 같은 줄을 다시 실행하면 됩니다.
--
-- insert into public.app_admin (id, key_hash) values (1, encode(digest('여기에_비밀번호', 'sha256'), 'hex'))
--   on conflict (id) do update set key_hash = excluded.key_hash;
