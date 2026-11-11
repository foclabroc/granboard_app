-- GranBoard : comptes joueurs (pseudo + code PIN), parties, note et classements.
-- Serveur maison (même base que Pixel Trade, tables et fonctions préfixées gb_).
-- Relançable. À lancer en postgres :
--   psql -U postgres -d postgres -f 2026-11-11_comptes_stats.sql

begin;

-- ─── Tables ────────────────────────────────────────────────────────────────

create table if not exists public.gb_players (
  id           bigserial primary key,
  pseudo       text        not null,
  pin_hash     text        not null,
  color        int         not null default 0,
  created_at   timestamptz not null default now(),
  seen_at      timestamptz not null default now(),
  fails        int         not null default 0,
  locked_until timestamptz
);
create unique index if not exists gb_players_pseudo_uk on public.gb_players (lower(pseudo));

-- Sessions : un jeton par téléphone et par joueur (seule l'empreinte est gardée)
create table if not exists public.gb_sessions (
  token_hash text primary key,
  player_id  bigint not null references public.gb_players (id) on delete cascade,
  created_at timestamptz not null default now(),
  used_at    timestamptz not null default now()
);
create index if not exists gb_sessions_player_ix on public.gb_sessions (player_id);

create table if not exists public.gb_games (
  id          bigserial primary key,
  client_id   text unique,            -- identifiant fourni par l'appli (envoi rejoué = ignoré)
  mode        text not null,          -- « 501 », « Freeze 301 »
  start_score int  not null,
  is_freeze   boolean not null default false,
  in_rule     text,
  out_rule    text,
  rounds      int,
  n_players   int not null,
  played_at   timestamptz not null default now()
);

create table if not exists public.gb_game_players (
  game_id   bigint not null references public.gb_games (id) on delete cascade,
  player_id bigint not null references public.gb_players (id) on delete cascade,
  team      int,
  won       boolean not null,
  darts     int not null,
  points    int not null,
  highest   int not null default 0,
  n100      int not null default 0,
  n180      int not null default 0,
  checkout  int,
  remaining int not null default 0,
  primary key (game_id, player_id)
);
create index if not exists gb_game_players_player_ix on public.gb_game_players (player_id);

alter table public.gb_players      owner to rc_owner;
alter table public.gb_sessions     owner to rc_owner;
alter table public.gb_games        owner to rc_owner;
alter table public.gb_game_players owner to rc_owner;
alter sequence public.gb_players_id_seq owner to rc_owner;
alter sequence public.gb_games_id_seq   owner to rc_owner;

-- Aucun droit direct pour l'API
revoke all on public.gb_players, public.gb_sessions, public.gb_games, public.gb_game_players
  from public, anon, authenticated;
revoke all on sequence public.gb_players_id_seq, public.gb_games_id_seq
  from public, anon, authenticated;

-- ─── Fonctions internes (gb__) ─────────────────────────────────────────────

create or replace function public.gb__sha(p text) returns text
 language sql immutable
 set search_path to 'public'
as $$ select encode(extensions.digest(p, 'sha256'), 'hex') $$;

-- Crée une session et renvoie le jeton (en clair, une seule fois)
create or replace function public.gb__session(p_pid bigint) returns text
 language plpgsql
 set search_path to 'public'
as $$
declare v_tok text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  insert into gb_sessions (token_hash, player_id) values (gb__sha(v_tok), p_pid);
  return v_tok;
end $$;

-- Joueur d'un jeton (exception « session » si invalide)
create or replace function public.gb__auth(p_token text) returns bigint
 language plpgsql
 set search_path to 'public'
as $$
declare v_pid bigint;
begin
  update gb_sessions set used_at = now()
   where token_hash = gb__sha(coalesce(p_token, ''))
  returning player_id into v_pid;
  if v_pid is null then
    raise exception 'session';
  end if;
  update gb_players set seen_at = now() where id = v_pid;
  return v_pid;
end $$;

-- Note : moyenne aux 3 fléchettes sur les 20 dernières parties (3 parties minimum)
create or replace function public.gb__rating(p_pid bigint) returns numeric
 language sql stable
 set search_path to 'public'
as $$
  select case when count(*) >= 3 and sum(darts) > 0
              then round(sum(points) * 3.0 / sum(darts), 1) end
    from (select gp.points, gp.darts
            from gb_game_players gp join gb_games g on g.id = gp.game_id
           where gp.player_id = p_pid
           order by g.played_at desc
           limit 20) t
$$;

-- Statistiques cumulées d'un joueur
create or replace function public.gb__stats(p_pid bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_build_object(
           'games',  count(*),
           'wins',   coalesce(sum(won::int), 0),
           'darts',  coalesce(sum(darts), 0),
           'points', coalesce(sum(points), 0),
           'avg',    case when sum(darts) > 0 then round(sum(points) * 3.0 / sum(darts), 1) else 0 end,
           'high',   coalesce(max(highest), 0),
           'n100',   coalesce(sum(n100), 0),
           'n180',   coalesce(sum(n180), 0),
           'best_co', coalesce(max(checkout), 0),
           'rating', gb__rating(p_pid))
    from gb_game_players where player_id = p_pid
$$;

create or replace function public.gb__account(p_pid bigint, p_token text) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_build_object('id', id, 'pseudo', pseudo, 'color', color, 'token', p_token)
    from gb_players where id = p_pid
$$;

-- ─── RPC (appelées par l'appli) ────────────────────────────────────────────

-- Création de compte : pseudo (2 à 16 caractères) + PIN à 4 chiffres
create or replace function public.gb_register(p_pseudo text, p_pin text, p_color int default 0)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_pseudo text := btrim(coalesce(p_pseudo, ''));
  v_pid bigint;
begin
  if char_length(v_pseudo) < 2 or char_length(v_pseudo) > 16 then
    raise exception 'pseudo';
  end if;
  if coalesce(p_pin, '') !~ '^[0-9]{4}$' then
    raise exception 'pin_format';
  end if;
  if exists (select 1 from gb_players where lower(pseudo) = lower(v_pseudo)) then
    raise exception 'taken';
  end if;
  insert into gb_players (pseudo, pin_hash, color)
  values (v_pseudo, extensions.crypt(p_pin, extensions.gen_salt('bf', 8)), greatest(0, coalesce(p_color, 0)))
  returning id into v_pid;
  return gb__account(v_pid, gb__session(v_pid));
end $$;

-- Connexion : 5 erreurs de PIN → bloqué 15 minutes.
-- Les erreurs sont RENVOYÉES ({"error": …}) et non levées : une exception
-- annulerait aussi le compteur d'essais.
create or replace function public.gb_login(p_pseudo text, p_pin text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v gb_players;
begin
  select * into v from gb_players where lower(pseudo) = lower(btrim(coalesce(p_pseudo, '')));
  if v.id is null then
    return jsonb_build_object('error', 'unknown');
  end if;
  if v.locked_until is not null and v.locked_until > now() then
    return jsonb_build_object('error', 'locked',
      'minutes', ceil(extract(epoch from v.locked_until - now()) / 60));
  end if;
  if extensions.crypt(coalesce(p_pin, ''), v.pin_hash) <> v.pin_hash then
    update gb_players
       set fails = fails + 1,
           locked_until = case when fails + 1 >= 5 then now() + interval '15 minutes' end
     where id = v.id;
    return jsonb_build_object('error', 'pin', 'left', greatest(0, 4 - v.fails));
  end if;
  update gb_players set fails = 0, locked_until = null, seen_at = now() where id = v.id;
  return gb__account(v.id, gb__session(v.id));
end $$;

-- Vérifie les comptes mémorisés sur un téléphone : renvoie ceux encore valides
create or replace function public.gb_check(p_tokens text[])
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_out jsonb := '[]'; t text; v_pid bigint;
begin
  foreach t in array coalesce(p_tokens, '{}') loop
    select player_id into v_pid from gb_sessions where token_hash = gb__sha(t);
    if v_pid is not null then
      update gb_sessions set used_at = now() where token_hash = gb__sha(t);
      v_out := v_out || jsonb_build_array(gb__account(v_pid, t));
    end if;
  end loop;
  return v_out;
end $$;

create or replace function public.gb_logout(p_token text)
 returns void
 language sql security definer
 set search_path to 'public'
as $$ delete from gb_sessions where token_hash = gb__sha(coalesce(p_token, '')) $$;

create or replace function public.gb_set_color(p_token text, p_color int)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
begin
  update gb_players set color = greatest(0, coalesce(p_color, 0)) where id = gb__auth(p_token);
end $$;

create or replace function public.gb_set_pin(p_token text, p_old text, p_new text)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_hash text;
begin
  select pin_hash into v_hash from gb_players where id = v_pid;
  if extensions.crypt(coalesce(p_old, ''), v_hash) <> v_hash then
    raise exception 'pin';
  end if;
  if coalesce(p_new, '') !~ '^[0-9]{4}$' then
    raise exception 'pin_format';
  end if;
  update gb_players set pin_hash = extensions.crypt(p_new, extensions.gen_salt('bf', 8)) where id = v_pid;
end $$;

-- Enregistre une partie terminée.
-- p_game : {cid, mode, start, freeze, in, out, rounds, n,
--           players: [{token, team, won, darts, points, highest, n100, n180, checkout, remaining}]}
-- Les invités ne sont pas envoyés. Renvoie l'id de la partie (le même si déjà reçue).
create or replace function public.gb_submit(p_game jsonb)
 returns bigint
 language plpgsql security definer
 set search_path to 'public'
as $$
declare
  v_gid bigint;
  v_pid bigint;
  p jsonb;
  v_seen bigint[] := '{}';
  v_darts int; v_points int;
begin
  if coalesce(p_game->>'cid', '') = '' then
    raise exception 'cid';
  end if;
  select id into v_gid from gb_games where client_id = p_game->>'cid';
  if v_gid is not null then
    return v_gid;
  end if;
  if jsonb_typeof(p_game->'players') <> 'array' or jsonb_array_length(p_game->'players') = 0 then
    raise exception 'players';
  end if;

  insert into gb_games (client_id, mode, start_score, is_freeze, in_rule, out_rule, rounds, n_players)
  values (p_game->>'cid',
          left(coalesce(p_game->>'mode', '?'), 30),
          coalesce((p_game->>'start')::int, 0),
          coalesce((p_game->>'freeze')::boolean, false),
          left(p_game->>'in', 10),
          left(p_game->>'out', 10),
          nullif(p_game->>'rounds', '')::int,
          greatest(1, coalesce((p_game->>'n')::int, 1)))
  returning id into v_gid;

  for p in select * from jsonb_array_elements(p_game->'players') loop
    v_pid := gb__auth(p->>'token');
    if v_pid = any(v_seen) then
      raise exception 'duplicate';
    end if;
    v_seen := v_seen || v_pid;
    v_darts  := coalesce((p->>'darts')::int, 0);
    v_points := coalesce((p->>'points')::int, 0);
    -- Garde-fous (valeurs impossibles = refus)
    if v_darts < 0 or v_darts > 3000 or v_points < 0 or v_points > v_darts * 60
       or coalesce((p->>'highest')::int, 0) > 180
       or coalesce((p->>'n180')::int, 0) * 3 > v_darts
       or coalesce((p->>'checkout')::int, 0) > 180 then
      raise exception 'values';
    end if;
    insert into gb_game_players (game_id, player_id, team, won, darts, points, highest,
                                 n100, n180, checkout, remaining)
    values (v_gid, v_pid,
            nullif(p->>'team', '')::int,
            coalesce((p->>'won')::boolean, false),
            v_darts, v_points,
            coalesce((p->>'highest')::int, 0),
            coalesce((p->>'n100')::int, 0),
            coalesce((p->>'n180')::int, 0),
            nullif(p->>'checkout', '')::int,
            coalesce((p->>'remaining')::int, 0));
  end loop;
  return v_gid;
end $$;

-- Profil public : stats, note, rang au classement, 20 dernières parties
create or replace function public.gb_profile(p_id bigint)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v gb_players; v_stats jsonb; v_rank int;
begin
  select * into v from gb_players where id = p_id;
  if v.id is null then
    raise exception 'unknown';
  end if;
  v_stats := gb__stats(v.id);
  if v_stats->>'rating' is not null then
    select 1 + count(*) into v_rank
      from gb_players o
     where o.id <> v.id and gb__rating(o.id) > (v_stats->>'rating')::numeric;
  end if;
  return jsonb_build_object(
    'id', v.id, 'pseudo', v.pseudo, 'color', v.color, 'since', v.created_at,
    'stats', v_stats, 'rank', v_rank,
    'recent', coalesce((
      select jsonb_agg(r order by r.date desc)
        from (select g.played_at as date, g.mode, gp.won,
                     case when gp.darts > 0 then round(gp.points * 3.0 / gp.darts, 1) else 0 end as avg,
                     gp.checkout, gp.darts
                from gb_game_players gp join gb_games g on g.id = gp.game_id
               where gp.player_id = v.id
               order by g.played_at desc
               limit 20) r), '[]'));
end $$;

-- Classements : rating, wins, avg, n180, checkout, high
create or replace function public.gb_top(p_kind text, p_limit int default 50)
 returns jsonb
 language sql stable security definer
 set search_path to 'public'
as $$
  with s as (
    select p.id, p.pseudo, p.color,
           count(gp.game_id) as games,
           coalesce(sum(gp.won::int), 0) as wins,
           coalesce(sum(gp.darts), 0) as darts,
           coalesce(sum(gp.points), 0) as points,
           coalesce(sum(gp.n180), 0) as n180,
           coalesce(max(gp.checkout), 0) as best_co,
           coalesce(max(gp.highest), 0) as high
      from gb_players p left join gb_game_players gp on gp.player_id = p.id
     group by p.id
  ), v as (
    select id, pseudo, color, games,
           case p_kind
             when 'rating'   then gb__rating(id)
             when 'wins'     then wins::numeric
             when 'avg'      then case when games >= 3 and darts > 0
                                       then round(points * 3.0 / darts, 1) end
             when 'n180'     then n180::numeric
             when 'checkout' then best_co::numeric
             when 'high'     then high::numeric
           end as value
      from s
  )
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'pseudo', pseudo, 'color', color,
                                               'games', games, 'value', value)
                            order by value desc, games desc), '[]')
    from (select * from v where value is not null and value > 0
           order by value desc, games desc
           limit least(greatest(coalesce(p_limit, 50), 1), 100)) t
$$;

-- ─── Propriétaire et droits ────────────────────────────────────────────────

do $$
declare f record;
begin
  for f in
    select p.oid::regprocedure as sig, p.proname
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public' and p.proname like 'gb\_%'
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

-- Contrôle : 4 tables, fonctions ouvertes / fermées
select
  (select count(*) from pg_tables where schemaname = 'public' and tablename like 'gb\_%') as tables_gb,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'gb\_%' and p.proname not like 'gb\_\_%') as rpc_ouvertes,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname like 'gb\_\_%') as fonctions_internes;
