-- Foclaboard : En ligne, la suite — dernière connexion, « veut jouer »
-- (défi laissé à un joueur absent), bilan contre un ami, joueurs bloqués,
-- « ne pas déranger », regarder la partie d'un ami, rendez-vous, phrase du
-- profil et titre, amis dans les classements.
-- Relançable. À lancer en postgres APRÈS 2026-11-15_amis.sql :
--   psql -U postgres -d postgres -f 2026-11-15_social.sql

begin;

alter table public.gb_players add column if not exists dnd   boolean not null default false;
alter table public.gb_players add column if not exists motto text    not null default '';
alter table public.gb_on_rooms add column if not exists counted boolean not null default false;

-- a_id a bloqué b_id
create table if not exists public.gb_blocks (
  a_id bigint not null references public.gb_players(id) on delete cascade,
  b_id bigint not null references public.gb_players(id) on delete cascade,
  primary key (a_id, b_id)
);
-- from_id veut jouer avec to_id (vu par to_id à sa prochaine connexion)
create table if not exists public.gb_on_wants (
  from_id    bigint not null references public.gb_players(id) on delete cascade,
  to_id      bigint not null references public.gb_players(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_id, to_id)
);
-- Parties en ligne gagnées de chaque côté (a_id < b_id)
create table if not exists public.gb_h2h (
  a_id   bigint not null references public.gb_players(id) on delete cascade,
  b_id   bigint not null references public.gb_players(id) on delete cascade,
  a_wins int not null default 0,
  b_wins int not null default 0,
  primary key (a_id, b_id)
);
-- Rendez-vous pour jouer
create table if not exists public.gb_on_dates (
  id         bigserial primary key,
  from_id    bigint not null references public.gb_players(id) on delete cascade,
  to_id      bigint not null references public.gb_players(id) on delete cascade,
  at         timestamptz not null,
  status     text not null default 'pending' check (status in ('pending', 'ok')),
  created_at timestamptz not null default now()
);
alter table public.gb_blocks   owner to rc_owner;
alter table public.gb_on_wants owner to rc_owner;
alter table public.gb_h2h      owner to rc_owner;
alter table public.gb_on_dates owner to rc_owner;
revoke all on public.gb_blocks, public.gb_on_wants, public.gb_h2h, public.gb_on_dates
  from anon, authenticated;

-- L'un des deux a bloqué l'autre ?
create or replace function public.gb__blocked(p_a bigint, p_b bigint) returns boolean
 language sql stable
 set search_path to 'public'
as $$ select exists (select 1 from gb_blocks
                      where (a_id = p_a and b_id = p_b) or (a_id = p_b and b_id = p_a)) $$;

-- Titre d'un joueur d'après ses exploits ('' si aucun)
create or replace function public.gb__title(p_pid bigint) returns text
 language sql stable
 set search_path to 'public'
as $$
  select case
           when s.n180 >= 10 then 'Roi du 180'
           when s.best_co >= 150 then 'Finisseur de légende'
           when s.wins >= 100 then 'Centurion'
           when s.n180 >= 1 then 'Monsieur 180'
           when s.best_co >= 100 then 'Grand finisseur'
           when s.wins >= 25 then 'Habitué du podium'
           when s.games >= 50 then 'Pilier de comptoir'
           when s.wins >= 5 then 'Gagneur'
           when s.games >= 10 then 'Lanceur régulier'
           else '' end
    from (select coalesce(sum(gp.n180), 0) as n180,
                 coalesce(max(gp.checkout), 0) as best_co,
                 count(*) filter (where gp.won) as wins,
                 count(*) as games
            from gb_game_players gp where gp.player_id = p_pid) s
$$;

-- Bilan de p_me contre p_other : parties à la maison (même partie, un seul
-- des deux gagne) + parties en ligne
create or replace function public.gb__h2h(p_me bigint, p_other bigint) returns jsonb
 language sql stable
 set search_path to 'public'
