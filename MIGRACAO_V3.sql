-- ============================================================
-- NOSSO TEMPO V3 — MIGRAÇÃO
-- Rode UMA VEZ no SQL Editor do mesmo projeto Supabase.
-- Preserva os dados já existentes.
-- ============================================================

alter table public.day_plans add column if not exists title text;
alter table public.day_plans add column if not exists incident_reason text;
alter table public.day_plans add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.day_plans add column if not exists created_at timestamptz not null default now();

update public.day_plans
set title = coalesce(nullif(trim(good_option), ''), nullif(trim(category), ''), 'Atividade')
where title is null or trim(title) = '';

alter table public.day_plans drop constraint if exists day_plans_board_id_plan_date_key;
alter table public.day_plans drop constraint if exists day_plans_status_check;
alter table public.day_plans add constraint day_plans_status_check check (status in ('planned','done','skipped','unexpected'));

do $$ begin
  alter table public.day_plans add constraint day_plans_board_id_id_unique unique (board_id, id);
exception when duplicate_object then null; end $$;

alter table public.board_members add column if not exists profile_color text default '#df8f7c';
alter table public.board_members add column if not exists profile_note text;

create table if not exists public.plan_participants (
  board_id uuid not null references public.boards(id) on delete cascade,
  plan_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (plan_id, user_id),
  foreign key (board_id, plan_id) references public.day_plans(board_id, id) on delete cascade
);

create table if not exists public.plan_checklist_items (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  plan_id uuid not null,
  item_text text not null,
  is_done boolean not null default false,
  position integer not null default 0,
  done_by uuid references auth.users(id) on delete set null,
  done_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key (board_id, plan_id) references public.day_plans(board_id, id) on delete cascade
);

