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
