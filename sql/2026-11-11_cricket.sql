-- GranBoard : parties de Cricket (et futurs jeux) dans les stats.
-- Chaque partie a un type (« x01 », « cricket »…). La note, la moyenne, les 180
-- et les fins ne comptent que les parties 01 ; le Cricket a son MPR
-- (marques par manche de 3 fléchettes) et ses classements.
-- Relançable. À lancer en postgres APRÈS 2026-11-11_comptes_stats.sql :
--   psql -U postgres -d postgres -f 2026-11-11_cricket.sql

begin;

alter table public.gb_games        add column if not exists kind    text not null default 'x01';
alter table public.gb_games        add column if not exists variant text;
alter table public.gb_game_players add column if not exists marks   int  not null default 0;
create index if not exists gb_games_kind_ix on public.gb_games (kind);

-- Note (01 seulement) : moyenne aux 3 fléchettes des 20 dernières parties
create or replace function public.gb__rating(p_pid bigint) returns numeric
 language sql stable
 set search_path to 'public'
as $$
  select case when count(*) >= 3 and sum(darts) > 0
              then round(sum(points) * 3.0 / sum(darts), 1) end
    from (select gp.points, gp.darts
            from gb_game_players gp join gb_games g on g.id = gp.game_id
           where gp.player_id = p_pid and g.kind = 'x01'
           order by g.played_at desc
           limit 20) t
$$;

-- MPR Cricket : marques par manche des 20 dernières parties (3 minimum)
create or replace function public.gb__mpr(p_pid bigint) returns numeric
 language sql stable
 set search_path to 'public'
as $$
  select case when count(*) >= 3 and sum(darts) > 0
              then round(sum(marks) * 3.0 / sum(darts), 2) end
    from (select gp.marks, gp.darts
            from gb_game_players gp join gb_games g on g.id = gp.game_id
           where gp.player_id = p_pid and g.kind = 'cricket'
           order by g.played_at desc
           limit 20) t
$$;

-- Statistiques cumulées : 01 (comme avant) + Cricket
create or replace function public.gb__stats(p_pid bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_build_object(
           'games',  count(*) filter (where g.kind = 'x01'),
           'wins',   coalesce(sum(gp.won::int) filter (where g.kind = 'x01'), 0),
           'darts',  coalesce(sum(gp.darts) filter (where g.kind = 'x01'), 0),
           'points', coalesce(sum(gp.points) filter (where g.kind = 'x01'), 0),
           'avg',    case when sum(gp.darts) filter (where g.kind = 'x01') > 0
                          then round(sum(gp.points) filter (where g.kind = 'x01') * 3.0
                                     / sum(gp.darts) filter (where g.kind = 'x01'), 1)
                          else 0 end,
           'high',   coalesce(max(gp.highest) filter (where g.kind = 'x01'), 0),
           'n100',   coalesce(sum(gp.n100) filter (where g.kind = 'x01'), 0),
           'n180',   coalesce(sum(gp.n180) filter (where g.kind = 'x01'), 0),
           'best_co', coalesce(max(gp.checkout) filter (where g.kind = 'x01'), 0),
           'rating', gb__rating(p_pid),
           'cr_games', count(*) filter (where g.kind = 'cricket'),
           'cr_wins',  coalesce(sum(gp.won::int) filter (where g.kind = 'cricket'), 0),
           'cr_marks', coalesce(sum(gp.marks) filter (where g.kind = 'cricket'), 0),
           'cr_best',  coalesce(max(gp.highest) filter (where g.kind = 'cricket'), 0),
           'mpr',      gb__mpr(p_pid),
           'all_games', count(*),
           'all_wins',  coalesce(sum(gp.won::int), 0))
    from gb_game_players gp join gb_games g on g.id = gp.game_id
   where gp.player_id = p_pid
$$;

-- Envoi d'une partie terminée (anti-doublon par cid, invités jamais envoyés)
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
  v_kind text := coalesce(nullif(p_game->>'kind', ''), 'x01');
  v_darts int; v_points int; v_marks int; v_high int;
begin
  if coalesce(p_game->>'cid', '') = '' then
    raise exception 'cid';
  end if;
  if v_kind not in ('x01', 'cricket') then
    raise exception 'kind';
  end if;
  select id into v_gid from gb_games where client_id = p_game->>'cid';
  if v_gid is not null then
    return v_gid;
  end if;
  if jsonb_typeof(p_game->'players') <> 'array' or jsonb_array_length(p_game->'players') = 0 then
    raise exception 'players';
  end if;

  insert into gb_games (client_id, kind, variant, mode, start_score, is_freeze, in_rule, out_rule, rounds, n_players)
  values (p_game->>'cid', v_kind,
          left(p_game->>'variant', 20),
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
    v_marks  := coalesce((p->>'marks')::int, 0);
    v_high   := coalesce((p->>'highest')::int, 0);
    -- Garde-fous (valeurs impossibles = refus)
    if v_darts < 0 or v_darts > 3000 or v_points < 0 or v_marks < 0 then
      raise exception 'values';
    end if;
    if v_kind = 'x01' and (v_points > v_darts * 60 or v_high > 180
         or coalesce((p->>'n180')::int, 0) * 3 > v_darts
         or coalesce((p->>'checkout')::int, 0) > 180) then
      raise exception 'values';
    end if;
    -- Cricket : 3 marques au plus par fléchette, 9 par manche ;
    -- Cut Throat à 8 joueurs : jusqu'à 60 points donnés à 7 adversaires
    if v_kind = 'cricket' and (v_marks > v_darts * 3 or v_high > 9
         or v_points > v_darts * 60 * 7) then
      raise exception 'values';
    end if;
    insert into gb_game_players (game_id, player_id, team, won, darts, points, highest,
                                 n100, n180, checkout, remaining, marks)
    values (v_gid, v_pid,
            nullif(p->>'team', '')::int,
            coalesce((p->>'won')::boolean, false),
            v_darts, v_points, v_high,
            case when v_kind = 'x01' then coalesce((p->>'n100')::int, 0) else 0 end,
            case when v_kind = 'x01' then coalesce((p->>'n180')::int, 0) else 0 end,
            case when v_kind = 'x01' then nullif(p->>'checkout', '')::int end,
            coalesce((p->>'remaining')::int, 0),
            v_marks);
  end loop;
  return v_gid;
end $$;

-- Profil public : stats, note, rang, 20 dernières parties (tous jeux)
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
        from (select g.played_at as date, g.kind, g.mode, gp.won,
                     case when gp.darts > 0 then round(gp.points * 3.0 / gp.darts, 1) else 0 end as avg,
                     case when gp.darts > 0 then round(gp.marks * 3.0 / gp.darts, 2) else 0 end as mpr,
                     gp.checkout, gp.darts
                from gb_game_players gp join gb_games g on g.id = gp.game_id
               where gp.player_id = v.id
               order by g.played_at desc
               limit 20) r), '[]'));
