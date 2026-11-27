-- Trono V2.8: Instant Social Push Notifications (FCM HTTP v1 + Native Android Channels)
-- Stores per-device FCM tokens + independent channel toggles (thrones, comments, reactions).
-- Exact GPS coordinates, work salary, and private logs NEVER leave the device or trigger pushes.

create extension if not exists pg_net;

-- 1. Device Push Tokens & Per-Category Preferences
create table if not exists public.push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique check (char_length(trim(token)) between 20 and 512),
  platform text not null default 'android' check (platform in ('android', 'ios')),
  locale text not null default 'en' check (locale in ('en', 'es')),
  notify_friend_thrones boolean not null default true,
  notify_friend_comments boolean not null default true,
  notify_friend_reactions boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.push_tokens enable row level security;
create index if not exists idx_push_tokens_user_id on public.push_tokens (user_id);

-- Strict owner-only RLS policies (TO authenticated + (select auth.uid()))
create policy "push_tokens_select_owner"
  on public.push_tokens for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "push_tokens_insert_owner"
  on public.push_tokens for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "push_tokens_update_owner"
  on public.push_tokens for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "push_tokens_delete_owner"
  on public.push_tokens for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- 2. Authenticated RPC to safely upsert/reassign a device token on account switch
create or replace function public.upsert_my_push_token(
  p_token text,
  p_platform text default 'android',
  p_locale text default 'en',
  p_notify_friend_thrones boolean default true,
  p_notify_friend_comments boolean default true,
  p_notify_friend_reactions boolean default true
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_token text := trim(coalesce(p_token, ''));
  v_platform text := case when p_platform = 'ios' then 'ios' else 'android' end;
  v_locale text := case when lower(coalesce(p_locale, 'en')) like 'es%' then 'es' else 'en' end;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;
  if char_length(v_token) < 20 or char_length(v_token) > 512 then
    raise exception 'INVALID_TOKEN';
  end if;

  insert into public.push_tokens (
    user_id,
    token,
    platform,
    locale,
    notify_friend_thrones,
    notify_friend_comments,
    notify_friend_reactions,
    updated_at
  )
  values (
    v_uid,
    v_token,
    v_platform,
    v_locale,
    coalesce(p_notify_friend_thrones, true),
    coalesce(p_notify_friend_comments, true),
    coalesce(p_notify_friend_reactions, true),
    now()
  )
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    locale = excluded.locale,
    notify_friend_thrones = excluded.notify_friend_thrones,
    notify_friend_comments = excluded.notify_friend_comments,
    notify_friend_reactions = excluded.notify_friend_reactions,
    updated_at = now();
end;
$$;

revoke all on function public.upsert_my_push_token(text, text, text, boolean, boolean, boolean) from public, anon;
grant execute on function public.upsert_my_push_token(text, text, text, boolean, boolean, boolean) to authenticated;

-- 3. Internal Webhook Config (non-exposed private schema, zero client access)
create table if not exists private.push_webhook_config (
  id integer primary key check (id = 1),
  function_url text not null,
  webhook_secret text not null,
  updated_at timestamptz not null default now()
);

alter table private.push_webhook_config enable row level security;
revoke all on table private.push_webhook_config from public, anon, authenticated;

-- 4. Async Trigger Dispatcher -> Supabase Edge Function `send-social-push`
create or replace function private.dispatch_social_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_url text;
  v_secret text;
  v_payload jsonb;
begin
  select function_url, webhook_secret
    into v_url, v_secret
  from private.push_webhook_config
  where id = 1;

  if v_url is null or v_secret is null or v_url = '' or v_secret = '' then
    return new;
  end if;

  if tg_table_name = 'shared_logs' then
    -- Only push fresh throne claims (skip false alarms & >15m offline backfill)
    if new.type <> 'poop' or new."timestamp" < (now() - interval '15 minutes') then
      return new;
    end if;
    v_payload := jsonb_build_object(
      'event', 'friend_throne',
      'actor_id', new.user_id,
      'log_id', new.log_id,
      'location_kind', coalesce(new.location_kind, '')
    );
  elsif tg_table_name = 'log_comments' then
    v_payload := jsonb_build_object(
      'event', 'friend_comment',
      'actor_id', new.user_id,
      'log_id', new.log_id,
      'comment_id', new.id,
      'comment_body', left(coalesce(new.body, ''), 140)
    );
  elsif tg_table_name = 'log_reactions' then
    v_payload := jsonb_build_object(
      'event', 'friend_reaction',
      'actor_id', new.user_id,
      'log_id', new.log_id,
      'reaction_emoji', coalesce(new.emoji, '👑')
    );
  else
    return new;
  end if;

  begin
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-trono-webhook-secret', v_secret
      ),
      body := v_payload
    );
  exception when others then
    -- Never fail a user's log/comment/reaction write if push dispatch fails
    null;
  end;

  return new;
end;
$$;

revoke all on function private.dispatch_social_push() from public, anon, authenticated;

create trigger trg_push_shared_logs
  after insert on public.shared_logs
  for each row execute function private.dispatch_social_push();

create trigger trg_push_log_comments
  after insert on public.log_comments
  for each row execute function private.dispatch_social_push();

create trigger trg_push_log_reactions
  after insert on public.log_reactions
  for each row execute function private.dispatch_social_push();
