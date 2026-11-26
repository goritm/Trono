-- Trono V2: Multiplayer, Cloud Sync & Privacy-Preserving Shared Feed
-- Exact GPS coordinates (lat/lng) and work salary NEVER leave the device.

create schema if not exists private;
grant usage on schema private to authenticated;

-- 1. Profiles
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 32),
  avatar_emoji text not null default '👑' check (char_length(avatar_emoji) between 1 and 12),
  total_xp integer not null default 0 check (total_xp >= 0),
  rank_level integer not null default 1 check (rank_level between 1 and 7),
  current_streak integer not null default 0 check (current_streak >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- 2. Private Groups
create table public.groups (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 1 and 40),
  emoji text not null default '👑' check (char_length(emoji) between 1 and 12),
  invite_code text not null unique check (invite_code ~ '^[A-Z0-9]{6}$'),
  created_by uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.groups enable row level security;
create index idx_groups_created_by on public.groups (created_by);

-- 3. Group Members
create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table public.group_members enable row level security;
create index idx_group_members_user_id on public.group_members (user_id);

-- 4. Private RLS helper functions (non-exposed schema, strict auth.uid() checks)
create or replace function private.is_group_member(p_group_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.group_members gm
      where gm.group_id = p_group_id
        and gm.user_id = (select auth.uid())
    );
$$;

create or replace function private.shares_group_with(p_other_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (select auth.uid()) is not null
    and exists (
      select 1
      from public.group_members m1
      join public.group_members m2 on m1.group_id = m2.group_id
      where m1.user_id = (select auth.uid())
        and m2.user_id = p_other_user_id
    );
$$;

revoke all on function private.is_group_member(uuid) from public, anon;
grant execute on function private.is_group_member(uuid) to authenticated;

revoke all on function private.shares_group_with(uuid) from public, anon;
grant execute on function private.shares_group_with(uuid) to authenticated;

-- 5. Personal Bathroom Logs (100% owner-only cloud backup; NO lat/lng or salary!)
create table public.bathroom_logs (
  id uuid primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('poop', 'false_alarm')),
  "timestamp" timestamptz not null,
  bristol_type smallint check (bristol_type between 1 and 7),
  size text check (size in ('small', 'normal', 'epic')),
  effort text check (effort in ('effortless', 'normal', 'struggled', 'urgent')),
  duration_seconds integer check (duration_seconds >= 0 and duration_seconds <= 86400),
  color text check (color in ('brown', 'lightBrown', 'darkBrown', 'green', 'yellow', 'reddish')),
  tags text[] not null default '{}',
  note text,
  location_kind text check (location_kind in ('home', 'work', 'away')),
  place_label text,
  share_level text not null default 'summary_only' check (share_level in ('private', 'summary_only', 'full')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

alter table public.bathroom_logs enable row level security;
create index idx_bathroom_logs_user_ts on public.bathroom_logs (user_id, "timestamp" desc);
create index idx_bathroom_logs_user_updated on public.bathroom_logs (user_id, updated_at desc);

-- 6. Privacy-Redacted Shared Logs Projection (feeds group feed, leaderboards & Realtime)
create table public.shared_logs (
  log_id uuid primary key references public.bathroom_logs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('poop', 'false_alarm')),
  "timestamp" timestamptz not null,
  location_kind text check (location_kind in ('home', 'work', 'away')),
  share_level text not null check (share_level in ('summary_only', 'full')),
  bristol_type smallint,
  size text,
  effort text,
  duration_seconds integer,
  color text,
  tags text[] not null default '{}',
  note text,
  place_label text,
  updated_at timestamptz not null default now()
);

alter table public.shared_logs enable row level security;
create index idx_shared_logs_user_ts on public.shared_logs (user_id, "timestamp" desc);
create index idx_shared_logs_ts on public.shared_logs ("timestamp" desc);

-- Trigger to keep shared_logs automatically synced & strictly redacted
create or replace function private.sync_shared_log()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.shared_logs where log_id = old.id;
    return old;
  end if;

  if new.deleted_at is not null or new.share_level = 'private' then
    delete from public.shared_logs where log_id = new.id;
    return new;
  end if;

  if new.share_level = 'summary_only' then
    insert into public.shared_logs (
      log_id, user_id, type, "timestamp", location_kind, share_level,
      bristol_type, size, effort, duration_seconds, color, tags, note, place_label, updated_at
    )
    values (
      new.id, new.user_id, new.type, new."timestamp", new.location_kind, 'summary_only',
      null, null, null, null, null, '{}', null, null, new.updated_at
    )
    on conflict (log_id) do update set
      type = excluded.type,
      "timestamp" = excluded."timestamp",
      location_kind = excluded.location_kind,
      share_level = 'summary_only',
      bristol_type = null,
      size = null,
      effort = null,
      duration_seconds = null,
      color = null,
      tags = '{}',
      note = null,
      place_label = null,
      updated_at = excluded.updated_at;
  else
    insert into public.shared_logs (
      log_id, user_id, type, "timestamp", location_kind, share_level,
      bristol_type, size, effort, duration_seconds, color, tags, note, place_label, updated_at
    )
    values (
      new.id, new.user_id, new.type, new."timestamp", new.location_kind, 'full',
      new.bristol_type, new.size, new.effort, new.duration_seconds, new.color,
      coalesce(new.tags, '{}'), new.note, new.place_label, new.updated_at
    )
    on conflict (log_id) do update set
      type = excluded.type,
      "timestamp" = excluded."timestamp",
      location_kind = excluded.location_kind,
      share_level = 'full',
      bristol_type = excluded.bristol_type,
      size = excluded.size,
      effort = excluded.effort,
      duration_seconds = excluded.duration_seconds,
      color = excluded.color,
      tags = excluded.tags,
      note = excluded.note,
      place_label = excluded.place_label,
      updated_at = excluded.updated_at;
  end if;

  return new;
end;
$$;

create trigger trg_bathroom_logs_sync_shared
  after insert or update or delete on public.bathroom_logs
  for each row execute function private.sync_shared_log();

-- 7. Reactions on Shared Logs
create table public.log_reactions (
  id uuid primary key default gen_random_uuid(),
  log_id uuid not null references public.shared_logs(log_id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  emoji text not null check (emoji in ('👑', '🔥', '💀', '👏')),
  created_at timestamptz not null default now(),
  unique (log_id, user_id, emoji)
);

alter table public.log_reactions enable row level security;
create index idx_log_reactions_log_id on public.log_reactions (log_id);
create index idx_log_reactions_user_id on public.log_reactions (user_id);

-- 8. Auto-create profile row on auth.users signup (convenience only; never used for authz)
create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_name text;
  v_emoji text;
begin
  v_name := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Trono'
  );
  v_name := left(v_name, 32);
  v_emoji := coalesce(nullif(trim(new.raw_user_meta_data ->> 'avatar_emoji'), ''), '👑');
  v_emoji := left(v_emoji, 12);

  insert into public.profiles (id, display_name, avatar_emoji)
  values (new.id, v_name, v_emoji)
  on conflict (id) do nothing;

  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- 9. Row-Level Security Policies (TO authenticated + (select auth.uid()))

-- profiles
create policy "profiles_select_self_or_group"
  on public.profiles for select
  to authenticated
  using (
    (select auth.uid()) = id
    or (select private.shares_group_with(id))
  );

create policy "profiles_insert_self"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "profiles_update_self"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- groups
create policy "groups_select_members"
  on public.groups for select
  to authenticated
  using ((select private.is_group_member(id)));

create policy "groups_update_creator"
  on public.groups for update
  to authenticated
  using ((select auth.uid()) = created_by)
  with check ((select auth.uid()) = created_by);

create policy "groups_delete_creator"
  on public.groups for delete
  to authenticated
  using ((select auth.uid()) = created_by);

-- group_members
create policy "group_members_select_members"
  on public.group_members for select
  to authenticated
  using ((select private.is_group_member(group_id)));

create policy "group_members_delete_self_or_owner"
  on public.group_members for delete
  to authenticated
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1 from public.groups g
      where g.id = group_members.group_id
        and g.created_by = (select auth.uid())
    )
  );

