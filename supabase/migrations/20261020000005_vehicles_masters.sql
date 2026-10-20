-- 05 (phase 2): vehicle status changes, tariff edits with history, photo ordering,
-- per-vehicle statistics, and permission helpers used by storage.

-- ---------------------------------------------------------------- helpers
create or replace function private.require_role(p_roles public.user_role[])
returns void language plpgsql stable security definer set search_path = '' as $$
begin
  if public.app_role() is null or not (public.app_role() = any (p_roles)) then
    raise exception 'You do not have permission to do this.' using errcode = '42501';
  end if;
end $$;

-- can the caller see this challan? (RLS on challans decides; used by storage)
create or replace function public.app_can_see_challan(p_challan_id uuid)
returns boolean language sql stable security invoker set search_path = '' as $$
  select exists (select 1 from public.challans c where c.id = p_challan_id)
$$;

-- may the caller upload the site photo for this challan? (assigned driver, job in progress)
create or replace function public.app_can_upload_site_photo(p_challan_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.challans c
                 where c.id = p_challan_id and c.driver_id = public.app_driver_id()
                   and c.status in ('started', 'reached'))
$$;

-- ---------------------------------------------------------------- vehicle status (operator/admin)
-- On Job is never set here: it follows challans automatically.
create or replace function public.set_vehicle_status(
  p_vehicle_id uuid,
  p_status public.vehicle_status,
  p_reason text default null,
  p_expected_back date default null)
returns public.vehicles language plpgsql security definer set search_path = '' as $$
declare
  v      public.vehicles;
  v_job  text;
begin
  perform private.require_role(array['admin', 'operator']::public.user_role[]);
  select * into v from public.vehicles where id = p_vehicle_id for update;
  if not found or not public.app_can_see_tehsil(v.tehsil_id) then
    raise exception 'Vehicle not found.' using errcode = 'P0002';
  end if;
  if p_status = 'on_job' then
    raise exception 'On Job is set automatically when a challan is assigned.' using errcode = 'P0001';
  end if;
  select challan_no into v_job from public.challans
   where vehicle_id = p_vehicle_id and status in ('assigned', 'started', 'reached') limit 1;
  if v_job is not null then
    raise exception 'This vehicle is on a job (%). Finish or re-assign that challan first.', v_job using errcode = 'P0001';
  end if;

  if p_status = 'maintenance' then
    if coalesce(trim(p_reason), '') = '' then
      raise exception 'Write the reason for maintenance.' using errcode = 'P0001';
    end if;
    if p_expected_back is not null and p_expected_back < public.karachi_today() then
      raise exception 'The expected-back date cannot be in the past.' using errcode = 'P0001';
    end if;
    update public.vehicles
       set status = 'maintenance', status_reason = trim(p_reason), expected_back_on = p_expected_back
     where id = p_vehicle_id returning * into v;
    if not exists (select 1 from public.vehicle_maintenance where vehicle_id = p_vehicle_id and ended_on is null) then
      insert into public.vehicle_maintenance (vehicle_id, description, created_by)
      values (p_vehicle_id, trim(p_reason), auth.uid());
    end if;
  else  -- available
    update public.vehicles
       set status = 'available', status_reason = null, expected_back_on = null
     where id = p_vehicle_id returning * into v;
    update public.vehicle_maintenance set ended_on = public.karachi_today()
     where vehicle_id = p_vehicle_id and ended_on is null;
  end if;
  return v;
end $$;

-- ---------------------------------------------------------------- tariff (admin), keeps history
create or replace function public.set_tariff_rate(
  p_area_id uuid,
  p_vehicle_type_id uuid,
  p_rate numeric,
  p_effective_from date default null)
returns public.tariffs language plpgsql security definer set search_path = '' as $$
declare
  t      public.tariffs;
  v_unit public.pricing_unit;
begin
  perform private.require_role(array['admin']::public.user_role[]);
  if p_rate is null or p_rate < 0 then
    raise exception 'Enter a rate of 0 or more.' using errcode = 'P0001';
  end if;
  select pricing_unit into v_unit from public.vehicle_types where id = p_vehicle_type_id;
  if v_unit is null or not exists (select 1 from public.areas where id = p_area_id) then
    raise exception 'Area or vehicle type not found.' using errcode = 'P0002';
  end if;
  update public.tariffs set is_active = false
   where area_id = p_area_id and vehicle_type_id = p_vehicle_type_id and is_active;
  insert into public.tariffs (area_id, vehicle_type_id, rate, pricing_unit, effective_from, is_active, is_placeholder, created_by)
  values (p_area_id, p_vehicle_type_id, round(p_rate, 2), v_unit,
          coalesce(p_effective_from, public.karachi_today()), true, false, auth.uid())
  returning * into t;
  return t;
end $$;

-- ---------------------------------------------------------------- photo order (admin): first = main photo
create or replace function public.reorder_vehicle_photos(p_vehicle_id uuid, p_photo_ids uuid[])
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform private.require_role(array['admin']::public.user_role[]);
  if (select count(*) from public.vehicle_photos where vehicle_id = p_vehicle_id)
     <> coalesce(array_length(p_photo_ids, 1), 0) then
    raise exception 'The photo list is out of date. Reload and try again.' using errcode = 'P0001';
  end if;
  update public.vehicle_photos p
     set position = o.ord - 1
    from unnest(p_photo_ids) with ordinality as o (id, ord)
   where p.id = o.id and p.vehicle_id = p_vehicle_id;
end $$;

-- ---------------------------------------------------------------- per-vehicle numbers (board + history tab)
create or replace view public.vehicle_stats with (security_invoker = true) as
select v.id as vehicle_id,
       count(c.id) filter (where c.status = 'done')                                 as trips,
       coalesce(sum(c.amount) filter (where c.status = 'done'), 0)                  as amount_generated,
       coalesce(sum(c.amount) filter (where c.payment_status = 'paid'), 0)          as amount_paid,
       max(c.done_at)                                                                as last_trip_at,
       (select coalesce(sum(coalesce(m.ended_on, public.karachi_today()) - m.started_on + 1), 0)
          from public.vehicle_maintenance m where m.vehicle_id = v.id)              as days_in_maintenance
from public.vehicles v
left join public.challans c on c.vehicle_id = v.id
group by v.id;

grant select on public.vehicle_stats to authenticated;
revoke all on function private.require_role(public.user_role[]) from public;
grant execute on function public.set_vehicle_status(uuid, public.vehicle_status, text, date),
                          public.set_tariff_rate(uuid, uuid, numeric, date),
                          public.reorder_vehicle_photos(uuid, uuid[]),
                          public.app_can_see_challan(uuid),
                          public.app_can_upload_site_photo(uuid)
  to authenticated;
revoke execute on function public.set_vehicle_status(uuid, public.vehicle_status, text, date),
                           public.set_tariff_rate(uuid, uuid, numeric, date),
                           public.reorder_vehicle_photos(uuid, uuid[]),
                           public.app_can_see_challan(uuid),
                           public.app_can_upload_site_photo(uuid)
  from anon, public;
