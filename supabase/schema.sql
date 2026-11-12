-- 배너 편집기: 배너 등록 · 공유 URL 기능용 테이블과 이미지 저장소
-- Supabase 대시보드 > SQL Editor 에 통째로 붙여 넣고 Run 하세요. (여러 번 실행해도 안전)

-- 1) 배너 테이블 ------------------------------------------------------------
--   id            : 배너 ID (공유 URL ?banner=<id>)
--   data          : 등록 당시 편집 상태 전체 (템플릿 복사본, 입력 문구, 레이어 이름·순서·위치·크기, 글꼴·색 등)
--   edit_key_hash : 등록한 사람만 수정할 수 있게 하는 편집 키의 SHA-256 해시 (키 원문은 등록한 브라우저에만 있음)
create extension if not exists pgcrypto;

create table if not exists public.banners (
  id            uuid primary key default gen_random_uuid(),
  data          jsonb not null,
  edit_key_hash text not null check (edit_key_hash ~ '^[0-9a-f]{64}$'),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

alter table public.banners enable row level security;

-- 누구나 공유 URL로 배너를 볼 수 있음
drop policy if exists "banners: anyone can read" on public.banners;
create policy "banners: anyone can read" on public.banners
  for select to anon, authenticated using (true);

-- 누구나 새 배너를 등록할 수 있음 (데이터 크기 1MB 제한)
drop policy if exists "banners: anyone can register" on public.banners;
create policy "banners: anyone can register" on public.banners
  for insert to anon, authenticated
  with check (pg_column_size(data) < 1000000);

-- update / delete 정책은 만들지 않음 → 테이블을 직접 고치거나 지울 수 없음.
-- 수정은 아래 함수로만: 편집 키가 맞을 때만 data 를 바꿈
create or replace function public.update_banner(p_id uuid, p_key text, p_data jsonb)
returns boolean
language plpgsql
security definer
set search_path = public, extensions
as $$
declare n int;
begin
  if pg_column_size(p_data) >= 1000000 then return false; end if;
  update public.banners
     set data = p_data, updated_at = now()
   where id = p_id
     and edit_key_hash = encode(digest(p_key, 'sha256'), 'hex');
  get diagnostics n = row_count;
  return n = 1;
end $$;

revoke all on function public.update_banner(uuid, text, jsonb) from public;
grant execute on function public.update_banner(uuid, text, jsonb) to anon, authenticated;

-- 2) 배경 이미지 저장소 (Storage) --------------------------------------------
--   공개 버킷: 이미지 주소로 누구나 볼 수 있음. 올리기만 허용하고 덮어쓰기·삭제는 막음
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('banner-images', 'banner-images', true, 5242880, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = true, file_size_limit = 5242880, allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp'];

drop policy if exists "banner-images: anyone can upload" on storage.objects;
create policy "banner-images: anyone can upload" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'banner-images');
