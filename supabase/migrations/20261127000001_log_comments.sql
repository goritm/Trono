-- Trono V2.6: Real-time Comments on Shared Feed Logs
-- Privacy invariant: comments can only attach to public.shared_logs (never private logs)
-- and cascade-delete automatically when a log is deleted or switched to private.

create table public.log_comments (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references public.shared_logs(log_id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 280),
  created_at timestamptz not null default now()
);

alter table public.log_comments enable row level security;

create index idx_log_comments_log_created
  on public.log_comments (log_id, created_at asc);

create index idx_log_comments_user_id
  on public.log_comments (user_id);

-- Row-Level Security Policies (TO authenticated + (select auth.uid()))

create policy "log_comments_select_visible"
  on public.log_comments for select
  to authenticated
  using (
    exists (
      select 1 from public.shared_logs sl
      where sl.log_id = log_comments.log_id
        and (
          sl.user_id = (select auth.uid())
          or (select private.shares_group_with(sl.user_id))
        )
    )
  );

create policy "log_comments_insert_visible"
  on public.log_comments for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.shared_logs sl
      where sl.log_id = log_comments.log_id
        and (
          sl.user_id = (select auth.uid())
          or (select private.shares_group_with(sl.user_id))
        )
    )
  );

create policy "log_comments_delete_owner"
  on public.log_comments for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- Idempotently enable Realtime for public.log_comments
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'log_comments'
  ) then
    alter publication supabase_realtime add table public.log_comments;
  end if;
end
$$;
