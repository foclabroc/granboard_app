-- Foclaboard : jeu en ligne 1 contre 1 (chacun chez soi avec sa cible).
--   • joueurs en ligne (présence), défis, salle de partie synchronisée
--   • messages de mise en relation de la vidéo (WebRTC) : la vidéo passe en
--     direct entre les 2 téléphones, jamais par le serveur
--   • gb_config : réglages lus par l'appli (serveurs STUN/TURN de la vidéo)
-- Les notifications passent par le relais temps réel de Pixel Trade
-- (rc__rt_safe), comme le salon TV.
-- Relançable. À lancer en postgres APRÈS 2026-11-11_photo_son.sql :
--   psql -U postgres -d postgres -f 2026-11-12_en_ligne.sql

begin;

create table if not exists public.gb_online (
  player_id bigint primary key references public.gb_players(id) on delete cascade,
  seen_at   timestamptz not null default now(),
  busy      boolean not null default false
);

create table if not exists public.gb_on_rooms (
  id         bigserial primary key,
  a_id       bigint not null references public.gb_players(id) on delete cascade,  -- celui qui a défié
  b_id       bigint not null references public.gb_players(id) on delete cascade,
  game       jsonb not null,            -- la partie (réglages, joueurs, journal d'actions)
  seq        bigint not null default 1,
  a_seen     timestamptz not null default now(),
  b_seen     timestamptz not null default now(),
  left_by    bigint,                    -- joueur qui a quitté
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.gb_on_invites (
  id         bigserial primary key,
  from_id    bigint not null references public.gb_players(id) on delete cascade,
  to_id      bigint not null references public.gb_players(id) on delete cascade,
  game       jsonb not null,
  status     text not null default 'pending',  -- pending | accepted | declined | cancelled | expired
  room_id    bigint,
  created_at timestamptz not null default now()
);
create index if not exists gb_on_invites_to_ix   on public.gb_on_invites (to_id, status);
create index if not exists gb_on_invites_from_ix on public.gb_on_invites (from_id, created_at);

create table if not exists public.gb_on_signals (
  id         bigserial primary key,
  room_id    bigint not null references public.gb_on_rooms(id) on delete cascade,
  from_id    bigint not null,
  data       jsonb not null,
  created_at timestamptz not null default now()
);
create index if not exists gb_on_signals_room_ix on public.gb_on_signals (room_id, id);

create table if not exists public.gb_config (
  key   text primary key,
  value jsonb not null
);
-- Serveurs de mise en relation de la vidéo. Pour ajouter un relais TURN plus tard :
--   update gb_config set value = value || '[{"urls":["turn:HOTE:3478"],"username":"U","credential":"MDP"}]'
--    where key = 'ice';
insert into public.gb_config (key, value)
values ('ice', '[{"urls":["stun:stun.l.google.com:19302","stun:stun1.l.google.com:19302"]}]')
on conflict (key) do nothing;

alter table public.gb_online     owner to rc_owner;
alter table public.gb_on_rooms   owner to rc_owner;
alter table public.gb_on_invites owner to rc_owner;
alter table public.gb_on_signals owner to rc_owner;
alter table public.gb_config     owner to rc_owner;
alter sequence public.gb_on_rooms_id_seq   owner to rc_owner;
alter sequence public.gb_on_invites_id_seq owner to rc_owner;
alter sequence public.gb_on_signals_id_seq owner to rc_owner;
revoke all on public.gb_online, public.gb_on_rooms, public.gb_on_invites, public.gb_on_signals, public.gb_config
  from public, anon, authenticated;
revoke all on sequence public.gb_on_rooms_id_seq, public.gb_on_invites_id_seq, public.gb_on_signals_id_seq
  from public, anon, authenticated;

-- ─── Fonctions internes ────────────────────────────────────────────────────

-- Canal du relais : « u<id joueur> » (défis) ou « r<id salle> » (partie)
create or replace function public.gb__on_topic(p text) returns text
 language sql immutable
 set search_path to 'public'
as $$ select 'rc_' || left(encode(extensions.digest('gbon|' || p, 'sha256'), 'hex'), 24) $$;

create or replace function public.gb__on_notify(p text) returns void
 language plpgsql
 set search_path to 'public'
as $$
begin
  perform rc__rt_safe(gb__on_topic(p), 'gb', jsonb_build_object('t', 1));
end $$;

-- Fiche courte d'un joueur (liste en ligne, défi)
create or replace function public.gb__on_player(p_pid bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_build_object('id', p.id, 'pseudo', p.pseudo, 'color', p.color,
                            'rating', gb__rating(p.id))
    from gb_players p where p.id = p_pid
$$;

-- Joueur présent (vu depuis moins de 40 s) ?
create or replace function public.gb__on_here(p_pid bigint) returns boolean
 language sql stable
 set search_path to 'public'
as $$ select exists (select 1 from gb_online where player_id = p_pid and seen_at > now() - interval '40 seconds') $$;

-- ─── Présence et défis ─────────────────────────────────────────────────────

-- À appeler toutes les 10 s environ tant que l'appli est ouverte :
-- {me, topic, online: [...], invite: défi reçu, sent: mon dernier défi, room: partie à reprendre}
create or replace function public.gb_on_ping(p_token text, p_busy boolean default false)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  v_inv gb_on_invites;
  v_sent gb_on_invites;
  v_room bigint;
begin
  insert into gb_online (player_id, seen_at, busy) values (v_pid, now(), coalesce(p_busy, false))
  on conflict (player_id) do update set seen_at = now(), busy = excluded.busy;

  -- Ménage
  update gb_on_invites set status = 'expired'
   where status = 'pending' and created_at < now() - interval '45 seconds';
  delete from gb_on_invites where created_at < now() - interval '1 day';
  delete from gb_on_rooms   where updated_at < now() - interval '1 day';
  delete from gb_online     where seen_at    < now() - interval '10 minutes';

  select * into v_inv from gb_on_invites
   where to_id = v_pid and status = 'pending' order by id desc limit 1;
  select * into v_sent from gb_on_invites
   where from_id = v_pid and created_at > now() - interval '2 minutes' order by id desc limit 1;
  -- Partie en cours à reprendre (appli fermée par erreur)
  select id into v_room from gb_on_rooms
   where (a_id = v_pid or b_id = v_pid) and left_by is null
     and updated_at > now() - interval '10 minutes'
   order by id desc limit 1;

  return jsonb_build_object(
    'me', v_pid,
    'topic', gb__on_topic('u' || v_pid),
    'online', coalesce((
      select jsonb_agg(gb__on_player(o.player_id) || jsonb_build_object('busy', o.busy)
                       order by o.busy, lower(p.pseudo))
        from gb_online o join gb_players p on p.id = o.player_id
       where o.player_id <> v_pid and o.seen_at > now() - interval '40 seconds'), '[]'),
    'invite', case when v_inv.id is null then null else
      jsonb_build_object('id', v_inv.id, 'from', gb__on_player(v_inv.from_id), 'game', v_inv.game) end,
    'sent', case when v_sent.id is null then null else
      jsonb_build_object('id', v_sent.id, 'to', v_sent.to_id, 'status', v_sent.status, 'room', v_sent.room_id) end,
    'room', v_room);
end $$;

-- Quitte la liste des joueurs en ligne (appli en arrière-plan)
create or replace function public.gb_on_bye(p_token text)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
begin
  delete from gb_online where player_id = gb__auth(p_token);
end $$;

-- Défie un joueur : {id} ou {error: on_offline | on_busy}
create or replace function public.gb_on_invite(p_token text, p_to bigint, p_game jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  v_id bigint;
  v_ids text[];
begin
  if p_to is null or p_to = v_pid then
    raise exception 'on_player';
  end if;
  if octet_length(p_game::text) > 65536 or jsonb_typeof(p_game->'players') <> 'array' then
    raise exception 'on_game';
  end if;
  -- Les 2 joueurs de la partie sont bien les 2 comptes
  select array_agg(e->>'id' order by e->>'id') into v_ids from jsonb_array_elements(p_game->'players') e;
  if v_ids is distinct from (select array_agg(x order by x) from unnest(array[v_pid::text, p_to::text]) x) then
    raise exception 'on_game';
  end if;
  if not gb__on_here(p_to) then
    return jsonb_build_object('error', 'on_offline');
  end if;
  if exists (select 1 from gb_online where player_id = p_to and busy)
     or exists (select 1 from gb_on_invites
                 where to_id = p_to and status = 'pending' and from_id <> v_pid
                   and created_at > now() - interval '45 seconds') then
    return jsonb_build_object('error', 'on_busy');
  end if;
  update gb_on_invites set status = 'cancelled' where from_id = v_pid and status = 'pending';
  insert into gb_on_invites (from_id, to_id, game) values (v_pid, p_to, p_game) returning id into v_id;
  perform gb__on_notify('u' || p_to);
  return jsonb_build_object('id', v_id);
end $$;

-- Annule mon défi en attente
create or replace function public.gb_on_cancel(p_token text, p_invite bigint)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_to bigint;
begin
  update gb_on_invites set status = 'cancelled'
   where id = p_invite and from_id = v_pid and status = 'pending'
  returning to_id into v_to;
  if v_to is not null then
    perform gb__on_notify('u' || v_to);
  end if;
end $$;

-- Réponse à un défi : {room} si accepté, {} si refusé, {error: on_gone} s'il n'existe plus
create or replace function public.gb_on_answer(p_token text, p_invite bigint, p_accept boolean)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  v gb_on_invites;
  v_room bigint;
begin
  select * into v from gb_on_invites
   where id = p_invite and to_id = v_pid and status = 'pending'
     and created_at > now() - interval '60 seconds'
   for update;
  if v.id is null then
    return jsonb_build_object('error', 'on_gone');
  end if;
  if not coalesce(p_accept, false) then
    update gb_on_invites set status = 'declined' where id = v.id;
    perform gb__on_notify('u' || v.from_id);
    return '{}'::jsonb;
  end if;
  insert into gb_on_rooms (a_id, b_id, game) values (v.from_id, v_pid, v.game) returning id into v_room;
  update gb_on_invites set status = 'accepted', room_id = v_room where id = v.id;
  update gb_online set busy = true where player_id in (v.from_id, v_pid);
  perform gb__on_notify('u' || v.from_id);
  return jsonb_build_object('room', v_room);
end $$;

-- ─── Salle de partie ───────────────────────────────────────────────────────

-- État de la salle : {seq, [game], signals, peer_age, left, topic, side, peer, ice}
-- « game » seulement si seq > p_since ; « signals » = messages vidéo de l'autre après p_sig.
create or replace function public.gb_on_get(p_token text, p_room bigint, p_since bigint default 0, p_sig bigint default 0)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  r gb_on_rooms;
  v_a boolean;
begin
  select * into r from gb_on_rooms where id = p_room and (a_id = v_pid or b_id = v_pid);
  if r.id is null then
    return jsonb_build_object('error', 'on_room');
  end if;
  v_a := r.a_id = v_pid;
  if v_a then
    update gb_on_rooms set a_seen = now() where id = r.id;
  else
    update gb_on_rooms set b_seen = now() where id = r.id;
  end if;
  if r.left_by is null then
    insert into gb_online (player_id, seen_at, busy) values (v_pid, now(), true)
    on conflict (player_id) do update set seen_at = now(), busy = true;
  end if;
  return jsonb_build_object(
    'seq', r.seq,
    'side', case when v_a then 'a' else 'b' end,
    'peer', gb__on_player(case when v_a then r.b_id else r.a_id end),
    'peer_age', floor(extract(epoch from now() - case when v_a then r.b_seen else r.a_seen end))::int,
    'left', r.left_by is not null,
    'topic', gb__on_topic('r' || r.id),
    'ice', coalesce((select value from gb_config where key = 'ice'), '[]'::jsonb),
    'signals', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'data', s.data) order by s.id)
        from gb_on_signals s
       where s.room_id = r.id and s.from_id <> v_pid and s.id > coalesce(p_sig, 0)), '[]'))
    || case when r.seq > coalesce(p_since, 0) then jsonb_build_object('game', r.game) else '{}'::jsonb end;