-- bathroom_logs (strictly owner-only)
create policy "bathroom_logs_select_owner"
  on public.bathroom_logs for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "bathroom_logs_insert_owner"
  on public.bathroom_logs for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "bathroom_logs_update_owner"
  on public.bathroom_logs for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "bathroom_logs_delete_owner"
  on public.bathroom_logs for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- shared_logs (read-only for owner & group mates; written only via trigger)
create policy "shared_logs_select_self_or_group"
  on public.shared_logs for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or (select private.shares_group_with(user_id))
  );

-- log_reactions
create policy "log_reactions_select_visible"
  on public.log_reactions for select
  to authenticated
  using (
    exists (
      select 1 from public.shared_logs sl
      where sl.log_id = log_reactions.log_id
        and (
          sl.user_id = (select auth.uid())
          or (select private.shares_group_with(sl.user_id))
        )
    )
  );

create policy "log_reactions_insert_visible"
  on public.log_reactions for insert
  to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.shared_logs sl
      where sl.log_id = log_reactions.log_id
        and (
          sl.user_id = (select auth.uid())
          or (select private.shares_group_with(sl.user_id))
        )
    )
  );

create policy "log_reactions_delete_owner"
  on public.log_reactions for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- 10. Authenticated RPCs for group creation, invite-code join & leaderboard