as $$
  select jsonb_build_object(
    'w', l.w + coalesce((select case when h.a_id = p_me then h.a_wins else h.b_wins end
                           from gb_h2h h where h.a_id = least(p_me, p_other)
                                           and h.b_id = greatest(p_me, p_other)), 0),
    'l', l.l + coalesce((select case when h.a_id = p_me then h.b_wins else h.a_wins end
                           from gb_h2h h where h.a_id = least(p_me, p_other)
                                           and h.b_id = greatest(p_me, p_other)), 0))
    from (select count(*) filter (where m.won and not o.won) as w,
                 count(*) filter (where o.won and not m.won) as l
            from gb_game_players m
            join gb_game_players o on o.game_id = m.game_id and o.player_id = p_other
           where m.player_id = p_me) l
$$;

-- Défi refusé si l'un a bloqué l'autre ou si le joueur ne veut pas être
-- dérangé (pas pour un match de tournoi) ; le « veut jouer » est soldé
create or replace function public.gb__on_invite_check() returns trigger
 language plpgsql
 set search_path to 'public'
as $$
begin
  if not (new.game ? 'tn') then
    if gb__blocked(new.from_id, new.to_id) then raise exception 'on_blocked'; end if;
    if (select dnd from gb_players where id = new.to_id) then raise exception 'on_dnd'; end if;
  end if;
  delete from gb_on_wants
   where (from_id = new.from_id and to_id = new.to_id)
      or (from_id = new.to_id and to_id = new.from_id);
  return new;
end $$;
drop trigger if exists gb_on_invite_check on public.gb_on_invites;
create trigger gb_on_invite_check before insert on public.gb_on_invites
  for each row execute function public.gb__on_invite_check();

-- Tous les joueurs du serveur sauf moi (300 au plus) :
-- [{id, pseudo, color, rating, state: free | busy | off, dnd, seen, motto, title,
--   friend: '' | sent | ask | ok | blocked, want (il veut jouer), wanted (je lui ai
--   demandé), et pour un ami : w, l (mon bilan), room (partie en ligne à regarder)}]
create or replace function public.gb_on_people(p_token text)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  return coalesce((
    select jsonb_agg(x.j order by x.ord, x.name)
      from (
        select lower(p.pseudo) as name,
               gb__on_player(p.id) || jsonb_build_object(
                 'state', case when o.player_id is null or hid.a_id is not null then 'off'
                               when o.busy then 'busy' else 'free' end,
                 'dnd', p.dnd,
                 'seen', p.seen_at,
                 'motto', p.motto,
                 'title', gb__title(p.id),
                 'friend', case when blk.a_id is not null then 'blocked'
                                when f.status = 'ok' then 'ok'
                                when f.a_id = v_pid then 'sent'
                                when f.b_id = v_pid then 'ask' else '' end,
                 'want', exists (select 1 from gb_on_wants w where w.from_id = p.id and w.to_id = v_pid),
                 'wanted', exists (select 1 from gb_on_wants w where w.from_id = v_pid and w.to_id = p.id))
               || case when f.status = 'ok' then
                    gb__h2h(v_pid, p.id) || jsonb_build_object('room', exists (
                      select 1 from gb_on_rooms r
                       where p.id in (r.a_id, r.b_id) and r.left_by is null
                         and r.updated_at > now() - interval '3 minutes'))
                  else '{}'::jsonb end as j,
               case when f.status = 'pending' and f.b_id = v_pid then 0
                    when blk.a_id is not null then 5
                    when o.player_id is not null and hid.a_id is null and not o.busy then 1
                    when o.player_id is not null and hid.a_id is null then 2
                    when f.status = 'ok' then 3 else 4 end as ord
          from gb_players p
          left join gb_online o on o.player_id = p.id
                               and o.seen_at > now() - interval '40 seconds'
          left join gb_friends f on (f.a_id = v_pid and f.b_id = p.id)
                                 or (f.b_id = v_pid and f.a_id = p.id)
          left join gb_blocks blk on blk.a_id = v_pid and blk.b_id = p.id  -- je l'ai bloqué
          left join gb_blocks hid on hid.a_id = p.id and hid.b_id = v_pid  -- il m'a bloqué
         where p.id <> v_pid
         order by ord, name
         limit 300) x), '[]');
end $$;