create table if not exists public.shared_tasks (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  title text not null,
  category text not null default '🏠 Casa',
  due_date date,
  assigned_to uuid references auth.users(id) on delete set null,
  is_done boolean not null default false,
  unforeseen boolean not null default false,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.finance_entries (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  entry_date date not null default current_date,
  title text not null,
  category text not null default '✨ Outro',
  kind text not null check (kind in ('income','expense')),
  amount numeric(12,2) not null check (amount >= 0),
  is_paid boolean not null default false,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pets (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  name text not null,
  species text not null default 'gato',
  coat text,
  emoji text default '🐱',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique (board_id, name)
);

do $$ begin
  alter table public.pets add constraint pets_board_id_id_unique unique (board_id, id);
exception when duplicate_object then null; end $$;

create table if not exists public.pet_care_logs (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  pet_id uuid not null,
  care_date date not null,
  task_type text not null,
  is_done boolean not null default false,
  notes text,
  done_by uuid references auth.users(id) on delete set null,
  done_at timestamptz,
  created_at timestamptz not null default now(),
  unique (pet_id, care_date, task_type),
  foreign key (board_id, pet_id) references public.pets(board_id, id) on delete cascade
);

create table if not exists public.notices (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  title text not null,
  body text not null,
  priority text not null default 'normal' check (priority in ('normal','important')),
  expires_at date,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

do $$ begin
  alter table public.notices add constraint notices_board_id_id_unique unique (board_id, id);
exception when duplicate_object then null; end $$;

create table if not exists public.notice_reads (
  board_id uuid not null references public.boards(id) on delete cascade,
  notice_id uuid not null,
  user_id uuid not null references auth.users(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (notice_id, user_id),
  foreign key (board_id, notice_id) references public.notices(board_id, id) on delete cascade
);

create table if not exists public.availability_blocks (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  weekday smallint check (weekday between 0 and 6),
  specific_date date,
  start_time time not null,
  end_time time not null,
  availability_type text not null check (availability_type in ('available','busy')),
  label text not null,
  created_at timestamptz not null default now(),
  check (end_time > start_time),
  check (weekday is not null or specific_date is not null)
);

alter table public.plan_participants enable row level security;
alter table public.plan_checklist_items enable row level security;
alter table public.shared_tasks enable row level security;
alter table public.finance_entries enable row level security;
alter table public.pets enable row level security;
alter table public.pet_care_logs enable row level security;
alter table public.notices enable row level security;
alter table public.notice_reads enable row level security;
alter table public.availability_blocks enable row level security;

do $$
declare t text;
begin
  foreach t in array array['plan_participants','plan_checklist_items','shared_tasks','finance_entries','pets','pet_care_logs','notices']
  loop
    execute format('drop policy if exists "v3 select" on public.%I', t);
    execute format('drop policy if exists "v3 insert" on public.%I', t);
    execute format('drop policy if exists "v3 update" on public.%I', t);
    execute format('drop policy if exists "v3 delete" on public.%I', t);
    execute format('create policy "v3 select" on public.%I for select to authenticated using (public.is_board_member(board_id))', t);
    execute format('create policy "v3 insert" on public.%I for insert to authenticated with check (public.is_board_member(board_id))', t);
    execute format('create policy "v3 update" on public.%I for update to authenticated using (public.is_board_member(board_id)) with check (public.is_board_member(board_id))', t);
    execute format('create policy "v3 delete" on public.%I for delete to authenticated using (public.is_board_member(board_id))', t);
  end loop;
end $$;

drop policy if exists "v3 availability select" on public.availability_blocks;
drop policy if exists "v3 availability insert" on public.availability_blocks;
drop policy if exists "v3 availability update" on public.availability_blocks;
drop policy if exists "v3 availability delete" on public.availability_blocks;
create policy "v3 availability select" on public.availability_blocks for select to authenticated using (public.is_board_member(board_id));
create policy "v3 availability insert" on public.availability_blocks for insert to authenticated with check (public.is_board_member(board_id) and user_id = auth.uid());
create policy "v3 availability update" on public.availability_blocks for update to authenticated using (public.is_board_member(board_id) and user_id = auth.uid()) with check (public.is_board_member(board_id) and user_id = auth.uid());
create policy "v3 availability delete" on public.availability_blocks for delete to authenticated using (public.is_board_member(board_id) and user_id = auth.uid());

drop policy if exists "v3 reads select" on public.notice_reads;
drop policy if exists "v3 reads insert" on public.notice_reads;
drop policy if exists "v3 reads update" on public.notice_reads;
drop policy if exists "v3 reads delete" on public.notice_reads;
create policy "v3 reads select" on public.notice_reads for select to authenticated using (public.is_board_member(board_id));
create policy "v3 reads insert" on public.notice_reads for insert to authenticated with check (public.is_board_member(board_id) and user_id = auth.uid());
create policy "v3 reads update" on public.notice_reads for update to authenticated using (public.is_board_member(board_id) and user_id = auth.uid()) with check (public.is_board_member(board_id) and user_id = auth.uid());
create policy "v3 reads delete" on public.notice_reads for delete to authenticated using (public.is_board_member(board_id) and user_id = auth.uid());

create or replace function public.update_my_profile(p_board_id uuid,p_display_name text,p_profile_color text,p_profile_note text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_board_member(p_board_id) then raise exception 'Você não participa desta agenda.'; end if;
  update public.board_members set display_name=trim(p_display_name),profile_color=p_profile_color,profile_note=nullif(trim(coalesce(p_profile_note,'')),'') where board_id=p_board_id and user_id=auth.uid();
end; $$;
grant execute on function public.update_my_profile(uuid,text,text,text) to authenticated;

create or replace function public.ensure_default_pets(p_board_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_board_member(p_board_id) then raise exception 'Você não participa desta agenda.'; end if;
  insert into public.pets(board_id,name,species,coat,emoji,sort_order) values
    (p_board_id,'Simba','gato','rajado','🐯',1),(p_board_id,'Nala','gato','preto','🐈‍⬛',2),(p_board_id,'Gris','gato','cinza','🩶',3),(p_board_id,'Xayah','gata','rajada','🐯',4)
  on conflict (board_id,name) do nothing;
end; $$;
grant execute on function public.ensure_default_pets(uuid) to authenticated;

do $$
declare t text;
begin
  foreach t in array array['day_plans','shared_tasks','finance_entries','pet_care_logs','notices','notice_reads','availability_blocks','plan_checklist_items','plan_participants','board_members']
  loop
    begin execute format('alter publication supabase_realtime add table public.%I', t); exception when duplicate_object then null; end;
  end loop;
end $$;
