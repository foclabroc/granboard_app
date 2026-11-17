-- Foclaboard : historique des parties d'un joueur (page Stats), avec les
-- autres joueurs de chaque partie (comptes ; les invités ne sont pas
-- envoyés au serveur). Parties en ligne : chaque téléphone envoie la sienne,
-- reliées ensuite par `link` (« <salle>:<leg> ») pour retrouver l'adversaire.
-- Relançable. À lancer en postgres :
--   psql -U postgres -d postgres -f 2026-11-17_historique.sql

begin;

alter table public.gb_games add column if not exists link text;
create index if not exists gb_games_link on public.gb_games (link) where link is not null;

-- Partie en ligne envoyée : la relie à sa salle (et à son leg en Medley).
-- Seulement par un joueur de la partie qui était dans la salle.
create or replace function public.gb_on_link(p_token text, p_cid text, p_link text)
 returns boolean
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_room bigint;
begin
  if p_link is null or p_link !~ '^[0-9]{1,18}:[0-9]{1,3}$' then return false; end if;
  v_room := split_part(p_link, ':', 1)::bigint;
  if not exists (select 1 from gb_on_rooms where id = v_room and v_pid in (a_id, b_id)) then
    return false;
  end if;
  update gb_games g set link = p_link
   where g.client_id = p_cid and g.link is null
     and exists (select 1 from gb_game_players gp where gp.game_id = g.id and gp.player_id = v_pid);
  return found;
end $$;

-- Parties de p_id, les plus récentes d'abord, avant p_before (page
-- suivante), p_limit au plus (50) :
-- [{date, kind, mode, variant, won, avg, mpr, checkout, darts, points,
--   n180, highest, n (joueurs dans la partie), online,
--   with [{id, pseudo, color, won}]}]
create or replace function public.gb_history(p_id bigint, p_before timestamptz default null,
                                             p_limit int default 30)
 returns jsonb
 language sql stable security definer
 set search_path to 'public'
as $$
  select coalesce(jsonb_agg(r.j order by r.date desc), '[]')
    from (
      select g.played_at as date,
             jsonb_build_object(
               'date', g.played_at, 'kind', g.kind, 'mode', g.mode, 'variant', g.variant,
               'won', gp.won,
               'avg', case when gp.darts > 0 then round(gp.points * 3.0 / gp.darts, 1) else 0 end,
               'mpr', case when gp.darts > 0 then round(gp.marks * 3.0 / gp.darts, 2) else 0 end,
               'checkout', gp.checkout, 'darts', gp.darts, 'points', gp.points,
               'n180', gp.n180, 'highest', gp.highest, 'n', g.n_players,
               'online', g.link is not null,
               'with', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'id', o.player_id, 'pseudo', p.pseudo, 'color', p.color, 'won', o.won)
                          order by o.won desc, p.pseudo)
                   from (select distinct on (o.player_id) o.player_id, o.won
                           from gb_game_players o
                           join gb_games og on og.id = o.game_id
                          where o.player_id <> p_id
                            and (og.id = g.id or (g.link is not null and og.link = g.link))
                          order by o.player_id, o.won desc) o
                   join gb_players p on p.id = o.player_id), '[]')) as j
        from gb_game_players gp join gb_games g on g.id = gp.game_id
       where gp.player_id = p_id
         and (p_before is null or g.played_at < p_before)
       order by g.played_at desc
       limit least(greatest(coalesce(p_limit, 30), 1), 50)) r
$$;

alter function public.gb_on_link(text, text, text) owner to rc_owner;
alter function public.gb_history(bigint, timestamptz, int) owner to rc_owner;
grant execute on function public.gb_on_link(text, text, text) to anon;
grant execute on function public.gb_history(bigint, timestamptz, int) to anon;

commit;

notify pgrst, 'reload schema';
