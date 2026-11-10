-- =====================================================================
-- 029 EKONOMI V2 — FAZ 1: ODUL ENERJISI
-- =====================================================================
-- Tasarim: docs/EKONOMI_V2_TASARIM.md §6.
--
-- Mac ici TAKTIK ENERJISINDEN (021) TAMAMEN AYRIDIR: ayri tablo, ayri
-- isim. Dereceli mac 1 odul enerjisi harcar ve sandik kazandirir.
-- Enerjisi biten oyuncu NORMAL oynar: eslesme, MMR, galibiyet altini,
-- koruma hakki ve kart kaybi aynen; yalniz sandik cikmaz.
--
-- TEMBEL DOLUM: zamanlayici yok. Satirda son deger ve son dolum ani
-- tutulur; okunurken/harcanirken now() farki eklenir.
-- Tekrar calistirilabilir.
-- =====================================================================

insert into economy_config_versions (kind, version, payload, note)
values ('reward_energy', 1, '{"max": 10, "refill_minutes": 96}',
        '029: en fazla 10, 96 dakikada 1 (gunde 15)')
on conflict (kind, version) do nothing;

create table if not exists reward_energy (
  user_id         uuid primary key references users(id) on delete cascade,
  energy          int not null check (energy >= 0),
  -- Bir sonraki dolumun sayildigi an (enerji tam doluyken = son
  -- harcama ani; dolu iken zaman biriktirilmez)
  refill_anchor   timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table reward_energy is
  'Ekonomi V2 odul enerjisi (taktik enerjisinden ayri). Tembel dolum.';

-- ---------------------------------------------------------------------
-- Anlik durum (YAZMAZ). Satir yoksa oyuncu tam enerjilidir.
-- ---------------------------------------------------------------------
create or replace function reward_energy_state(p_user_id uuid)
returns jsonb
language plpgsql stable as $$
declare
  c        jsonb := economy_config('reward_energy');
  v_max    int := coalesce((c ->> 'max')::int, 10);
  v_dk     int := coalesce((c ->> 'refill_minutes')::int, 96);
  r        reward_energy%rowtype;
  v_dolan  int;
  v_enerji int;
  v_sonraki timestamptz;
begin
  select * into r from reward_energy where user_id = p_user_id;
  if not found then
    return jsonb_build_object('energy', v_max, 'max', v_max, 'refill_minutes', v_dk,
                              'next_at', null, 'server_time', now());
  end if;
  v_dolan  := floor(extract(epoch from (now() - r.refill_anchor)) / (v_dk * 60))::int;
  v_enerji := least(v_max, r.energy + greatest(v_dolan, 0));
  v_sonraki := case when v_enerji >= v_max then null
                    else r.refill_anchor + make_interval(mins => v_dk * (greatest(v_dolan, 0) + 1)) end;
  return jsonb_build_object('energy', v_enerji, 'max', v_max, 'refill_minutes', v_dk,
                            'next_at', v_sonraki, 'server_time', now());
end;
$$;

-- ---------------------------------------------------------------------
-- 1 enerji harca. Doner: harcandi mi? (enerji yoksa false, HATA DEGIL)
-- ---------------------------------------------------------------------
create or replace function _reward_energy_spend(p_user_id uuid)
returns boolean
language plpgsql as $$
declare
  c        jsonb := economy_config('reward_energy');
  v_max    int := coalesce((c ->> 'max')::int, 10);
  v_dk     int := coalesce((c ->> 'refill_minutes')::int, 96);
  r        reward_energy%rowtype;
  v_dolan  int;
  v_enerji int;
  v_capa   timestamptz;
begin
  insert into reward_energy (user_id, energy) values (p_user_id, v_max)
  on conflict (user_id) do nothing;
  select * into r from reward_energy where user_id = p_user_id for update;

  v_dolan  := greatest(floor(extract(epoch from (now() - r.refill_anchor)) / (v_dk * 60))::int, 0);
  v_enerji := least(v_max, r.energy + v_dolan);
  -- Capa: tam doluysa simdi; degilse dolan aralik kadar ileri (kalan
  -- kesir korunur, oyuncu dakika kaybetmez)
  v_capa := case when v_enerji >= v_max then now()
                 else r.refill_anchor + make_interval(mins => v_dk * v_dolan) end;

  if v_enerji < 1 then
    update reward_energy set energy = v_enerji, refill_anchor = v_capa, updated_at = now()
    where user_id = p_user_id;
    return false;
  end if;

  update reward_energy set energy = v_enerji - 1, refill_anchor = v_capa, updated_at = now()
  where user_id = p_user_id;
  return true;
end;
$$;

-- ---------------------------------------------------------------------
-- Enerji ekle (enerji icecegi vb., FAZ 3). Kapasiteyi asamaz.
-- ---------------------------------------------------------------------
create or replace function _reward_energy_add(p_user_id uuid, p_amount int)
returns int
language plpgsql as $$
declare
  c        jsonb := economy_config('reward_energy');
  v_max    int := coalesce((c ->> 'max')::int, 10);
  v_dk     int := coalesce((c ->> 'refill_minutes')::int, 96);
  r        reward_energy%rowtype;
  v_dolan  int;
  v_enerji int;
begin
  insert into reward_energy (user_id, energy) values (p_user_id, v_max)
  on conflict (user_id) do nothing;
  select * into r from reward_energy where user_id = p_user_id for update;

  -- Once biriken dolumu uygula (harcamayla AYNI hesap), sonra ekle
  v_dolan  := greatest(floor(extract(epoch from (now() - r.refill_anchor)) / (v_dk * 60))::int, 0);
  v_enerji := least(v_max, least(v_max, r.energy + v_dolan) + greatest(p_amount, 0));

  update reward_energy
  set energy        = v_enerji,
      refill_anchor = case when v_enerji >= v_max then now()
                           else r.refill_anchor + make_interval(mins => v_dk * v_dolan) end,
      updated_at    = now()
  where user_id = p_user_id;
  return v_enerji;
end;
$$;
