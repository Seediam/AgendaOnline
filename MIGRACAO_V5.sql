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
