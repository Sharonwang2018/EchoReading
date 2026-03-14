-- EchoReading RLS 策略：解决 "violates row-level security policy" 错误
-- 在 Supabase SQL Editor 中执行此脚本

-- books 表：允许匿名用户读取、插入、更新（扫码录入需写入）
alter table public.books enable row level security;

drop policy if exists "Allow public read on books" on public.books;
drop policy if exists "Allow public insert on books" on public.books;
drop policy if exists "Allow public update on books" on public.books;

create policy "Allow public read on books" on public.books
  for select using (true);

create policy "Allow public insert on books" on public.books
  for insert with check (true);

create policy "Allow public update on books" on public.books
  for update using (true);
