-- Foclaboard : salons en ligne à plusieurs maisons (2 à 4 cibles, chacune
-- avec ses joueurs) + identifiants temporaires du relais TURN de la vidéo.
--
-- Salon : public (liste « Salons ouverts ») ou privé (sur invitation),
-- l'hôte choisit le jeu puis lance ; la partie devient une salle
-- `gb_on_rooms` dont les maisons sont dans `gb_on_homes` (h1 = hôte, h2…).
-- Les parties 1 contre 1 (a/b) ne changent pas.
--
-- Relais TURN : la clé partagée n'est PAS dans ce fichier (dépôt public).
-- Elle se pose une fois sur le serveur :
--   insert into gb_config (key, value) values ('turn', '{"urls":["turn:HOTE:3478?transport=udp",
--     "turn:HOTE:3478?transport=tcp"],"secret":"CLE","ttl":86400}')
--   on conflict (key) do update set value = excluded.value;
-- (même CLE que dans turn.json du serveur TURN, voir tools/turn).
--
-- Relançable. À lancer en postgres :
--   psql -U postgres -d postgres -f 2026-11-17_salons.sql

begin;

-- ─── Tables ────────────────────────────────────────────────────────────────

create table if not exists public.gb_on_homes (
  room_id   bigint not null references public.gb_on_rooms(id) on delete cascade,
  player_id bigint not null references public.gb_players(id) on delete cascade,
  home      text   not null,               -- h1 (hôte), h2, h3, h4
  seen_at   timestamptz not null default now(),
  left_at   timestamptz,
  primary key (room_id, player_id)
);
create index if not exists gb_on_homes_player_ix on public.gb_on_homes (player_id);