end $$;

-- Classements : rating, wins, avg, n180, checkout, high (01) ; mpr, cr_wins (Cricket)
create or replace function public.gb_top(p_kind text, p_limit int default 50)
 returns jsonb
 language sql stable security definer
 set search_path to 'public'
as $$
  with s as (
    select p.id, p.pseudo, p.color,
           count(gp.game_id) filter (where g.kind = 'x01') as games,
           count(gp.game_id) filter (where g.kind = 'cricket') as cr_games,
           coalesce(sum(gp.won::int) filter (where g.kind = 'x01'), 0) as wins,
           coalesce(sum(gp.won::int) filter (where g.kind = 'cricket'), 0) as cr_wins,
           coalesce(sum(gp.darts) filter (where g.kind = 'x01'), 0) as darts,
           coalesce(sum(gp.points) filter (where g.kind = 'x01'), 0) as points,
           coalesce(sum(gp.n180) filter (where g.kind = 'x01'), 0) as n180,
           coalesce(max(gp.checkout) filter (where g.kind = 'x01'), 0) as best_co,
           coalesce(max(gp.highest) filter (where g.kind = 'x01'), 0) as high
      from gb_players p
      left join gb_game_players gp on gp.player_id = p.id
      left join gb_games g on g.id = gp.game_id
     group by p.id
  ), v as (
    select id, pseudo, color,
           case when p_kind in ('mpr', 'cr_wins') then cr_games else games end as games,
           case p_kind
             when 'rating'   then gb__rating(id)
             when 'wins'     then wins::numeric
             when 'avg'      then case when games >= 3 and darts > 0
                                       then round(points * 3.0 / darts, 1) end
             when 'n180'     then n180::numeric
             when 'checkout' then best_co::numeric
             when 'high'     then high::numeric
             when 'mpr'      then gb__mpr(id)
             when 'cr_wins'  then cr_wins::numeric
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

-- Propriétaire et droits (même règle que les autres fichiers)
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

-- Contrôle : 3 nouvelles colonnes, gb__mpr présente
select
  (select count(*) from information_schema.columns
    where table_schema = 'public'
      and ((table_name = 'gb_games' and column_name in ('kind', 'variant'))
        or (table_name = 'gb_game_players' and column_name = 'marks'))) as colonnes,
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'gb__mpr') as mpr;
