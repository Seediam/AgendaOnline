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


-- ============================================================
-- NOSSO TEMPO V4 — TAREFAS RECORRENTES
-- Rode UMA VEZ no SQL Editor, DEPOIS da MIGRACAO_V3.sql.
-- Preserva todas as tarefas atuais.
-- ============================================================

alter table public.shared_tasks
  add column if not exists recurrence_type text not null default 'none',
  add column if not exists recurrence_weekdays smallint[],
  add column if not exists recurrence_start date,
  add column if not exists recurrence_end date,
  add column if not exists priority text not null default 'normal';

alter table public.shared_tasks
  drop constraint if exists shared_tasks_recurrence_type_check;

alter table public.shared_tasks
  add constraint shared_tasks_recurrence_type_check
  check (recurrence_type in ('none','daily','weekdays','weekly','custom_weekdays','monthly'));

alter table public.shared_tasks
  drop constraint if exists shared_tasks_priority_check;

alter table public.shared_tasks
  add constraint shared_tasks_priority_check
  check (priority in ('normal','important','urgent'));

-- Cada repetição tem um estado próprio.
create table if not exists public.shared_task_occurrences (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  task_id uuid not null references public.shared_tasks(id) on delete cascade,
  occurrence_date date not null,
  is_done boolean not null default false,
  unforeseen boolean not null default false,
  completed_by uuid references auth.users(id) on delete set null,
  completed_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (task_id, occurrence_date)
);

alter table public.shared_task_occurrences enable row level security;

drop policy if exists "v4 occurrences select" on public.shared_task_occurrences;
drop policy if exists "v4 occurrences insert" on public.shared_task_occurrences;
drop policy if exists "v4 occurrences update" on public.shared_task_occurrences;
drop policy if exists "v4 occurrences delete" on public.shared_task_occurrences;

create policy "v4 occurrences select"
on public.shared_task_occurrences for select
to authenticated
using (public.is_board_member(board_id));

create policy "v4 occurrences insert"
on public.shared_task_occurrences for insert
to authenticated
with check (public.is_board_member(board_id));

create policy "v4 occurrences update"
on public.shared_task_occurrences for update
to authenticated
using (public.is_board_member(board_id))
with check (public.is_board_member(board_id));

create policy "v4 occurrences delete"
on public.shared_task_occurrences for delete
to authenticated
using (public.is_board_member(board_id));

do $$
begin
  alter publication supabase_realtime add table public.shared_task_occurrences;
exception when duplicate_object then null;
end $$;

-- Tarefas antigas continuam sendo tarefas únicas.
update public.shared_tasks
set recurrence_type = 'none'
where recurrence_type is null;

-- Se algum dia você transformar uma tarefa antiga em recorrente,
-- a data escolhida no site passa a ser o início da rotina.


-- ============================================================
-- NOSSO TEMPO V5 — PAINEL DA CASA
-- Rode UMA VEZ, depois da MIGRACAO_V3 e MIGRACAO_V4.
-- Preserva os dados existentes.
-- ============================================================

alter table public.day_plans add column if not exists end_time time;

create table if not exists public.shared_task_exceptions (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  task_id uuid not null references public.shared_tasks(id) on delete cascade,
  exception_date date not null,
  reason text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(task_id, exception_date)
);

create table if not exists public.recurring_bills (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  title text not null,
  category text not null default '💡 Contas',
  amount numeric(12,2) not null check(amount >= 0),
  due_day smallint not null check(due_day between 1 and 31),
  start_month date not null,
  end_month date,
  responsible_to uuid references auth.users(id) on delete set null,
  warning_days integer not null default 3 check(warning_days between 0 and 30),
  notes text,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recurring_bill_payments (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  bill_id uuid not null references public.recurring_bills(id) on delete cascade,
  billing_month date not null,
  due_date date not null,
  amount numeric(12,2) not null,
  finance_entry_id uuid references public.finance_entries(id) on delete set null,
  paid_by uuid references auth.users(id) on delete set null,
  paid_at timestamptz not null default now(),
  unique(bill_id, billing_month)
);

create table if not exists public.shopping_items (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  item_name text not null,
  quantity text,
  category text not null default '🛒 Mercado',
  assigned_to uuid references auth.users(id) on delete set null,
  estimated_price numeric(12,2) check(estimated_price is null or estimated_price >= 0),
  notes text,
  is_bought boolean not null default false,
  bought_at timestamptz,
  bought_by uuid references auth.users(id) on delete set null,
  finance_entry_id uuid references public.finance_entries(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.pet_health_records (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  pet_id uuid not null references public.pets(id) on delete cascade,
  record_type text not null check(record_type in ('vaccine','dewormer','flea','vet','weight','medicine','other')),
  title text not null,
  record_date date not null,
  next_due_date date,
  weight_kg numeric(6,2),
  dosage text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.goals (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  title text not null,
  goal_type text not null default 'count' check(goal_type in ('money','count','percent')),
  current_value numeric(14,2) not null default 0,
  target_value numeric(14,2) not null check(target_value > 0),
  unit text,
  deadline date,
  notes text,
  status text not null default 'active' check(status in ('active','completed','paused')),
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  board_id uuid not null references public.boards(id) on delete cascade,
  item_name text not null,
  category text not null default '✨ Outro',
  unit text,
  current_qty numeric(12,2) not null default 0 check(current_qty >= 0),
  min_qty numeric(12,2) not null default 0 check(min_qty >= 0),
  notes text,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.shared_task_exceptions enable row level security;
alter table public.recurring_bills enable row level security;
alter table public.recurring_bill_payments enable row level security;
alter table public.shopping_items enable row level security;
alter table public.pet_health_records enable row level security;
alter table public.goals enable row level security;
alter table public.inventory_items enable row level security;

do $$
declare t text;
begin
  foreach t in array array[
    'shared_task_exceptions','recurring_bills','recurring_bill_payments',
    'shopping_items','pet_health_records','goals','inventory_items'
  ] loop
    execute format('drop policy if exists "v5 select" on public.%I',t);
    execute format('drop policy if exists "v5 insert" on public.%I',t);
    execute format('drop policy if exists "v5 update" on public.%I',t);
    execute format('drop policy if exists "v5 delete" on public.%I',t);
    execute format('create policy "v5 select" on public.%I for select to authenticated using (public.is_board_member(board_id))',t);
    execute format('create policy "v5 insert" on public.%I for insert to authenticated with check (public.is_board_member(board_id))',t);
    execute format('create policy "v5 update" on public.%I for update to authenticated using (public.is_board_member(board_id)) with check (public.is_board_member(board_id))',t);
    execute format('create policy "v5 delete" on public.%I for delete to authenticated using (public.is_board_member(board_id))',t);
  end loop;
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'shared_task_exceptions','recurring_bills','recurring_bill_payments',
    'shopping_items','pet_health_records','goals','inventory_items'
  ] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I',t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