-- Demande en ami : refusée si l'un a bloqué l'autre
create or replace function public.gb_friend_ask(p_token text, p_to bigint)
 returns text
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); f gb_friends;
begin
  if p_to is null or p_to = v_pid
     or not exists (select 1 from gb_players where id = p_to) then
    raise exception 'on_player';
  end if;
  if gb__blocked(v_pid, p_to) then raise exception 'on_blocked'; end if;
  select * into f from gb_friends
   where (a_id = v_pid and b_id = p_to) or (a_id = p_to and b_id = v_pid);
  if not found then
    if (select count(*) from gb_friends where a_id = v_pid and status = 'pending') >= 100 then
      raise exception 'friend_many';
    end if;
    insert into gb_friends (a_id, b_id) values (v_pid, p_to);
    perform gb__on_notify('u' || p_to);
    return 'sent';
  end if;
  if f.status = 'pending' and f.a_id = p_to then
    update gb_friends set status = 'ok' where a_id = p_to and b_id = v_pid;
    perform gb__on_notify('u' || p_to);
    return 'ok';
  end if;
  return case when f.status = 'ok' then 'ok' else 'sent' end;
end $$;

-- Mes amis (classements)
create or replace function public.gb_friend_ids(p_token text)
 returns jsonb
 language plpgsql stable security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  return coalesce((
    select jsonb_agg(case when a_id = v_pid then b_id else a_id end)
      from gb_friends where status = 'ok' and v_pid in (a_id, b_id)), '[]');
end $$;

-- Bloque (ou débloque) un joueur : plus d'amitié, de défi ni de rendez-vous
create or replace function public.gb_block(p_token text, p_other bigint, p_on boolean)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  if p_other is null or p_other = v_pid then raise exception 'on_player'; end if;
  if coalesce(p_on, true) then
    insert into gb_blocks (a_id, b_id) values (v_pid, p_other) on conflict do nothing;
    delete from gb_friends  where (a_id = v_pid and b_id = p_other) or (a_id = p_other and b_id = v_pid);
    delete from gb_on_wants where (from_id = v_pid and to_id = p_other) or (from_id = p_other and to_id = v_pid);
    delete from gb_on_dates where (from_id = v_pid and to_id = p_other) or (from_id = p_other and to_id = v_pid);
  else
    delete from gb_blocks where a_id = v_pid and b_id = p_other;
  end if;
  perform gb__on_notify('u' || p_other);
end $$;

-- « Ne pas déranger » : visible en ligne, mais plus de défi
create or replace function public.gb_on_dnd(p_token text, p_on boolean)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  update gb_players set dnd = coalesce(p_on, false) where id = v_pid;
end $$;

-- Phrase du profil (60 caractères)
create or replace function public.gb_set_motto(p_token text, p_motto text)
 returns text
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
        v text := left(btrim(regexp_replace(coalesce(p_motto, ''), '\s+', ' ', 'g')), 60);
begin
  update gb_players set motto = v where id = v_pid;
  return v;
end $$;

-- « Je veux jouer avec toi » laissé à un joueur (ou retiré)
create or replace function public.gb_on_want(p_token text, p_to bigint, p_on boolean default true)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  if p_to is null or p_to = v_pid
     or not exists (select 1 from gb_players where id = p_to) then
    raise exception 'on_player';
  end if;
  if coalesce(p_on, true) then
    if gb__blocked(v_pid, p_to) then raise exception 'on_blocked'; end if;
    if (select count(*) from gb_on_wants where from_id = v_pid) >= 50 then
      raise exception 'friend_many';
    end if;
    insert into gb_on_wants (from_id, to_id) values (v_pid, p_to)
    on conflict (from_id, to_id) do update set created_at = now();
  else
    delete from gb_on_wants
     where (from_id = v_pid and to_id = p_to) or (from_id = p_to and to_id = v_pid);
  end if;
  perform gb__on_notify('u' || p_to);
end $$;

-- Fin d'une partie en ligne : j'ai gagné ou perdu (compté une fois par salle)
create or replace function public.gb_on_result(p_token text, p_room bigint, p_won boolean)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); r gb_on_rooms; v_win bigint; v_a bigint; v_b bigint;
begin
  update gb_on_rooms set counted = true
   where id = p_room and v_pid in (a_id, b_id) and not counted
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

-- Partie en ligne d'un ami, à regarder : {room, seq, game} ou {error: on_gone}
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
  select * into r from gb_on_rooms
   where p_player in (a_id, b_id) and left_by is null
     and updated_at > now() - interval '3 minutes'
   order by id desc limit 1;
  if not found then return jsonb_build_object('error', 'on_gone'); end if;
  return jsonb_build_object('room', r.id, 'seq', r.seq, 'game', r.game);
