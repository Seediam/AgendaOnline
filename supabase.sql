-- ============================================================
-- NOSSO TEMPO — BANCO DE DADOS SUPABASE
-- Cole TODO este arquivo no SQL Editor do Supabase e clique Run.
-- ============================================================

create extension if not exists pgcrypto;

create table if not exists public.boards (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  join_code text not null unique,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.board_members (
  board_id uuid not null references public.boards(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) between 1 and 40),
  joined_at timestamptz not null default now(),
  primary key (board_id, user_id)
);

create table if not exists public.day_plans (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  plan_date date not null,
  chooser_user_id uuid references auth.users(id) on delete set null,
  category text not null default '💛 Tempo juntos',
  good_option text,
  bad_option text,
  start_time time,
  selected_option text not null default 'auto'
    check (selected_option in ('auto', 'good', 'bad')),
  status text not null default 'planned'
    check (status in ('planned', 'done', 'skipped')),
  reminder_at timestamptz,
  notes text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique (board_id, plan_date)
);

create index if not exists day_plans_board_date_idx
  on public.day_plans(board_id, plan_date);

alter table public.boards enable row level security;
alter table public.board_members enable row level security;
alter table public.day_plans enable row level security;

-- Helper SECURITY DEFINER: evita recursão de RLS ao checar a própria tabela de membros.
create or replace function public.is_board_member(p_board_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.board_members bm
    where bm.board_id = p_board_id
      and bm.user_id = auth.uid()
  );
$$;

revoke all on function public.is_board_member(uuid) from public;
grant execute on function public.is_board_member(uuid) to authenticated;

-- Limpa políticas antigas do mesmo nome, caso você rode o SQL novamente.
drop policy if exists "members can view boards" on public.boards;
drop policy if exists "members can view members" on public.board_members;
drop policy if exists "members can view plans" on public.day_plans;
drop policy if exists "members can insert plans" on public.day_plans;
drop policy if exists "members can update plans" on public.day_plans;
drop policy if exists "members can delete plans" on public.day_plans;

create policy "members can view boards"
on public.boards for select
to authenticated
using (public.is_board_member(id));

create policy "members can view members"
on public.board_members for select
to authenticated
using (public.is_board_member(board_id));

create policy "members can view plans"
on public.day_plans for select
to authenticated
using (public.is_board_member(board_id));

create policy "members can insert plans"
on public.day_plans for insert
to authenticated
with check (public.is_board_member(board_id));

create policy "members can update plans"
on public.day_plans for update
to authenticated
using (public.is_board_member(board_id))
with check (public.is_board_member(board_id));

create policy "members can delete plans"
on public.day_plans for delete
to authenticated
using (public.is_board_member(board_id));

-- Função para criar agenda sem precisar abrir INSERT direto nas tabelas.
create or replace function public.create_board(p_name text, p_display_name text)
returns table(board_id uuid, join_code text)
language plpgsql
security definer
set search_path = public
as $$
declare
  new_board_id uuid;
  new_code text;
begin
  if auth.uid() is null then
    raise exception 'Você precisa estar autenticado.';
  end if;

  if trim(coalesce(p_name, '')) = '' or trim(coalesce(p_display_name, '')) = '' then
    raise exception 'Nome da agenda e nome da pessoa são obrigatórios.';
  end if;

  loop
    new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists(select 1 from public.boards b where b.join_code = new_code);
  end loop;

  insert into public.boards(name, join_code, created_by)
  values (trim(p_name), new_code, auth.uid())
  returning id into new_board_id;

  insert into public.board_members(board_id, user_id, display_name)
  values (new_board_id, auth.uid(), trim(p_display_name));

  return query select new_board_id, new_code;
end;
$$;

-- Função segura para entrar usando o código.
create or replace function public.join_board(p_join_code text, p_display_name text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  target_board uuid;
begin
  if auth.uid() is null then
    raise exception 'Você precisa estar autenticado.';
  end if;

  select b.id into target_board
  from public.boards b
  where b.join_code = upper(trim(p_join_code))
  limit 1;

  if target_board is null then
    raise exception 'Código de convite inválido.';
  end if;

  insert into public.board_members(board_id, user_id, display_name)
  values (target_board, auth.uid(), trim(p_display_name))
  on conflict (board_id, user_id)
  do update set display_name = excluded.display_name;

  return target_board;
end;
$$;

grant execute on function public.create_board(text, text) to authenticated;
grant execute on function public.join_board(text, text) to authenticated;

-- Realtime para alterações aparecerem para os dois sem recarregar.
do $$
begin
  alter publication supabase_realtime add table public.day_plans;
exception
  when duplicate_object then null;
end $$;
