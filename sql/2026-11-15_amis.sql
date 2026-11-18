-- Foclaboard : amis et liste de tous les joueurs du serveur (écran En ligne :
-- qui est en ligne, libre ou en partie, demandes d'ami, défi).
-- Relançable. À lancer en postgres APRÈS 2026-11-13_double.sql :
--   psql -U postgres -d postgres -f 2026-11-15_amis.sql

begin;

-- Une ligne par paire : a_id a demandé b_id en ami
create table if not exists public.gb_friends (
  a_id       bigint not null references public.gb_players(id) on delete cascade,
  b_id       bigint not null references public.gb_players(id) on delete cascade,
  status     text not null default 'pending' check (status in ('pending', 'ok')),
  created_at timestamptz not null default now(),
  primary key (a_id, b_id),
  check (a_id <> b_id)
);
create unique index if not exists gb_friends_pair
  on public.gb_friends (least(a_id, b_id), greatest(a_id, b_id));
create index if not exists gb_friends_b on public.gb_friends (b_id);
alter table public.gb_friends owner to rc_owner;
revoke all on public.gb_friends from anon, authenticated;

-- Tous les joueurs du serveur sauf moi (300 au plus) :
-- [{id, pseudo, color, rating, state: free | busy | off, friend: '' | sent | ask | ok}]
-- triés : demandes reçues, en ligne libres, en partie, amis hors ligne, les autres
create or replace function public.gb_on_people(p_token text)
 returns jsonb
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  return coalesce((
    select jsonb_agg(x.j order by x.ord, x.name)
      from (
        select lower(p.pseudo) as name,
               gb__on_player(p.id) || jsonb_build_object(
                 'state', case when o.player_id is null then 'off'
                               when o.busy then 'busy' else 'free' end,
                 'friend', case when f.status = 'ok' then 'ok'
                                when f.a_id = v_pid then 'sent'
                                when f.b_id = v_pid then 'ask' else '' end) as j,
               case when f.status = 'pending' and f.b_id = v_pid then 0
                    when o.player_id is not null and not o.busy then 1
                    when o.player_id is not null then 2
                    when f.status = 'ok' then 3 else 4 end as ord
          from gb_players p
          left join gb_online o on o.player_id = p.id
                               and o.seen_at > now() - interval '40 seconds'
          left join gb_friends f on (f.a_id = v_pid and f.b_id = p.id)
                                 or (f.b_id = v_pid and f.a_id = p.id)
         where p.id <> v_pid
         order by ord, name
         limit 300) x), '[]');
end $$;

-- Demande en ami : 'sent', ou 'ok' si l'autre m'avait déjà demandé
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

-- Réponse à une demande reçue (refus = demande effacée)
create or replace function public.gb_friend_answer(p_token text, p_from bigint, p_accept boolean)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  if coalesce(p_accept, false) then
    update gb_friends set status = 'ok'
     where a_id = p_from and b_id = v_pid and status = 'pending';
  else
    delete from gb_friends where a_id = p_from and b_id = v_pid and status = 'pending';
  end if;
  perform gb__on_notify('u' || p_from);
end $$;

-- Retire un ami, ou annule ma demande
create or replace function public.gb_friend_remove(p_token text, p_other bigint)
 returns void
 language plpgsql security definer
 set search_path to 'public'
as $$
declare v_pid bigint := gb__auth(p_token);
begin
  delete from gb_friends
   where (a_id = v_pid and b_id = p_other) or (a_id = p_other and b_id = v_pid);
  perform gb__on_notify('u' || p_other);
end $$;

-- Présence : + asks (demandes d'ami reçues)
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
    'room', v_room,
    'asks', coalesce((
      select jsonb_agg(gb__on_player(f.a_id) order by f.created_at)
        from gb_friends f where f.b_id = v_pid and f.status = 'pending'), '[]'));
end $$;

alter function public.gb_on_people(text) owner to rc_owner;
alter function public.gb_friend_ask(text, bigint) owner to rc_owner;
alter function public.gb_friend_answer(text, bigint, boolean) owner to rc_owner;
alter function public.gb_friend_remove(text, bigint) owner to rc_owner;
grant execute on function public.gb_on_people(text) to anon;
grant execute on function public.gb_friend_ask(text, bigint) to anon;
grant execute on function public.gb_friend_answer(text, bigint, boolean) to anon;
grant execute on function public.gb_friend_remove(text, bigint) to anon;

commit;

notify pgrst, 'reload schema';