create table if not exists public.gb_on_lobbies (
  id         bigserial primary key,
  host_id    bigint not null references public.gb_players(id) on delete cascade,
  public     boolean not null default false,
  game       jsonb,                         -- jeu choisi par l'hôte {kind, settings, label}
  status     text not null default 'open',  -- open | started | closed
  room_id    bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists gb_on_lobbies_open_ix on public.gb_on_lobbies (status, public);

create table if not exists public.gb_on_lb_members (
  lobby_id  bigint not null references public.gb_on_lobbies(id) on delete cascade,
  player_id bigint not null references public.gb_players(id) on delete cascade,
  players   jsonb not null default '[]',    -- joueurs de cette maison [{id, name}]
  joined_at timestamptz not null default now(),
  seen_at   timestamptz not null default now(),
  primary key (lobby_id, player_id)
);
create index if not exists gb_on_lb_members_player_ix on public.gb_on_lb_members (player_id);

create table if not exists public.gb_on_lb_invites (
  lobby_id   bigint not null references public.gb_on_lobbies(id) on delete cascade,
  to_id      bigint not null references public.gb_players(id) on delete cascade,
  from_id    bigint not null,
  status     text not null default 'pending',  -- pending | declined
  created_at timestamptz not null default now(),
  primary key (lobby_id, to_id)
);
create index if not exists gb_on_lb_invites_to_ix on public.gb_on_lb_invites (to_id, status);

alter table public.gb_on_homes      owner to rc_owner;
alter table public.gb_on_lobbies    owner to rc_owner;
alter table public.gb_on_lb_members owner to rc_owner;
alter table public.gb_on_lb_invites owner to rc_owner;
alter sequence public.gb_on_lobbies_id_seq owner to rc_owner;
revoke all on public.gb_on_homes, public.gb_on_lobbies, public.gb_on_lb_members, public.gb_on_lb_invites
  from public, anon, authenticated;
revoke all on sequence public.gb_on_lobbies_id_seq from public, anon, authenticated;

-- ─── Fonctions internes ────────────────────────────────────────────────────

-- Le joueur fait partie de la salle (1 contre 1 ou maison d'un salon) ?
-- p_active : seulement s'il ne l'a pas quittée (maisons d'un salon).
create or replace function public.gb__on_member(p_room bigint, p_pid bigint, p_active boolean default false)
 returns boolean
 language sql stable
 set search_path to 'public'
as $$
  select exists (select 1 from gb_on_rooms r where r.id = p_room and p_pid in (r.a_id, r.b_id)
                   and not exists (select 1 from gb_on_homes h where h.room_id = r.id))
      or exists (select 1 from gb_on_homes h where h.room_id = p_room and h.player_id = p_pid
                   and (not p_active or h.left_at is null))
$$;

-- Serveurs de la vidéo : STUN + relais TURN avec un identifiant valable
-- 24 h (schéma « TURN REST » : user = expiration:joueur, mot de passe =
-- base64(HMAC-SHA1(clé, user))).
create or replace function public.gb__on_ice(p_pid bigint) returns jsonb
 language plpgsql stable
 set search_path to 'public'
as $$
declare
  v_ice  jsonb := coalesce((select value from gb_config where key = 'ice'), '[]'::jsonb);
  v_turn jsonb := (select value from gb_config where key = 'turn');
  v_user text;
begin
  if v_turn is null or coalesce(v_turn->>'secret', '') = '' or jsonb_typeof(v_turn->'urls') <> 'array' then
    return v_ice;
  end if;
  v_user := (floor(extract(epoch from now()))::bigint + coalesce((v_turn->>'ttl')::int, 86400)) || ':' || p_pid;
  return v_ice || jsonb_build_array(jsonb_build_object(
    'urls', v_turn->'urls',
    'username', v_user,
    'credential', encode(extensions.hmac(v_user, v_turn->>'secret', 'sha1'), 'base64')));
end $$;

-- Liste de joueurs d'une maison : 1 à 4 {id, name}, ids = comptes ou invités.
create or replace function public.gb__lb_players_ok(p jsonb) returns boolean
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_typeof(p) = 'array'
     and jsonb_array_length(p) between 1 and 4
     and octet_length(p::text) <= 4096
     and not exists (
       select 1 from jsonb_array_elements(p) e
        where jsonb_typeof(e) <> 'object'
           or coalesce(e->>'id', '') = ''
           or length(coalesce(e->>'name', '')) not between 1 and 24
           or (e->>'id' not like 'guest-%'
               and not exists (select 1 from gb_players g where g.id::text = e->>'id')))
     and (select count(*) = count(distinct e->>'id') from jsonb_array_elements(p) e)
$$;

-- Retire les maisons qui ne donnent plus signe de vie (salon ouvert),
-- passe la main si l'hôte est parti, ferme le salon vide.
create or replace function public.gb__lb_prune(p_id bigint) returns void
 language plpgsql
 set search_path to 'public'
as $$
declare l gb_on_lobbies; v_next bigint;
begin
  select * into l from gb_on_lobbies where id = p_id for update;
  if l.id is null or l.status <> 'open' then return; end if;
  delete from gb_on_lb_members where lobby_id = p_id and seen_at < now() - interval '45 seconds';
  if not exists (select 1 from gb_on_lb_members where lobby_id = p_id and player_id = l.host_id) then
    select player_id into v_next from gb_on_lb_members where lobby_id = p_id order by joined_at, player_id limit 1;
    if v_next is null then
      update gb_on_lobbies set status = 'closed', updated_at = now() where id = p_id;
    else
      update gb_on_lobbies set host_id = v_next, updated_at = now() where id = p_id;
    end if;
    perform gb__on_notify('l' || p_id);
  end if;
end $$;

-- Quitte tous les salons ouverts (sauf p_keep).
create or replace function public.gb__lb_drop(p_pid bigint, p_keep bigint default null) returns void
 language plpgsql
 set search_path to 'public'
as $$
declare v_id bigint;
begin
  for v_id in select m.lobby_id from gb_on_lb_members m join gb_on_lobbies l on l.id = m.lobby_id
               where m.player_id = p_pid and l.status = 'open' and m.lobby_id is distinct from p_keep
  loop
    delete from gb_on_lb_members where lobby_id = v_id and player_id = p_pid;
    perform gb__lb_prune(v_id);
    perform gb__on_notify('l' || v_id);
  end loop;
end $$;

-- Vue d'un salon pour le joueur p_pid.
create or replace function public.gb__lb_view(p_id bigint, p_pid bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_build_object(
    'id', l.id,
    'host', l.host_id,
    'public', l.public,
    'game', l.game,
    'status', l.status,
    'room', l.room_id,
    'topic', gb__on_topic('l' || l.id),
    'members', coalesce((
      select jsonb_agg(gb__on_player(m.player_id) || jsonb_build_object(
               'players', m.players,
               'age', floor(extract(epoch from now() - m.seen_at))::int)
             order by (m.player_id <> l.host_id), m.joined_at, m.player_id)
        from gb_on_lb_members m where m.lobby_id = l.id), '[]'),
    'invited', coalesce((
      select jsonb_agg(gb__on_player(i.to_id) || jsonb_build_object('status', i.status) order by i.created_at)
        from gb_on_lb_invites i
       where i.lobby_id = l.id
         and not exists (select 1 from gb_on_lb_members m where m.lobby_id = l.id and m.player_id = i.to_id)), '[]'))
  from gb_on_lobbies l where l.id = p_id
$$;

-- Résumé d'un salon (listes) : hôte, nombre de maisons, jeu.
create or replace function public.gb__lb_card(p_id bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_build_object(
    'id', l.id,
    'host', gb__on_player(l.host_id),
    'public', l.public,
    'label', l.game->>'label',
    'homes', (select count(*) from gb_on_lb_members m where m.lobby_id = l.id),
    'players', (select coalesce(sum(jsonb_array_length(m.players)), 0) from gb_on_lb_members m where m.lobby_id = l.id))
  from gb_on_lobbies l where l.id = p_id
$$;

create or replace function public.gb__lb_me(p_id bigint, p_pid bigint) returns gb_on_lobbies
 language plpgsql
 set search_path to 'public'
as $$
declare l gb_on_lobbies;
begin
  select * into l from gb_on_lobbies where id = p_id;
  if l.id is null or l.status = 'closed'
     or not exists (select 1 from gb_on_lb_members where lobby_id = p_id and player_id = p_pid) then
    raise exception 'lb_gone';
  end if;
  return l;
end $$;

-- ─── Salons ────────────────────────────────────────────────────────────────

-- Crée un salon dont je suis l'hôte (je quitte les autres).
create or replace function public.gb_lb_create(p_token text, p_public boolean, p_players jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_id bigint;
begin
  if not gb__lb_players_ok(p_players) then raise exception 'lb_players'; end if;
  perform gb__lb_drop(v_pid);
  insert into gb_on_lobbies (host_id, public) values (v_pid, coalesce(p_public, false)) returning id into v_id;
  insert into gb_on_lb_members (lobby_id, player_id, players) values (v_id, v_pid, p_players);
  return gb__lb_view(v_id, v_pid);
end $$;

-- Salons publics ouverts, invitations reçues, mon salon.
create or replace function public.gb_lb_list(p_token text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  update gb_on_lobbies set status = 'closed'
   where status <> 'closed' and updated_at < now() - interval '1 day';
  delete from gb_on_lobbies where status = 'closed' and updated_at < now() - interval '1 day';
  return jsonb_build_object(
    'public', coalesce((
      select jsonb_agg(gb__lb_card(l.id) order by l.created_at desc)
        from gb_on_lobbies l
       where l.status = 'open' and l.public
         and not gb__blocked(l.host_id, v_pid)
         and not exists (select 1 from gb_on_lb_members m where m.lobby_id = l.id and m.player_id = v_pid)
         and exists (select 1 from gb_on_lb_members m where m.lobby_id = l.id and m.seen_at > now() - interval '45 seconds')
         and (select count(*) from gb_on_lb_members m where m.lobby_id = l.id) < 4), '[]'),
    'invites', coalesce((
      select jsonb_agg(gb__lb_card(i.lobby_id) || jsonb_build_object('from', gb__on_player(i.from_id))
                       order by i.created_at desc)
        from gb_on_lb_invites i join gb_on_lobbies l on l.id = i.lobby_id
       where i.to_id = v_pid and i.status = 'pending' and l.status = 'open'
         and i.created_at > now() - interval '10 minutes'), '[]'),
    'mine', (select m.lobby_id from gb_on_lb_members m join gb_on_lobbies l on l.id = m.lobby_id
              where m.player_id = v_pid and l.status <> 'closed' order by m.joined_at desc limit 1));
end $$;

-- Relit le salon (et dit que je suis là).
create or replace function public.gb_lb_get(p_token text, p_id bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  update gb_on_lb_members set seen_at = now() where lobby_id = p_id and player_id = v_pid;
  perform gb__lb_prune(p_id);
  perform gb__lb_me(p_id, v_pid);
  return gb__lb_view(p_id, v_pid);
end $$;

-- Rejoint un salon public, ou un salon où je suis invité.
create or replace function public.gb_lb_join(p_token text, p_id bigint, p_players jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); l gb_on_lobbies;
begin
  if not gb__lb_players_ok(p_players) then raise exception 'lb_players'; end if;
  perform gb__lb_prune(p_id);
  select * into l from gb_on_lobbies where id = p_id for update;
  if l.id is null or l.status <> 'open' then raise exception 'lb_gone'; end if;
  if exists (select 1 from gb_on_lb_members where lobby_id = p_id and player_id = v_pid) then
    update gb_on_lb_members set players = p_players, seen_at = now() where lobby_id = p_id and player_id = v_pid;
  else
    if not l.public and not exists (select 1 from gb_on_lb_invites
                                     where lobby_id = p_id and to_id = v_pid and status = 'pending') then
      raise exception 'lb_private';
    end if;
    if gb__blocked(l.host_id, v_pid) then raise exception 'on_blocked'; end if;
    if (select count(*) from gb_on_lb_members where lobby_id = p_id) >= 4 then
      raise exception 'lb_full';
    end if;
    perform gb__lb_drop(v_pid, p_id);
    insert into gb_on_lb_members (lobby_id, player_id, players) values (p_id, v_pid, p_players);
  end if;
  delete from gb_on_lb_invites where lobby_id = p_id and to_id = v_pid;
  update gb_on_lobbies set updated_at = now() where id = p_id;
  perform gb__on_notify('l' || p_id);
  return gb__lb_view(p_id, v_pid);
end $$;

-- Change les joueurs de ma maison.
create or replace function public.gb_lb_players(p_token text, p_id bigint, p_players jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); l gb_on_lobbies;
begin
  if not gb__lb_players_ok(p_players) then raise exception 'lb_players'; end if;
  l := gb__lb_me(p_id, v_pid);
  if l.status <> 'open' then raise exception 'lb_started'; end if;
  update gb_on_lb_members set players = p_players, seen_at = now() where lobby_id = p_id and player_id = v_pid;
  update gb_on_lobbies set updated_at = now() where id = p_id;
  perform gb__on_notify('l' || p_id);
  return gb__lb_view(p_id, v_pid);
end $$;

-- L'hôte choisit le jeu {kind, settings, label} et l'ouverture (public / privé).
create or replace function public.gb_lb_set(p_token text, p_id bigint, p_game jsonb, p_public boolean)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); l gb_on_lobbies;
begin
  l := gb__lb_me(p_id, v_pid);
  if l.host_id <> v_pid then raise exception 'lb_host'; end if;
  if l.status <> 'open' then raise exception 'lb_started'; end if;
  if p_game is not null and (jsonb_typeof(p_game) <> 'object' or octet_length(p_game::text) > 16384) then
    raise exception 'on_game';
  end if;
  update gb_on_lobbies
     set game = case when p_game is null then game else p_game - 'players' - 'actions' - 'home' end,
         public = coalesce(p_public, public), updated_at = now()
   where id = p_id;
  perform gb__on_notify('l' || p_id);
  return gb__lb_view(p_id, v_pid);
end $$;

-- Invite un joueur dans le salon (n'importe quelle maison du salon).
create or replace function public.gb_lb_invite(p_token text, p_id bigint, p_to bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); l gb_on_lobbies;
begin
  l := gb__lb_me(p_id, v_pid);
  if l.status <> 'open' then raise exception 'lb_started'; end if;
  if p_to = v_pid or not exists (select 1 from gb_players where id = p_to) then raise exception 'on_player'; end if;
  if gb__blocked(v_pid, p_to) or gb__blocked(l.host_id, p_to) then raise exception 'on_blocked'; end if;
  if (select dnd from gb_players where id = p_to) then raise exception 'on_dnd'; end if;
  if (select count(*) from gb_on_lb_members where lobby_id = p_id) >= 4 then raise exception 'lb_full'; end if;
  if exists (select 1 from gb_on_lb_members where lobby_id = p_id and player_id = p_to) then
    return gb__lb_view(p_id, v_pid);
  end if;
  insert into gb_on_lb_invites (lobby_id, to_id, from_id) values (p_id, p_to, v_pid)
  on conflict (lobby_id, to_id) do update set from_id = excluded.from_id, status = 'pending', created_at = now();
  perform gb__on_notify('u' || p_to);
  perform gb__on_notify('l' || p_id);
  return gb__lb_view(p_id, v_pid);
end $$;

-- Refuse une invitation.
create or replace function public.gb_lb_decline(p_token text, p_id bigint)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  update gb_on_lb_invites set status = 'declined' where lobby_id = p_id and to_id = v_pid;
  if found then perform gb__on_notify('l' || p_id); end if;
end $$;

-- L'hôte retire une maison du salon.
create or replace function public.gb_lb_kick(p_token text, p_id bigint, p_player bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); l gb_on_lobbies;
begin
  l := gb__lb_me(p_id, v_pid);
  if l.host_id <> v_pid then raise exception 'lb_host'; end if;
  if l.status <> 'open' then raise exception 'lb_started'; end if;
  if p_player <> v_pid then
    delete from gb_on_lb_members where lobby_id = p_id and player_id = p_player;
    delete from gb_on_lb_invites where lobby_id = p_id and to_id = p_player;
    perform gb__on_notify('u' || p_player);
    perform gb__on_notify('l' || p_id);
  end if;
  return gb__lb_view(p_id, v_pid);
end $$;

-- Quitte le salon (l'hôte passe la main au suivant).
create or replace function public.gb_lb_leave(p_token text, p_id bigint)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); l gb_on_lobbies; v_next bigint;
begin
  select * into l from gb_on_lobbies where id = p_id for update;
  if l.id is null then return; end if;
  delete from gb_on_lb_members where lobby_id = p_id and player_id = v_pid;
  if not found then return; end if;
  if l.host_id = v_pid then
    select player_id into v_next from gb_on_lb_members where lobby_id = p_id order by joined_at, player_id limit 1;
    if v_next is null then
      update gb_on_lobbies set status = 'closed', updated_at = now() where id = p_id;
    else
      update gb_on_lobbies set host_id = v_next, updated_at = now() where id = p_id;
    end if;
  else
    update gb_on_lobbies set updated_at = now() where id = p_id;
  end if;
  perform gb__on_notify('l' || p_id);
end $$;

-- L'hôte lance la partie : p_game = la partie complète (joueurs de toutes
-- les maisons). Le serveur pose « home » (joueur → maison) et crée la salle.
create or replace function public.gb_lb_start(p_token text, p_id bigint, p_game jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  l gb_on_lobbies;
  v_homes jsonb := '{}'::jsonb;
  v_ids text[] := '{}';
  v_game jsonb;
  v_room bigint;
  v_b bigint;
  m record;
  e jsonb;
  i int := 0;
begin
  perform gb__lb_prune(p_id);
  select * into l from gb_on_lobbies where id = p_id for update;
  if l.id is null or l.status <> 'open'
     or not exists (select 1 from gb_on_lb_members where lobby_id = p_id and player_id = v_pid) then
    raise exception 'lb_gone';
  end if;
  if l.host_id <> v_pid then raise exception 'lb_host'; end if;
  if (select count(*) from gb_on_lb_members where lobby_id = p_id) < 2 then raise exception 'lb_alone'; end if;
  if p_game is null or jsonb_typeof(p_game) <> 'object' or octet_length(p_game::text) > 65536
     or jsonb_typeof(p_game->'players') <> 'array' or not gb__on_players_ok(p_game) then
    raise exception 'on_game';
  end if;
  -- Maisons dans l'ordre : hôte (h1), puis ordre d'arrivée
  for m in select * from gb_on_lb_members where lobby_id = p_id
            order by (player_id <> l.host_id), joined_at, player_id loop
    i := i + 1;
    if m.player_id <> l.host_id and v_b is null then v_b := m.player_id; end if;
    for e in select * from jsonb_array_elements(m.players) loop
      v_homes := v_homes || jsonb_build_object(e->>'id', 'h' || i);
      v_ids := v_ids || (e->>'id');
    end loop;
  end loop;
  -- Les joueurs de la partie sont exactement ceux des maisons
  if (select count(*) from jsonb_array_elements(p_game->'players')) <> cardinality(v_ids)
     or exists (select 1 from jsonb_array_elements(p_game->'players') x where not (x->>'id' = any (v_ids))) then
    raise exception 'lb_players';
  end if;
  v_game := (p_game - 'home' - 'double') || jsonb_build_object('actions', '[]'::jsonb, 'home', v_homes, 'salon', p_id);
  insert into gb_on_rooms (a_id, b_id, game) values (l.host_id, v_b, v_game) returning id into v_room;
  i := 0;
  for m in select * from gb_on_lb_members where lobby_id = p_id
            order by (player_id <> l.host_id), joined_at, player_id loop
    i := i + 1;
    insert into gb_on_homes (room_id, player_id, home) values (v_room, m.player_id, 'h' || i);
    insert into gb_online (player_id, seen_at, busy) values (m.player_id, now(), true)
    on conflict (player_id) do update set busy = true;
    perform gb__on_notify('u' || m.player_id);
  end loop;
  update gb_on_lobbies set status = 'started', room_id = v_room, updated_at = now() where id = p_id;
  delete from gb_on_lb_invites where lobby_id = p_id;
  perform gb__on_notify('l' || p_id);
  return jsonb_build_object('room', v_room);
end $$;

-- Retour au salon après la partie (n'importe quelle maison) : le salon
-- se rouvre avec les mêmes maisons.
create or replace function public.gb_lb_back(p_token text, p_id bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); l gb_on_lobbies;
begin
  l := gb__lb_me(p_id, v_pid);
  update gb_on_lb_members set seen_at = now() where lobby_id = p_id and player_id = v_pid;
  if l.status = 'started' then
    update gb_on_lobbies set status = 'open', room_id = null, updated_at = now() where id = p_id;
    -- Chacun a 45 s pour revenir
    update gb_on_lb_members set seen_at = now() where lobby_id = p_id;
    perform gb__on_notify('l' || p_id);
  end if;
  return gb__lb_view(p_id, v_pid);
end $$;

-- ─── Salle de partie : maisons d'un salon ──────────────────────────────────

-- État de la salle : {seq, [game], signals, peer_age, left, topic, side, peer, ice}
-- Salon : side = ma maison (h1…), homes = [{home, player, age, left}],
-- chaque message vidéo porte la maison qui l'envoie (« from »).
create or replace function public.gb_on_get(p_token text, p_room bigint, p_since bigint default 0, p_sig bigint default 0)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  r gb_on_rooms;
  v_a boolean;
  h gb_on_homes;
  v_peer bigint;
  v_age int;
begin
  select * into r from gb_on_rooms where id = p_room;
  if r.id is null or not gb__on_member(p_room, v_pid) then
    return jsonb_build_object('error', 'on_room');
  end if;
  if r.left_by is null then
    insert into gb_online (player_id, seen_at, busy) values (v_pid, now(), true)
    on conflict (player_id) do update set seen_at = now(), busy = true;
  end if;
  select * into h from gb_on_homes where room_id = r.id and player_id = v_pid;
  if h.room_id is not null then
    update gb_on_homes set seen_at = now() where room_id = r.id and player_id = v_pid;
    select o.player_id, floor(extract(epoch from now() - o.seen_at))::int into v_peer, v_age
      from gb_on_homes o where o.room_id = r.id and o.player_id <> v_pid and o.left_at is null
     order by o.seen_at desc limit 1;
    return jsonb_build_object(
      'seq', r.seq,
      'side', h.home,
      'peer', gb__on_player(coalesce(v_peer, case when r.a_id = v_pid then r.b_id else r.a_id end)),
      'peer_age', coalesce(v_age, 0),
      'left', r.left_by is not null,
      'topic', gb__on_topic('r' || r.id),
      'ice', gb__on_ice(v_pid),
      'homes', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'home', o.home, 'player', gb__on_player(o.player_id),
                 'age', floor(extract(epoch from now() - o.seen_at))::int,
                 'left', o.left_at is not null) order by o.home)
          from gb_on_homes o where o.room_id = r.id), '[]'),
      'signals', coalesce((
        select jsonb_agg(jsonb_build_object('id', s.id, 'data', s.data,
                 'from', (select o.home from gb_on_homes o where o.room_id = r.id and o.player_id = s.from_id))
               order by s.id)
          from gb_on_signals s
         where s.room_id = r.id and s.from_id <> v_pid and s.id > coalesce(p_sig, 0)), '[]'))
      || case when r.seq > coalesce(p_since, 0) then jsonb_build_object('game', r.game) else '{}'::jsonb end;
  end if;
  v_a := r.a_id = v_pid;
  if v_a then
    update gb_on_rooms set a_seen = now() where id = r.id;
  else
    update gb_on_rooms set b_seen = now() where id = r.id;
  end if;
  return jsonb_build_object(
    'seq', r.seq,
    'side', case when v_a then 'a' else 'b' end,
    'peer', gb__on_player(case when v_a then r.b_id else r.a_id end),
    'peer_age', floor(extract(epoch from now() - case when v_a then r.b_seen else r.a_seen end))::int,
    'left', r.left_by is not null,
    'topic', gb__on_topic('r' || r.id),
    'ice', gb__on_ice(v_pid),
    'signals', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'data', s.data) order by s.id)
        from gb_on_signals s
       where s.room_id = r.id and s.from_id <> v_pid and s.id > coalesce(p_sig, 0)), '[]'))
    || case when r.seq > coalesce(p_since, 0) then jsonb_build_object('game', r.game) else '{}'::jsonb end;
end $$;

create or replace function public.gb_on_push(p_token text, p_room bigint, p_seq bigint, p_game jsonb)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pid bigint := gb__auth(p_token);
  r gb_on_rooms;
begin
  select * into r from gb_on_rooms where id = p_room for update;
  if r.id is null or r.left_by is not null or not gb__on_member(p_room, v_pid, true) then
    return jsonb_build_object('error', 'on_room');
  end if;
  if octet_length(p_game::text) > 131072 then
    raise exception 'too_big';
  end if;
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

create or replace function public.gb_on_signal(p_token text, p_room bigint, p_data jsonb)
 returns bigint
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_id bigint;
begin
  if not gb__on_member(p_room, v_pid, true) then
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

-- Quitte la partie. Salon : ma maison s'en va, la partie continue tant
-- qu'il reste au moins 2 maisons.
create or replace function public.gb_on_leave(p_token text, p_room bigint)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_id bigint;
begin
  if exists (select 1 from gb_on_homes where room_id = p_room and player_id = v_pid) then
    update gb_on_homes set left_at = coalesce(left_at, now()) where room_id = p_room and player_id = v_pid;
    if (select count(*) from gb_on_homes where room_id = p_room and left_at is null) < 2 then
      update gb_on_rooms set left_by = coalesce(left_by, v_pid), updated_at = now() where id = p_room;
    else
      update gb_on_rooms set updated_at = now() where id = p_room;
    end if;
    v_id := p_room;
  else
    update gb_on_rooms set left_by = coalesce(left_by, v_pid), updated_at = now()
     where id = p_room and (a_id = v_pid or b_id = v_pid)
    returning id into v_id;
  end if;
  update gb_online set busy = false where player_id = v_pid;
  if v_id is not null then
    perform gb__on_notify('r' || v_id);
  end if;
end $$;

create or replace function public.gb_on_link(p_token text, p_cid text, p_link text)
 returns boolean
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_room bigint;
begin
  if p_link is null or p_link !~ '^[0-9]{1,18}:[0-9]{1,3}$' then return false; end if;
  v_room := split_part(p_link, ':', 1)::bigint;
  if not gb__on_member(v_room, v_pid) then
    return false;
  end if;
  update gb_games g set link = p_link
   where g.client_id = p_cid and g.link is null
     and exists (select 1 from gb_game_players gp where gp.game_id = g.id and gp.player_id = v_pid);
  return found;
end $$;

-- Bilan entre 2 joueurs : seulement les parties 1 contre 1.
create or replace function public.gb_on_result(p_token text, p_room bigint, p_won boolean)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); r gb_on_rooms; v_win bigint; v_a bigint; v_b bigint;
begin
  update gb_on_rooms set counted = true
   where id = p_room and v_pid in (a_id, b_id) and not counted
     and not exists (select 1 from gb_on_homes h where h.room_id = p_room)
  returning * into r;
  if not found or p_won is null then return; end if;
  v_win := case when p_won then v_pid
                when r.a_id = v_pid then r.b_id else r.a_id end;
  v_a := least(r.a_id, r.b_id); v_b := greatest(r.a_id, r.b_id);
  insert into gb_h2h (a_id, b_id, a_wins, b_wins)
  values (v_a, v_b, (v_win = v_a)::int, (v_win = v_b)::int)
  on conflict (a_id, b_id) do update
     set a_wins = gb_h2h.a_wins + excluded.a_wins,
         b_wins = gb_h2h.b_wins + excluded.b_wins;