end $$;

-- Rendez-vous proposé à un joueur → id
create or replace function public.gb_date_set(p_token text, p_to bigint, p_at timestamptz)
 returns bigint
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); v_id bigint;
begin
  if p_to is null or p_to = v_pid
     or not exists (select 1 from gb_players where id = p_to) then
    raise exception 'on_player';
  end if;
  if gb__blocked(v_pid, p_to) then raise exception 'on_blocked'; end if;
  if p_at is null or p_at < now() - interval '5 minutes' or p_at > now() + interval '60 days' then
    raise exception 'date';
  end if;
  if (select count(*) from gb_on_dates where from_id = v_pid) >= 20 then
    raise exception 'friend_many';
  end if;
  insert into gb_on_dates (from_id, to_id, at) values (v_pid, p_to, p_at) returning id into v_id;
  perform gb__on_notify('u' || p_to);
  return v_id;
end $$;

-- Rendez-vous accepté par celui qui l'a reçu, ou retiré par l'un des deux
create or replace function public.gb_date_answer(p_token text, p_id bigint, p_accept boolean)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token); d gb_on_dates;
begin
  select * into d from gb_on_dates where id = p_id and v_pid in (from_id, to_id);
  if not found then return; end if;
  if coalesce(p_accept, false) and d.to_id = v_pid then
    update gb_on_dates set status = 'ok' where id = p_id;
  else
    delete from gb_on_dates where id = p_id;
  end if;
  perform gb__on_notify('u' || case when d.from_id = v_pid then d.to_id else d.from_id end);
end $$;

-- Présence : + dernière connexion gardée, wants, dates, dnd, motto, title
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
  update gb_players set seen_at = now() where id = v_pid;

  -- Ménage
  update gb_on_invites set status = 'expired'
   where status = 'pending' and created_at < now() - interval '45 seconds';
  delete from gb_on_invites where created_at < now() - interval '1 day';
  delete from gb_on_rooms   where updated_at < now() - interval '1 day';
  delete from gb_online     where seen_at    < now() - interval '10 minutes';
  delete from gb_on_wants   where created_at < now() - interval '7 days';
  delete from gb_on_dates   where at         < now() - interval '2 hours';

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
    'room', v_room,
    'asks', coalesce((
      select jsonb_agg(gb__on_player(f.a_id) order by f.created_at)
        from gb_friends f where f.b_id = v_pid and f.status = 'pending'), '[]'),
    'wants', coalesce((
      select jsonb_agg(gb__on_player(w.from_id) order by w.created_at)
        from gb_on_wants w where w.to_id = v_pid), '[]'),
    'dates', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', d.id, 'at', d.at, 'ok', d.status = 'ok', 'mine', d.from_id = v_pid,
               'with', gb__on_player(case when d.from_id = v_pid then d.to_id else d.from_id end))
             order by d.at)
        from gb_on_dates d where v_pid in (d.from_id, d.to_id)), '[]'),
    'dnd', (select dnd from gb_players where id = v_pid),
    'motto', (select motto from gb_players where id = v_pid),
    'title', gb__title(v_pid));
end $$;

alter function public.gb__blocked(bigint, bigint) owner to rc_owner;
alter function public.gb__title(bigint) owner to rc_owner;
alter function public.gb__h2h(bigint, bigint) owner to rc_owner;
alter function public.gb__on_invite_check() owner to rc_owner;
revoke all on function public.gb__blocked(bigint, bigint), public.gb__title(bigint),
  public.gb__h2h(bigint, bigint), public.gb__on_invite_check() from public, anon, authenticated;

do $$
declare f text;
begin
  foreach f in array array[
    'gb_friend_ids(text)', 'gb_block(text, bigint, boolean)', 'gb_on_dnd(text, boolean)',
    'gb_set_motto(text, text)', 'gb_on_want(text, bigint, boolean)',
    'gb_on_result(text, bigint, boolean)', 'gb_on_watch(text, bigint)',
    'gb_date_set(text, bigint, timestamptz)', 'gb_date_answer(text, bigint, boolean)']
  loop
    execute format('alter function public.%s owner to rc_owner', f);
    execute format('grant execute on function public.%s to anon', f);
  end loop;
end $$;

commit;

notify pgrst, 'reload schema';
