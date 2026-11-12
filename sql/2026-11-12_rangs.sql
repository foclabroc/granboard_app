-- GranBoard : rangs façon GranBoard (C, CC, B, BB, A, AA, S, SS, M, GM) et
-- note sur 20 (« rating »), calculés sur les 30 dernières parties :
--   PPR = points par manche de 3 fléchettes en 01,
--   MPR = marques par manche en Cricket,
--   note 01 et note Cricket lues dans le tableau des rangs (interpolées dans
--   chaque palier), note générale = moyenne des deux (ou la seule connue).
-- « 80 % » = les 80 % meilleures parties parmi les 30 dernières (par défaut,
-- comme GranBoard) ; « 100 % » = toutes.
-- gb__rating renvoie désormais cette note générale : classement « rating »,
-- profil, joueurs en ligne passent au nouveau système sans autre changement.
-- gb_stats(id) : page de stats de n'importe quel joueur.
-- Relançable. À lancer en postgres APRÈS 2026-11-12_en_ligne.sql :
--   psql -U postgres -d postgres -f 2026-11-12_rangs.sql

begin;

-- Note (1 à 20) d'un PPR (p_kind = 'x01') ou d'un MPR (p_kind = 'cricket')
create or replace function public.gb__band(p_v numeric, p_kind text) returns numeric
 language plpgsql immutable
 set search_path to 'public'
as $$
declare
  lo numeric[] := case when p_kind = 'x01'
    then array[0, 35, 40, 45, 51, 57, 63, 69.5, 75.5, 82, 89, 96, 103, 110, 116, 122, 127, 132, 137, 142]
    else array[0, 1.20, 1.40, 1.60, 1.80, 2.00, 2.20, 2.45, 2.70, 3.00, 3.25, 3.50, 3.75, 4.00, 4.25, 4.50, 4.80, 5.10, 5.40, 5.70]
  end;
  i int;
begin
  if p_v is null then return null; end if;
  if p_v >= lo[20] then return 20; end if;
  for i in 1..19 loop
    if p_v < lo[i + 1] then
      return round(i + (greatest(p_v, 0) - lo[i]) / (lo[i + 1] - lo[i]), 2);
    end if;
  end loop;
  return 20;
end $$;

-- PPR (01) ou MPR (Cricket) des 30 dernières parties, en ne gardant que la
-- part p_pct des meilleures (0.8 = 80 %, 1 = toutes)
create or replace function public.gb__perf(p_pid bigint, p_kind text, p_pct numeric) returns numeric
 language sql stable
 set search_path to 'public'
as $$
  with last as (
    select gp.points, gp.marks, gp.darts
      from gb_game_players gp join gb_games g on g.id = gp.game_id
     where gp.player_id = p_pid and g.kind = p_kind and gp.darts > 0
     order by g.played_at desc
     limit 30
  ), ranked as (
    select *, row_number() over (
                order by (case when p_kind = 'x01' then points else marks end)::numeric / darts desc) as rn,
              count(*) over () as n
      from last
  )
  select case when count(*) > 0 and sum(darts) > 0 then
           round((case when p_kind = 'x01' then sum(points) else sum(marks) end) * 3.0 / sum(darts), 2)
         end
    from ranked
   where rn <= greatest(1, ceil(n * p_pct))
$$;

-- Rang complet : PPR, MPR, notes 01 / Cricket / générale, nombre de parties
create or replace function public.gb__grade(p_pid bigint, p_pct numeric) returns jsonb
 language plpgsql stable
 set search_path to 'public'
as $$
declare
  v_ppr numeric := gb__perf(p_pid, 'x01', p_pct);
  v_mpr numeric := gb__perf(p_pid, 'cricket', p_pct);
  r01 numeric := gb__band(v_ppr, 'x01');
  rcr numeric := gb__band(v_mpr, 'cricket');
begin
  return jsonb_build_object(
    'ppr', v_ppr, 'mpr', v_mpr, 'r01', r01, 'rcr', rcr,
    'rating', case when r01 is not null and rcr is not null then round((r01 + rcr) / 2, 2)
                   else coalesce(r01, rcr) end);
end $$;

-- Note générale (80 %) : utilisée partout où « rating » apparaît
create or replace function public.gb__rating(p_pid bigint) returns numeric
 language sql stable
 set search_path to 'public'
as $$
  select (gb__grade(p_pid, 0.8)->>'rating')::numeric
$$;

-- Les 30 dernières parties d'un type, de la plus ancienne à la plus récente
-- (PPR ou MPR de chaque partie) pour la courbe
create or replace function public.gb__series(p_pid bigint, p_kind text) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select coalesce(jsonb_agg(jsonb_build_object('d', date, 'v', v) order by date), '[]')
    from (select g.played_at as date,
                 round((case when p_kind = 'x01' then gp.points else gp.marks end) * 3.0 / gp.darts, 2) as v
            from gb_game_players gp join gb_games g on g.id = gp.game_id
           where gp.player_id = p_pid and g.kind = p_kind and gp.darts > 0
           order by g.played_at desc
           limit 30) t
$$;

-- Entraînement : meilleur score, moyenne et nombre de parties par jeu
create or replace function public.gb__practice(p_pid bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select coalesce(jsonb_object_agg(variant, jsonb_build_object('best', best, 'games', n, 'avg', av)), '{}')
    from (select g.variant, max(gp.points) as best, count(*) as n, round(avg(gp.points), 2) as av
            from gb_game_players gp join gb_games g on g.id = gp.game_id
           where gp.player_id = p_pid and g.kind = 'practice' and g.variant is not null
           group by g.variant) t
$$;

-- Page de stats d'un joueur (n'importe lequel, comme gb_profile)
create or replace function public.gb_stats(p_id bigint)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'public'
as $$
declare v gb_players;
begin
  select * into v from gb_players where id = p_id;
  if v.id is null then
    raise exception 'unknown';
  end if;
  return jsonb_build_object(
    'id', v.id, 'pseudo', v.pseudo, 'color', v.color,
    'g80', gb__grade(v.id, 0.8),
    'g100', gb__grade(v.id, 1),
    's01', gb__series(v.id, 'x01'),
    'scr', gb__series(v.id, 'cricket'),
    'practice', gb__practice(v.id));
end $$;

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
