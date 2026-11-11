-- GranBoard : jeux d'entraînement dans les stats (kind = 'practice',
-- variant = le jeu : countUp, halfIt, bobs27…, points = score du jeu).
-- Classement « meilleur score » par jeu : gb_top('pr:<jeu>').
-- La note, la moyenne 01 et le MPR ne sont pas touchés.
-- Relançable. À lancer en postgres APRÈS 2026-11-11_cricket.sql :
--   psql -U postgres -d postgres -f 2026-11-11_entrainement.sql

begin;

-- Meilleur score de chaque jeu d'entraînement du joueur
create or replace function public.gb__practice(p_pid bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select coalesce(jsonb_object_agg(variant, jsonb_build_object('best', best, 'games', n)), '{}')
    from (select g.variant, max(gp.points) as best, count(*) as n
            from gb_game_players gp join gb_games g on g.id = gp.game_id
           where gp.player_id = p_pid and g.kind = 'practice' and g.variant is not null
           group by g.variant) t
$$;

-- Classement d'un jeu d'entraînement : meilleur score de chaque joueur
create or replace function public.gb__top_practice(p_variant text, p_limit int) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'pseudo', pseudo, 'color', color,
                                               'games', games, 'value', value)
                            order by value desc, games desc), '[]')
    from (select p.id, p.pseudo, p.color, count(*) as games, max(gp.points) as value
            from gb_players p
            join gb_game_players gp on gp.player_id = p.id
            join gb_games g on g.id = gp.game_id
           where g.kind = 'practice' and g.variant = p_variant
           group by p.id
           order by value desc, games desc
           limit least(greatest(coalesce(p_limit, 50), 1), 100)) t
$$;

-- Stats du profil : + entraînement (meilleur score par jeu)
create or replace function public.gb__stats_all(p_pid bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select gb__stats(p_pid) || jsonb_build_object('practice', gb__practice(p_pid))
$$;

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
  if v_kind not in ('x01', 'cricket', 'practice') then
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
    if v_darts < 0 or v_darts > 3000 or v_marks < 0
       or (v_kind <> 'practice' and v_points < 0) then
      raise exception 'values';
    end if;
    -- Entraînement : score du jeu (peut être négatif : Bob's 27, CR Multiple…)
    if v_kind = 'practice' and (v_points < -100000 or v_points > 2000000
         or v_marks > v_darts) then
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
  v_stats := gb__stats_all(v.id);
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
                     gp.checkout, gp.darts, gp.points
                from gb_game_players gp join gb_games g on g.id = gp.game_id
               where gp.player_id = v.id
               order by g.played_at desc
               limit 20) r), '[]'));
end $$;

create or replace function public.gb_top(p_kind text, p_limit int default 50)
 returns jsonb
 language sql stable security definer
 set search_path to 'public'
as $$
  select case when p_kind like 'pr:%' then gb__top_practice(substr(p_kind, 4), p_limit)
  else (
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
  ) end
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

-- Contrôle : 3 nouvelles fonctions internes
select count(*) as fonctions_entrainement
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('gb__practice', 'gb__top_practice', 'gb__stats_all');