end $$;

-- Regarder la partie d'un ami (aussi dans un salon).
create or replace function public.gb_on_watch(p_token text, p_player bigint)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); r gb_on_rooms;
begin
  if not exists (select 1 from gb_friends where status = 'ok'
                  and ((a_id = v_pid and b_id = p_player) or (a_id = p_player and b_id = v_pid))) then
    raise exception 'on_player';
  end if;
  select * into r from gb_on_rooms r
   where (p_player in (r.a_id, r.b_id)
          or exists (select 1 from gb_on_homes h where h.room_id = r.id and h.player_id = p_player and h.left_at is null))
     and r.left_by is null
     and r.updated_at > now() - interval '3 minutes'
   order by r.id desc limit 1;
  if not found then return jsonb_build_object('error', 'on_gone'); end if;
  return jsonb_build_object('room', r.id, 'seq', r.seq, 'game', r.game);
end $$;

-- ─── gb_on_ping et gb_on_people : salons en plus ───────────────────────────
-- (texte de la version en place remplacé, relançable)
do $$
declare v_src text; v_new text;
begin
  -- Partie à reprendre : aussi une maison d'un salon
  v_src := pg_get_functiondef('public.gb_on_ping(text, boolean)'::regprocedure);
  if position('gb_on_homes' in v_src) = 0 then
    v_new := replace(v_src,
      'where (a_id = v_pid or b_id = v_pid) and left_by is null',
      'where (((a_id = v_pid or b_id = v_pid) and not exists (select 1 from gb_on_homes h where h.room_id = gb_on_rooms.id))'
      || ' or exists (select 1 from gb_on_homes h where h.room_id = gb_on_rooms.id and h.player_id = v_pid and h.left_at is null))'
      || ' and left_by is null');
    v_new := replace(v_new,
      '''title'', gb__title(v_pid));',
      '''title'', gb__title(v_pid),'
      || E'\n    ''lobby_invites'', coalesce((select jsonb_agg(gb__lb_card(i.lobby_id) || jsonb_build_object(''from'', gb__on_player(i.from_id)) order by i.created_at desc)'
      || E'\n        from gb_on_lb_invites i join gb_on_lobbies l on l.id = i.lobby_id'
      || E'\n       where i.to_id = v_pid and i.status = ''pending'' and l.status = ''open'' and i.created_at > now() - interval ''10 minutes''), ''[]''),'
      || E'\n    ''lobby'', (select m.lobby_id from gb_on_lb_members m join gb_on_lobbies l on l.id = m.lobby_id'
      || E'\n                where m.player_id = v_pid and l.status <> ''closed'' order by m.joined_at desc limit 1));');
    if v_new = v_src or position('gb_on_homes' in v_new) = 0 or position('lobby_invites' in v_new) = 0 then
      raise exception 'gb_on_ping : texte attendu introuvable';
    end if;
    execute v_new;
  end if;

  -- Ami en partie (« regarder ») : aussi dans un salon
  v_src := pg_get_functiondef('public.gb_on_people(text)'::regprocedure);
  if position('gb_on_homes' in v_src) = 0 then
    v_new := replace(v_src,
      'where p.id in (r.a_id, r.b_id) and r.left_by is null',
      'where (p.id in (r.a_id, r.b_id) or exists (select 1 from gb_on_homes h where h.room_id = r.id and h.player_id = p.id and h.left_at is null)) and r.left_by is null');
    if v_new = v_src then
      raise exception 'gb_on_people : texte attendu introuvable';
    end if;
    execute v_new;
  end if;
end $$;

-- ─── Propriétaire et droits ────────────────────────────────────────────────
do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and (p.proname like 'gb\_on\_%' or p.proname like 'gb\_\_on\_%'
            or p.proname like 'gb\_lb\_%' or p.proname like 'gb\_\_lb\_%')
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

-- Contrôle : 4 tables, 12 fonctions de salon, relais TURN posé ?
select
  (select count(*) from pg_tables where schemaname = 'public'
    and tablename in ('gb_on_homes', 'gb_on_lobbies', 'gb_on_lb_members', 'gb_on_lb_invites')) as tables,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'gb\_lb\_%') as rpc,
  exists (select 1 from gb_config where key = 'turn') as turn;