create or replace function public.create_group(
  p_name text,
  p_emoji text default '👑'
)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_clean_name text := trim(coalesce(p_name, ''));
  v_clean_emoji text := coalesce(nullif(trim(p_emoji), ''), '👑');
  v_chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_group public.groups;
  v_attempt int := 0;
  v_i int;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if char_length(v_clean_name) < 1 or char_length(v_clean_name) > 40 then
    raise exception 'INVALID_GROUP_NAME';
  end if;

  loop
    v_attempt := v_attempt + 1;
    v_code := '';
    for v_i in 1..6 loop
      v_code := v_code || substr(v_chars, 1 + floor(random() * length(v_chars))::int, 1);
    end loop;

    begin
      insert into public.groups (name, emoji, invite_code, created_by)
      values (v_clean_name, left(v_clean_emoji, 12), v_code, v_uid)
      returning * into v_group;
      exit;
    exception when unique_violation then
      if v_attempt >= 12 then
        raise exception 'COULD_NOT_GENERATE_CODE';
      end if;
    end;
  end loop;

  insert into public.group_members (group_id, user_id, role)
  values (v_group.id, v_uid, 'owner')
  on conflict (group_id, user_id) do nothing;

  return v_group;
end;
$$;

create or replace function public.join_group_by_code(p_code text)
returns public.groups
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_norm text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  v_group public.groups;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if length(v_norm) <> 6 then
    raise exception 'INVALID_CODE';
  end if;

  select * into v_group
  from public.groups
  where invite_code = v_norm;

  if not found then
    raise exception 'GROUP_NOT_FOUND';
  end if;

  insert into public.group_members (group_id, user_id, role)
  values (v_group.id, v_uid, 'member')
  on conflict (group_id, user_id) do nothing;

  return v_group;
end;
$$;

create or replace function public.get_group_leaderboard(
  p_group_id uuid,
  p_days integer default 7
)
returns table (
  user_id uuid,
  display_name text,
  avatar_emoji text,
  total_xp integer,
  rank_level integer,
  current_streak integer,
  poop_count integer,
  away_count integer,
  work_count integer,
  total_duration_seconds integer
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_since timestamptz;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if not private.is_group_member(p_group_id) then
    raise exception 'NOT_A_MEMBER';
  end if;

  if p_days is not null and p_days > 0 then
    v_since := now() - make_interval(days => p_days);
  else
    v_since := '-infinity'::timestamptz;
  end if;

  return query
  select
    p.id as user_id,
    p.display_name,
    p.avatar_emoji,
    p.total_xp,
    p.rank_level,
    p.current_streak,
    coalesce(count(sl.log_id) filter (where sl.type = 'poop'), 0)::integer as poop_count,
    coalesce(count(sl.log_id) filter (where sl.type = 'poop' and sl.location_kind in ('away', 'work')), 0)::integer as away_count,
    coalesce(count(sl.log_id) filter (where sl.type = 'poop' and sl.location_kind = 'work'), 0)::integer as work_count,
    coalesce(sum(sl.duration_seconds) filter (where sl.type = 'poop'), 0)::integer as total_duration_seconds
  from public.group_members gm
  join public.profiles p on p.id = gm.user_id
  left join public.shared_logs sl
    on sl.user_id = gm.user_id
   and sl."timestamp" >= v_since
  where gm.group_id = p_group_id
  group by p.id, p.display_name, p.avatar_emoji, p.total_xp, p.rank_level, p.current_streak
  order by poop_count desc, away_count desc, p.total_xp desc, p.display_name asc;
end;
$$;

revoke all on function public.create_group(text, text) from public, anon;
grant execute on function public.create_group(text, text) to authenticated;

revoke all on function public.join_group_by_code(text) from public, anon;
grant execute on function public.join_group_by_code(text) to authenticated;

revoke all on function public.get_group_leaderboard(uuid, integer) from public, anon;
grant execute on function public.get_group_leaderboard(uuid, integer) to authenticated;

-- 11. Enable Realtime on social tables
alter publication supabase_realtime add table public.shared_logs;
alter publication supabase_realtime add table public.log_reactions;
alter publication supabase_realtime add table public.group_members;
