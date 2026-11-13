-- Foclaboard : cible choisie par chaque joueur (style de la cible dessinée,
-- affichée pendant son tour), gardée avec sa photo et son son dans gb_media
-- pour le suivre sur tous les téléphones, la TV et en ligne.
-- Relançable. À lancer en postgres APRÈS 2026-11-11_photo_son.sql :
--   psql -U postgres -d postgres -f 2026-11-13_cible.sql

begin;

alter table public.gb_media add column if not exists board text not null default '';

-- Cible du joueur : '' = style par défaut du téléphone, sinon id d'un style
create or replace function public.gb_set_board(p_token text, p_board text)
 returns int
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_v int; v_b text := coalesce(p_board, '');
begin
  if v_b !~ '^[a-z0-9_]{0,24}$' then
    raise exception 'board';
  end if;
  insert into gb_media (player_id, board) values (v_pid, v_b)
  on conflict (player_id) do update
     set board = excluded.board, v = gb_media.v + 1, updated_at = now()
  returning v into v_v;
  return v_v;
end $$;

-- Médias de plusieurs joueurs : + board
create or replace function public.gb_media(p_ids bigint[], p_known jsonb default '{}')
 returns jsonb
 language sql stable security definer
 set search_path to 'public'
as $$
  select coalesce(jsonb_object_agg(p.id::text,
           case when coalesce(m.v, 0) = coalesce((p_known->>(p.id::text))::int, -1)
                then jsonb_build_object('v', coalesce(m.v, 0))
                else jsonb_build_object('v', coalesce(m.v, 0), 'photo', m.photo,
                                        'sound', coalesce(m.sound, ''),
                                        'voice', case when m.sound = 'voice' then m.voice end,
                                        'board', coalesce(m.board, ''))
           end), '{}'::jsonb)
    from gb_players p left join gb_media m on m.player_id = p.id
   where p.id = any (p_ids[1:32])
$$;

alter function public.gb_set_board(text, text) owner to rc_owner;
alter function public.gb_media(bigint[], jsonb) owner to rc_owner;
grant execute on function public.gb_set_board(text, text) to anon;
grant execute on function public.gb_media(bigint[], jsonb) to anon;

commit;

notify pgrst, 'reload schema';