end $$;

-- Envoie la partie après une action : {seq} ou {error: on_conflict} si l'autre
-- a joué entre-temps (l'appli relit alors la salle).
create or replace function public.gb_on_push(p_token text, p_room bigint, p_seq bigint, p_game jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  r gb_on_rooms;
begin
  select * into r from gb_on_rooms
   where id = p_room and (a_id = v_pid or b_id = v_pid) for update;
  if r.id is null or r.left_by is not null then
    return jsonb_build_object('error', 'on_room');
  end if;
  if octet_length(p_game::text) > 131072 then
    raise exception 'too_big';
  end if;
  -- Seul le journal d'actions change : réglages et joueurs sont ceux du défi
  if (p_game - 'actions') is distinct from (r.game - 'actions') then
    raise exception 'on_game';
  end if;
  if r.seq <> coalesce(p_seq, 0) then
    return jsonb_build_object('error', 'on_conflict');
  end if;
  update gb_on_rooms set game = p_game, seq = seq + 1, updated_at = now() where id = r.id;
  perform gb__on_notify('r' || r.id);
  return jsonb_build_object('seq', r.seq + 1);
end $$;

-- Message de mise en relation de la vidéo pour l'autre joueur
create or replace function public.gb_on_signal(p_token text, p_room bigint, p_data jsonb)
 returns bigint
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_id bigint;
begin
  if not exists (select 1 from gb_on_rooms where id = p_room and (a_id = v_pid or b_id = v_pid)) then
    raise exception 'on_room';
  end if;
  if octet_length(p_data::text) > 32768 then
    raise exception 'too_big';
  end if;
  delete from gb_on_signals where room_id = p_room and created_at < now() - interval '10 minutes';
  insert into gb_on_signals (room_id, from_id, data) values (p_room, v_pid, p_data) returning id into v_id;
  perform gb__on_notify('r' || p_room);
  return v_id;
end $$;

-- Quitte la partie (l'autre est prévenu)
create or replace function public.gb_on_leave(p_token text, p_room bigint)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_id bigint;
begin
  update gb_on_rooms set left_by = coalesce(left_by, v_pid), updated_at = now()
   where id = p_room and (a_id = v_pid or b_id = v_pid)
  returning id into v_id;
  update gb_online set busy = false where player_id = v_pid;
  if v_id is not null then
    perform gb__on_notify('r' || v_id);
  end if;
end $$;

-- Propriétaire et droits (même règle que les autres fichiers)
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and (p.proname like 'gb\_on\_%' or p.proname like 'gb\_\_on\_%')
  loop
    execute format('alter function %s owner to rc_owner', f.sig);
    if f.proname like 'gb\_\_%' then
      execute format('revoke execute on function %s from public, anon, authenticated', f.sig);
    else
      execute format('grant execute on function %s to anon', f.sig);
    end if;
  end loop;
end $$;

commit;

notify pgrst, 'reload schema';

-- Contrôle : 5 tables, 9 fonctions ouvertes
select
  (select count(*) from pg_tables where schemaname = 'public'
    and tablename in ('gb_online', 'gb_on_rooms', 'gb_on_invites', 'gb_on_signals', 'gb_config')) as tables,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname in ('gb_on_ping', 'gb_on_bye', 'gb_on_invite', 'gb_on_cancel',
      'gb_on_answer', 'gb_on_get', 'gb_on_push', 'gb_on_signal', 'gb_on_leave')) as rpc;
