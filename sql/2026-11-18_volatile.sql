-- Foclaboard : fonctions marquées « stable » qui appellent gb__auth (UPDATE de
-- gb_sessions / gb_players). PostgREST les lance en transaction en lecture seule
-- → « ne peut pas exécuter UPDATE dans une transaction en lecture seule ».
-- Effet visible : liste « En ligne » réduite aux joueurs connectés (gb_on_people
-- en échec), amis, réglages du compte et « regarder » muets.
-- Relançable.
alter function public.gb_on_people(text) volatile;
alter function public.gb_friend_ids(text) volatile;
alter function public.gb_settings_get(text, integer) volatile;
alter function public.gb_on_watch(text, bigint) volatile;
notify pgrst, 'reload schema';
