-- Albania Service & Booking Hub
-- Canonical Supabase schema for the Flutter app.
-- Run in the Supabase SQL Editor or apply with `supabase db push`.

create extension if not exists pgcrypto;

-- STORAGE SETUP -------------------------------------------------------------
-- This block provisions the bucket used by the Flutter gallery picker. For an
-- existing project that reports "Bucket not found", run this section first in
-- Supabase SQL Editor, then run the remainder of this schema as needed.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'business-images',
  'business-images',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read business images" on storage.objects;
drop policy if exists "Owners can upload business images" on storage.objects;
drop policy if exists "Owners can update business images" on storage.objects;
drop policy if exists "Owners can delete business images" on storage.objects;
create policy "Public can read business images"
on storage.objects for select
using (bucket_id = 'business-images');
create policy "Owners can upload business images"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'business-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy "Owners can update business images"
on storage.objects for update to authenticated
using (
  bucket_id = 'business-images'
  and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
  bucket_id = 'business-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);
create policy "Owners can delete business images"
on storage.objects for delete to authenticated
using (
  bucket_id = 'business-images'
  and (storage.foldername(name))[1] = auth.uid()::text
);

-- END STORAGE SETUP ---------------------------------------------------------

-- Keep the original domain types available when this schema is applied to a
-- fresh project, while allowing it to be re-run against the existing project.
do $$
begin
  if not exists (
    select 1 from pg_type where typnamespace = 'public'::regnamespace and typname = 'app_role'
  ) then
    create type public.app_role as enum ('customer', 'business_owner', 'admin');
  end if;

  if not exists (
    select 1 from pg_type where typnamespace = 'public'::regnamespace and typname = 'preferred_language'
  ) then
    create type public.preferred_language as enum ('sq', 'en');
  end if;

  if not exists (
    select 1 from pg_type where typnamespace = 'public'::regnamespace and typname = 'business_category'
  ) then
    create type public.business_category as enum (
      'car_rental',
      'barber',
      'dentist',
      'restaurant',
      'other'
    );
  end if;

  if not exists (
    select 1 from pg_type where typnamespace = 'public'::regnamespace and typname = 'subscription_status'
  ) then
    create type public.subscription_status as enum ('trial', 'active', 'past_due', 'canceled');
  end if;

  if not exists (
    select 1 from pg_type where typnamespace = 'public'::regnamespace and typname = 'booking_status'
  ) then
    create type public.booking_status as enum ('pending', 'confirmed', 'completed', 'canceled');
  end if;
end;
$$;

alter type public.business_category add value if not exists 'restaurant';

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null unique,
  full_name text,
  phone text,
  avatar_url text,
  role public.app_role not null default 'customer',
  preferred_language public.preferred_language not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Move the original local `businesses` model to the table name used by Flutter.
-- The conditions mean this only runs when a legacy table exists and listings
-- has not already been created.
do $$
begin
  if to_regclass('public.businesses') is not null
    and to_regclass('public.listings') is null then
    alter table public.businesses rename to listings;
  end if;

  if to_regclass('public.bookings') is not null
    and exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'bookings'
        and column_name = 'business_id'
    )
    and not exists (
      select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'bookings'
        and column_name = 'listing_id'
    ) then
    alter table public.bookings rename column business_id to listing_id;
  end if;
end;
$$;

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  -- Listings may be imported before a business owner claims them.
  owner_id uuid references public.users(id) on delete set null,
  title text not null,
  name text not null,
  slug text not null unique,
  description text not null,
  price_per_night numeric(10, 2) not null,
  location text not null,
  image_url text,
  category public.business_category not null,
  phone text,
  email text,
  website_url text,
  address_line text,
  district text,
  city text not null,
  country text not null default 'Albania',
  latitude numeric(9, 6),
  longitude numeric(9, 6),
  image_urls text[] not null default '{}',
  price_from numeric(10, 2),
  currency char(3) not null default 'ALL',
  rating numeric(2, 1) not null default 0,
  review_count integer not null default 0,
  default_booking_duration_minutes smallint,
  availability_note text,
  business_details jsonb not null default '{}'::jsonb,
  subscription_status public.subscription_status not null default 'trial',
  is_active boolean not null default true,
  is_featured boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Add the richer listing fields when upgrading the prior businesses table.
alter table public.listings
  add column if not exists title text,
  add column if not exists price_per_night numeric(10, 2),
  add column if not exists location text,
  add column if not exists image_url text,
  add column if not exists district text,
  add column if not exists image_urls text[] not null default '{}',
  add column if not exists price_from numeric(10, 2),
  add column if not exists currency char(3) not null default 'ALL',
  add column if not exists rating numeric(2, 1) not null default 0,
  add column if not exists review_count integer not null default 0,
  add column if not exists default_booking_duration_minutes smallint,
  add column if not exists availability_note text,
  add column if not exists business_details jsonb not null default '{}'::jsonb,
  add column if not exists is_featured boolean not null default false;

update public.listings
set
  title = coalesce(title, name),
  price_per_night = coalesce(price_per_night, price_from, 0),
  location = coalesce(location, concat_ws(', ', city, country)),
  image_url = coalesce(image_url, image_urls[1]);

alter table public.listings
  alter column owner_id drop not null,
  alter column title set not null,
  alter column price_per_night set not null,
  alter column location set not null,
  drop constraint if exists businesses_owner_id_fkey,
  drop constraint if exists listings_owner_id_fkey,
  add constraint listings_owner_id_fkey
    foreign key (owner_id) references public.users(id) on delete set null,
  drop constraint if exists businesses_slug_format,
  drop constraint if exists listings_slug_format,
  add constraint listings_slug_format
    check (slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'),
  drop constraint if exists businesses_latitude_range,
  drop constraint if exists listings_latitude_range,
  add constraint listings_latitude_range
    check (latitude is null or latitude between -90 and 90),
  drop constraint if exists businesses_longitude_range,
  drop constraint if exists listings_longitude_range,
  add constraint listings_longitude_range
    check (longitude is null or longitude between -180 and 180),
  drop constraint if exists listings_price_from_non_negative,
  add constraint listings_price_from_non_negative
    check (price_from is null or price_from >= 0),
  drop constraint if exists listings_price_per_night_positive,
  drop constraint if exists listings_price_per_night_non_negative,
  add constraint listings_price_per_night_non_negative
    check (price_per_night >= 0),
  drop constraint if exists listings_currency_uppercase,
  add constraint listings_currency_uppercase
    check (currency = upper(currency)),
  drop constraint if exists listings_rating_range,
  add constraint listings_rating_range
    check (rating between 0 and 5),
  drop constraint if exists listings_review_count_non_negative,
  add constraint listings_review_count_non_negative
    check (review_count >= 0),
  drop constraint if exists listings_booking_duration_range,
  add constraint listings_booking_duration_range
    check (
      default_booking_duration_minutes is null
      or default_booking_duration_minutes between 15 and 720
    );

create unique index if not exists listings_one_business_per_owner
on public.listings (owner_id)
where owner_id is not null;

create table if not exists public.rental_cars (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  model text not null,
  engine text not null,
  production_year integer,
  seat_count integer,
  price_per_day numeric(10, 2) not null,
  currency char(3) not null default 'ALL',
  transmission text not null,
  image_url text,
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint rental_cars_model_not_blank check (length(trim(model)) > 0),
  constraint rental_cars_engine_not_blank check (length(trim(engine)) > 0),
  constraint rental_cars_production_year_valid
    check (
      production_year is null
      or production_year between 1950 and extract(year from current_date)::integer + 1
    ),
  constraint rental_cars_seat_count_valid
    check (seat_count is null or seat_count between 1 and 12),
  constraint rental_cars_price_non_negative check (price_per_day >= 0),
  constraint rental_cars_currency_uppercase check (currency = upper(currency)),
  constraint rental_cars_transmission_valid
    check (transmission in ('automatic', 'manual'))
);

create index if not exists rental_cars_listing_id_idx
on public.rental_cars (listing_id);

alter table public.rental_cars
  add column if not exists production_year integer,
  add column if not exists seat_count integer,
  drop constraint if exists rental_cars_production_year_valid,
  add constraint rental_cars_production_year_valid
    check (
      production_year is null
      or production_year between 1950 and extract(year from current_date)::integer + 1
    ),
  drop constraint if exists rental_cars_seat_count_valid,
  add constraint rental_cars_seat_count_valid
    check (seat_count is null or seat_count between 1 and 12);

create table if not exists public.rental_car_unavailability (
  id uuid primary key default gen_random_uuid(),
  rental_car_id uuid not null references public.rental_cars(id) on delete cascade,
  starts_on date not null,
  ends_on date not null,
  reason text,
  created_at timestamptz not null default now(),
  constraint rental_car_unavailability_valid_range
    check (ends_on >= starts_on),
  constraint rental_car_unavailability_reason_not_blank
    check (reason is null or length(trim(reason)) > 0)
);

create index if not exists rental_car_unavailability_car_dates_idx
on public.rental_car_unavailability (rental_car_id, starts_on, ends_on);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  rental_car_id uuid references public.rental_cars(id) on delete set null,
  customer_id uuid not null references public.users(id) on delete cascade,
  status public.booking_status not null default 'pending',
  service_name text not null,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  price_amount numeric(10, 2),
  currency char(3) not null default 'ALL',
  customer_notes text,
  listing_notes text,
  cancellation_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Re-point legacy bookings to listings and normalize the notes field name.
alter table public.bookings
  add column if not exists rental_car_id uuid,
  add column if not exists listing_notes text,
  add column if not exists cancellation_reason text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'bookings'
      and column_name = 'business_notes'
  ) then
    update public.bookings
    set listing_notes = coalesce(listing_notes, business_notes);
  end if;
end;
$$;

alter table public.bookings
  drop constraint if exists bookings_business_id_fkey,
  drop constraint if exists bookings_listing_id_fkey,
  add constraint bookings_listing_id_fkey
    foreign key (listing_id) references public.listings(id) on delete cascade,
  drop constraint if exists bookings_rental_car_id_fkey,
  add constraint bookings_rental_car_id_fkey
    foreign key (rental_car_id) references public.rental_cars(id) on delete set null,
  drop constraint if exists bookings_valid_time_range,
  add constraint bookings_valid_time_range check (ends_at > starts_at),
  drop constraint if exists bookings_non_negative_price,
  add constraint bookings_non_negative_price
    check (price_amount is null or price_amount >= 0),
  drop constraint if exists bookings_currency_uppercase,
  add constraint bookings_currency_uppercase
    check (currency = upper(currency));

-- Durable, in-app booking updates. Notification rows are created only by the
-- booking trigger below; each signed-in user can read and mark only their own.
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.users(id) on delete cascade,
  booking_id uuid references public.bookings(id) on delete cascade,
  type text not null check (
    type in (
      'booking_requested',
      'booking_confirmed',
      'booking_declined',
      'booking_canceled'
    )
  ),
  title text not null check (length(trim(title)) > 0),
  body text not null check (length(trim(body)) > 0),
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

drop index if exists public.businesses_owner_id_idx;
drop index if exists public.businesses_category_city_idx;
drop index if exists public.businesses_active_idx;
drop index if exists public.bookings_no_duplicate_active_slot_idx;

create index if not exists listings_owner_id_idx
  on public.listings(owner_id)
  where owner_id is not null;
create index if not exists listings_category_city_active_idx
  on public.listings(category, city)
  where is_active = true;
create index if not exists listings_featured_idx
  on public.listings(is_featured, city)
  where is_active = true and is_featured = true;
create index if not exists bookings_listing_id_starts_at_idx
  on public.bookings(listing_id, starts_at);
create index if not exists bookings_customer_id_starts_at_idx
  on public.bookings(customer_id, starts_at);
create index if not exists bookings_status_idx
  on public.bookings(status);
create index if not exists bookings_rental_car_id_starts_at_idx
on public.bookings(rental_car_id, starts_at)
where rental_car_id is not null;
create index if not exists notifications_recipient_created_at_idx
on public.notifications(recipient_id, created_at desc);
create index if not exists notifications_unread_recipient_idx
on public.notifications(recipient_id, is_read)
where is_read = false;

create unique index bookings_no_duplicate_active_slot_idx
  on public.bookings(listing_id, starts_at, ends_at)
  where rental_car_id is null and status in ('pending', 'confirmed');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.clear_business_category_data()
returns trigger
language plpgsql
as $$
begin
  if old.category is distinct from new.category then
    delete from public.rental_cars where listing_id = old.id;
    new.business_details = '{}'::jsonb;
  end if;
  return new;
end;
$$;

create or replace function public.rental_car_is_available(
  p_rental_car_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_starts_at >= p_ends_at then
    return false;
  end if;

  if not exists (
    select 1
    from public.rental_cars
    join public.listings on listings.id = rental_cars.listing_id
    where rental_cars.id = p_rental_car_id
      and rental_cars.is_available = true
      and listings.is_active = true
  ) then
    return false;
  end if;

  return not exists (
    select 1
    from public.bookings
    where bookings.rental_car_id = p_rental_car_id
      and bookings.status = 'confirmed'
      and bookings.starts_at < p_ends_at
      and bookings.ends_at > p_starts_at
  ) and not exists (
    select 1
    from public.rental_car_unavailability
    where rental_car_unavailability.rental_car_id = p_rental_car_id
      and rental_car_unavailability.starts_on <= p_ends_at::date
      and rental_car_unavailability.ends_on >= p_starts_at::date
  );
end;
$$;

create or replace function public.available_rental_cars(
  p_listing_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz
)
returns setof public.rental_cars
language sql
security definer
set search_path = public
as $$
  select rental_cars.*
  from public.rental_cars
  join public.listings on listings.id = rental_cars.listing_id
  where rental_cars.listing_id = p_listing_id
    and rental_cars.is_available = true
    and listings.is_active = true
    and public.rental_car_is_available(
      rental_cars.id,
      p_starts_at,
      p_ends_at
    );
$$;

create or replace function public.enforce_rental_car_booking()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_car public.rental_cars%rowtype;
  v_rental_days integer;
begin
  if new.rental_car_id is null then
    return new;
  end if;

  select *
  into v_car
  from public.rental_cars
  where id = new.rental_car_id
  for update;

  if not found or v_car.listing_id <> new.listing_id then
    raise exception 'The selected car does not belong to this business.'
      using errcode = '23514';
  end if;

  if not v_car.is_available then
    raise exception 'This car is currently unavailable.' using errcode = '23P01';
  end if;

  v_rental_days := greatest(1, (new.ends_at::date - new.starts_at::date));
  new.service_name := v_car.model;
  new.currency := v_car.currency;
  new.price_amount := v_car.price_per_day * v_rental_days;

  if new.status = 'confirmed'
    and not public.rental_car_is_available(
      new.rental_car_id,
      new.starts_at,
      new.ends_at
    ) then
    raise exception 'This car is no longer available for the selected dates.'
      using errcode = '23P01';
  end if;

  return new;
end;
$$;

create or replace function public.enforce_booking_status_transition()
returns trigger
language plpgsql
as $$
begin
  if old.status is not distinct from new.status then
    return new;
  end if;

  if old.status = 'pending'
    and new.status not in ('confirmed', 'canceled') then
    raise exception 'A pending booking can only be confirmed or canceled.'
      using errcode = '23514';
  end if;

  if old.status = 'confirmed'
    and new.status not in ('completed', 'canceled') then
    raise exception 'A confirmed booking can only be completed or canceled.'
      using errcode = '23514';
  end if;

  if old.status in ('completed', 'canceled') then
    raise exception 'Completed or canceled bookings cannot be changed.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;

create or replace function public.create_booking_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing_title text;
  v_owner_id uuid;
  v_subject text;
  v_reason text;
begin
  select title, owner_id
  into v_listing_title, v_owner_id
  from public.listings
  where id = new.listing_id;

  v_subject := coalesce(v_listing_title, new.service_name, 'your business');
  v_reason := coalesce(nullif(trim(new.cancellation_reason), ''), 'No reason was provided.');

  if tg_op = 'INSERT' then
    if v_owner_id is not null then
      insert into public.notifications (
        recipient_id, booking_id, type, title, body
      ) values (
        v_owner_id,
        new.id,
        'booking_requested',
        'New booking request',
        format('A customer requested %s from %s to %s.', v_subject, new.starts_at::date, new.ends_at::date)
      );
    end if;
    return new;
  end if;

  if old.status is not distinct from new.status then
    return new;
  end if;

  if new.status = 'confirmed' then
    insert into public.notifications (
      recipient_id, booking_id, type, title, body
    ) values (
      new.customer_id,
      new.id,
      'booking_confirmed',
      'Booking confirmed',
      format('Your booking for %s has been confirmed.', v_subject)
    );
  elsif new.status = 'canceled' then
    if auth.uid() = new.customer_id then
      if v_owner_id is not null then
        insert into public.notifications (
          recipient_id, booking_id, type, title, body
        ) values (
          v_owner_id,
          new.id,
          'booking_canceled',
          'Booking canceled by customer',
          format('The customer canceled the booking for %s. Reason: %s', v_subject, v_reason)
        );
      end if;
    else
      insert into public.notifications (
        recipient_id, booking_id, type, title, body
      ) values (
        new.customer_id,
        new.id,
        'booking_declined',
        'Booking request declined',
        format('Your booking request for %s was declined. Reason: %s', v_subject, v_reason)
      );
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.create_rental_car_booking(
  p_listing_id uuid,
  p_rental_car_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_customer_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking_id uuid;
  v_listing public.listings%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Sign in is required to request a car rental.'
      using errcode = '42501';
  end if;

  select *
  into v_listing
  from public.listings
  where id = p_listing_id
  for key share;

  if not found or not v_listing.is_active then
    raise exception 'This business is not accepting bookings.'
      using errcode = '23514';
  end if;

  if v_listing.owner_id = auth.uid() then
    raise exception 'You cannot book a car from your own business.'
      using errcode = '42501';
  end if;

  if not public.rental_car_is_available(
    p_rental_car_id,
    p_starts_at,
    p_ends_at
  ) then
    raise exception 'This car is no longer available for the selected dates.'
      using errcode = '23P01';
  end if;

  insert into public.bookings (
    listing_id,
    rental_car_id,
    customer_id,
    status,
    service_name,
    starts_at,
    ends_at,
    price_amount,
    currency,
    customer_notes
  )
  values (
    p_listing_id,
    p_rental_car_id,
    auth.uid(),
    'pending',
    'Car rental',
    p_starts_at,
    p_ends_at,
    0,
    'ALL',
    nullif(trim(p_customer_notes), '')
  )
  returning id into v_booking_id;

  return v_booking_id;
end;
$$;

-- Booking writes are performed only through these guarded RPCs. This keeps
-- price calculation, ownership checks, and status changes out of the client.
create or replace function public.create_listing_booking(
  p_listing_id uuid,
  p_starts_at timestamptz,
  p_ends_at timestamptz,
  p_customer_notes text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_listing public.listings%rowtype;
  v_booking_id uuid;
  v_price numeric(10, 2);
  v_stay_nights integer;
begin
  if auth.uid() is null then
    raise exception 'Sign in is required to create a booking.'
      using errcode = '42501';
  end if;

  if p_starts_at >= p_ends_at then
    raise exception 'The booking end time must be after the start time.'
      using errcode = '23514';
  end if;

  select *
  into v_listing
  from public.listings
  where id = p_listing_id
  for key share;

  if not found or not v_listing.is_active then
    raise exception 'This business is not accepting bookings.'
      using errcode = '23514';
  end if;

  if v_listing.category = 'car_rental' then
    raise exception 'Select a vehicle before requesting a car rental.'
      using errcode = '23514';
  end if;

  if v_listing.owner_id = auth.uid() then
    raise exception 'You cannot book your own business.'
      using errcode = '42501';
  end if;

  v_stay_nights := greatest(1, p_ends_at::date - p_starts_at::date);
  v_price := case
    when v_listing.category = 'other' then v_listing.price_per_night * v_stay_nights
    else coalesce(v_listing.price_from, v_listing.price_per_night)
  end;

  insert into public.bookings (
    listing_id,
    customer_id,
    status,
    service_name,
    starts_at,
    ends_at,
    price_amount,
    currency,
    customer_notes
  ) values (
    v_listing.id,
    auth.uid(),
    'pending',
    v_listing.title,
    p_starts_at,
    p_ends_at,
    v_price,
    v_listing.currency,
    nullif(trim(p_customer_notes), '')
  )
  returning id into v_booking_id;

  return v_booking_id;
end;
$$;

create or replace function public.transition_booking_status(
  p_booking_id uuid,
  p_status public.booking_status,
  p_cancellation_reason text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_booking public.bookings%rowtype;
  v_owner_id uuid;
  v_reason text := nullif(trim(p_cancellation_reason), '');
begin
  if auth.uid() is null then
    raise exception 'Sign in is required to update a booking.'
      using errcode = '42501';
  end if;

  select *
  into v_booking
  from public.bookings
  where id = p_booking_id
  for update;

  if not found then
    raise exception 'Booking not found.' using errcode = 'P0002';
  end if;

  select owner_id
  into v_owner_id
  from public.listings
  where id = v_booking.listing_id;

  if p_status = 'confirmed' then
    if v_owner_id is distinct from auth.uid() then
      raise exception 'Only the business owner can confirm this booking.'
        using errcode = '42501';
    end if;
  elsif p_status = 'completed' then
    if v_owner_id is distinct from auth.uid() then
      raise exception 'Only the business owner can complete this booking.'
        using errcode = '42501';
    end if;
  elsif p_status = 'canceled' then
    if auth.uid() is distinct from v_booking.customer_id
      and auth.uid() is distinct from v_owner_id then
      raise exception 'You cannot cancel this booking.' using errcode = '42501';
    end if;

    if v_reason is null then
      raise exception 'Please provide a cancellation or decline reason.'
        using errcode = '23514';
    end if;
  else
    raise exception 'Bookings cannot be moved back to pending.'
      using errcode = '23514';
  end if;

  update public.bookings
  set
    status = p_status,
    cancellation_reason = case
      when p_status = 'canceled' then v_reason
      else cancellation_reason
    end
  where id = v_booking.id;
end;
$$;

create or replace function public.enforce_rental_car_unavailability()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.rental_car_unavailability
    where rental_car_unavailability.rental_car_id = new.rental_car_id
      and rental_car_unavailability.id <> new.id
      and rental_car_unavailability.starts_on <= new.ends_on
      and rental_car_unavailability.ends_on >= new.starts_on
  ) then
    raise exception 'This car already has an unavailable period overlapping those dates.'
      using errcode = '23P01';
  end if;

  if exists (
    select 1
    from public.bookings
    where bookings.rental_car_id = new.rental_car_id
      and bookings.status = 'confirmed'
      and bookings.starts_at::date <= new.ends_on
      and bookings.ends_at::date >= new.starts_on
  ) then
    raise exception 'This car has a confirmed booking during those dates.'
      using errcode = '23P01';
  end if;

  return new;
end;
$$;

create or replace function public.create_user_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, full_name, role)
  values (
    new.id,
    new.email,
    nullif(coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'), ''),
    case
      when new.raw_user_meta_data->>'account_role' = 'business_owner'
        then 'business_owner'::public.app_role
      else 'customer'::public.app_role
    end
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

drop trigger if exists set_users_updated_at on public.users;
create trigger set_users_updated_at
before update on public.users
for each row execute function public.set_updated_at();

drop trigger if exists set_businesses_updated_at on public.listings;
drop trigger if exists set_listings_updated_at on public.listings;
drop trigger if exists clear_business_category_data on public.listings;
create trigger clear_business_category_data
before update of category on public.listings
for each row execute function public.clear_business_category_data();
create trigger set_listings_updated_at
before update on public.listings
for each row execute function public.set_updated_at();

drop trigger if exists set_rental_cars_updated_at on public.rental_cars;
create trigger set_rental_cars_updated_at
before update on public.rental_cars
for each row execute function public.set_updated_at();

drop trigger if exists enforce_rental_car_unavailability
on public.rental_car_unavailability;
create trigger enforce_rental_car_unavailability
before insert or update of rental_car_id, starts_on, ends_on
on public.rental_car_unavailability
for each row execute function public.enforce_rental_car_unavailability();

drop trigger if exists enforce_rental_car_booking on public.bookings;
create trigger enforce_rental_car_booking
before insert or update of rental_car_id, listing_id, starts_at, ends_at, status
on public.bookings
for each row execute function public.enforce_rental_car_booking();

drop trigger if exists enforce_booking_status_transition on public.bookings;
create trigger enforce_booking_status_transition
before update of status on public.bookings
for each row execute function public.enforce_booking_status_transition();

drop trigger if exists set_bookings_updated_at on public.bookings;
create trigger set_bookings_updated_at
before update on public.bookings
for each row execute function public.set_updated_at();

drop trigger if exists create_booking_notification on public.bookings;
create trigger create_booking_notification
after insert or update of status, cancellation_reason on public.bookings
for each row execute function public.create_booking_notification();

drop trigger if exists create_user_profile_after_signup on auth.users;
create trigger create_user_profile_after_signup
after insert on auth.users
for each row execute function public.create_user_profile();

alter table public.users enable row level security;
alter table public.listings enable row level security;
alter table public.rental_cars enable row level security;
alter table public.rental_car_unavailability enable row level security;
alter table public.bookings enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "Users can read their own profile" on public.users;
drop policy if exists "Users can update their own profile" on public.users;
create policy "Users can read their own profile"
on public.users for select
using (auth.uid() = id);
create policy "Users can update their own profile"
on public.users for update
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "Anyone can read active businesses" on public.listings;
drop policy if exists "Business owners can read their businesses" on public.listings;
drop policy if exists "Business owners can create businesses" on public.listings;
drop policy if exists "Business owners can update their businesses" on public.listings;
drop policy if exists "Business owners can delete their businesses" on public.listings;
drop policy if exists "Anyone can read active listings" on public.listings;
drop policy if exists "Owners can read their listings" on public.listings;
drop policy if exists "Owners can create listings" on public.listings;
drop policy if exists "Owners can update listings" on public.listings;
drop policy if exists "Owners can delete listings" on public.listings;
create policy "Anyone can read active listings"
on public.listings for select
using (is_active = true);
create policy "Owners can read their listings"
on public.listings for select
using (auth.uid() = owner_id);
create policy "Owners can create listings"
on public.listings for insert
with check (auth.uid() = owner_id);
create policy "Owners can update listings"
on public.listings for update
using (auth.uid() = owner_id)
with check (auth.uid() = owner_id);
create policy "Owners can delete listings"
on public.listings for delete
using (auth.uid() = owner_id);

drop policy if exists "Anyone can read rental cars" on public.rental_cars;
drop policy if exists "Owners can create rental cars" on public.rental_cars;
drop policy if exists "Owners can update rental cars" on public.rental_cars;
drop policy if exists "Owners can delete rental cars" on public.rental_cars;
create policy "Anyone can read rental cars"
on public.rental_cars for select
using (
  exists (
    select 1
    from public.listings
    where listings.id = rental_cars.listing_id
      and (listings.is_active = true or listings.owner_id = auth.uid())
  )
);
create policy "Owners can create rental cars"
on public.rental_cars for insert
with check (
  exists (
    select 1
    from public.listings
    where listings.id = rental_cars.listing_id
      and listings.owner_id = auth.uid()
      and listings.category = 'car_rental'
  )
);
create policy "Owners can update rental cars"
on public.rental_cars for update
using (
  exists (
    select 1
    from public.listings
    where listings.id = rental_cars.listing_id
      and listings.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.listings
    where listings.id = rental_cars.listing_id
      and listings.owner_id = auth.uid()
      and listings.category = 'car_rental'
  )
);
create policy "Owners can delete rental cars"
on public.rental_cars for delete
using (
  exists (
    select 1
    from public.listings
    where listings.id = rental_cars.listing_id
      and listings.owner_id = auth.uid()
  )
);

drop policy if exists "Owners can read car unavailability"
on public.rental_car_unavailability;
drop policy if exists "Owners can create car unavailability"
on public.rental_car_unavailability;
drop policy if exists "Owners can update car unavailability"
on public.rental_car_unavailability;
drop policy if exists "Owners can delete car unavailability"
on public.rental_car_unavailability;
create policy "Owners can read car unavailability"
on public.rental_car_unavailability for select
using (
  exists (
    select 1
    from public.rental_cars
    join public.listings on listings.id = rental_cars.listing_id
    where rental_cars.id = rental_car_unavailability.rental_car_id
      and listings.owner_id = auth.uid()
  )
);
create policy "Owners can create car unavailability"
on public.rental_car_unavailability for insert
with check (
  exists (
    select 1
    from public.rental_cars
    join public.listings on listings.id = rental_cars.listing_id
    where rental_cars.id = rental_car_unavailability.rental_car_id
      and listings.owner_id = auth.uid()
  )
);
create policy "Owners can update car unavailability"
on public.rental_car_unavailability for update
using (
  exists (
    select 1
    from public.rental_cars
    join public.listings on listings.id = rental_cars.listing_id
    where rental_cars.id = rental_car_unavailability.rental_car_id
      and listings.owner_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.rental_cars
    join public.listings on listings.id = rental_cars.listing_id
    where rental_cars.id = rental_car_unavailability.rental_car_id
      and listings.owner_id = auth.uid()
  )
);
create policy "Owners can delete car unavailability"
on public.rental_car_unavailability for delete
using (
  exists (
    select 1
    from public.rental_cars
    join public.listings on listings.id = rental_cars.listing_id
    where rental_cars.id = rental_car_unavailability.rental_car_id
      and listings.owner_id = auth.uid()
  )
);

drop policy if exists "Customers can create their own bookings" on public.bookings;
drop policy if exists "Customers can read their own bookings" on public.bookings;
drop policy if exists "Business owners can read bookings for their businesses" on public.bookings;
drop policy if exists "Customers can update their pending bookings" on public.bookings;
drop policy if exists "Business owners can update bookings for their businesses" on public.bookings;
drop policy if exists "Listing owners can read bookings" on public.bookings;
drop policy if exists "Listing owners can update bookings" on public.bookings;
create policy "Customers can read their own bookings"
on public.bookings for select
using (auth.uid() = customer_id);
create policy "Listing owners can read bookings"
on public.bookings for select
using (
  exists (
    select 1
    from public.listings
    where listings.id = bookings.listing_id
      and listings.owner_id = auth.uid()
  )
);

drop policy if exists "Users can read their notifications" on public.notifications;
drop policy if exists "Users can mark their notifications read" on public.notifications;
create policy "Users can read their notifications"
on public.notifications for select
using (auth.uid() = recipient_id);
create policy "Users can mark their notifications read"
on public.notifications for update
using (auth.uid() = recipient_id)
with check (auth.uid() = recipient_id);

grant select on public.listings to anon, authenticated;
grant insert, update, delete on public.listings to authenticated;
grant select on public.rental_cars to anon, authenticated;
grant insert, update, delete on public.rental_cars to authenticated;
grant select, insert, update, delete on public.rental_car_unavailability
to authenticated;
revoke insert, update, delete on public.bookings from anon, authenticated;
grant select on public.bookings to authenticated;
grant select, update on public.notifications to authenticated;
grant select, update on public.users to authenticated;
revoke all on function public.rental_car_is_available(uuid, timestamptz, timestamptz) from public;
revoke all on function public.available_rental_cars(uuid, timestamptz, timestamptz) from public;
revoke all on function public.create_rental_car_booking(uuid, uuid, timestamptz, timestamptz, text) from public;
revoke all on function public.create_listing_booking(uuid, timestamptz, timestamptz, text) from public;
revoke all on function public.transition_booking_status(uuid, public.booking_status, text) from public;
grant execute on function public.available_rental_cars(uuid, timestamptz, timestamptz) to anon, authenticated;
grant execute on function public.create_rental_car_booking(uuid, uuid, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.create_listing_booking(uuid, timestamptz, timestamptz, text) to authenticated;
grant execute on function public.transition_booking_status(uuid, public.booking_status, text) to authenticated;

-- Seed only unclaimed public listings so this file has no dependency on test
-- records in auth.users. These can be claimed later by setting owner_id.
insert into public.listings (
  title,
  name,
  slug,
  description,
  price_per_night,
  location,
  image_url,
  category,
  phone,
  email,
  website_url,
  address_line,
  district,
  city,
  latitude,
  longitude,
  price_from,
  currency,
  rating,
  review_count,
  default_booking_duration_minutes,
  availability_note,
  is_active,
  is_featured
)
values
  (
    'Stone Villa Gjirokaster',
    'Stone Villa Gjirokaster',
    'stone-villa-gjirokaster',
    'A restored stone villa with castle views, a quiet courtyard, and traditional southern Albanian details.',
    89.00,
    'Gjirokaster, Albania',
    'https://images.unsplash.com/photo-1601918774946-25832a4be0d6?auto=format&fit=crop&w=1200&q=80',
    'other',
    '+355 69 123 4567',
    'stay@stonevillagjirokaster.example',
    null,
    'Rruga Bashkim Kokona 12',
    'Old Bazaar',
    'Gjirokaster',
    40.075800,
    20.138900,
    89.00,
    'USD',
    4.9,
    68,
    null,
    'Self check-in from 15:00.',
    true,
    true
  ),
  (
    'Ionian Sea View Loft',
    'Ionian Sea View Loft',
    'ionian-sea-view-loft',
    'A bright coastal loft with a private balcony, open sea views, and an easy walk to the Sarande promenade.',
    120.00,
    'Sarande, Albania',
    'https://images.unsplash.com/photo-1600607687939-ce8a6c25118c?auto=format&fit=crop&w=1200&q=80',
    'other',
    '+355 68 234 5678',
    'hello@ionianloft.example',
    null,
    'Rruga Butrinti 84',
    'Kodrra',
    'Sarande',
    39.866500,
    20.018600,
    120.00,
    'USD',
    4.8,
    91,
    null,
    'Two-night minimum during July and August.',
    true,
    true
  ),
  (
    'Theth Mountain Guesthouse',
    'Theth Mountain Guesthouse',
    'theth-mountain-guesthouse',
    'A welcoming alpine guesthouse near the village trailheads, with homemade breakfast and sweeping valley views.',
    74.00,
    'Theth, Albania',
    'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?auto=format&fit=crop&w=1200&q=80',
    'other',
    '+355 67 345 6789',
    'bookings@thethguesthouse.example',
    null,
    'Rruga Fushe 7',
    'Theth Valley',
    'Theth',
    42.395300,
    19.774400,
    74.00,
    'USD',
    4.9,
    127,
    null,
    'Breakfast and trail transfer available.',
    true,
    false
  ),
  (
    'Tirana Garden Apartment',
    'Tirana Garden Apartment',
    'tirana-garden-apartment',
    'A calm, design-led apartment with a leafy terrace, dedicated workspace, and quick access to Blloku.',
    96.00,
    'Tirana, Albania',
    'https://images.unsplash.com/photo-1600047509807-ba8f99d2cdde?auto=format&fit=crop&w=1200&q=80',
    'other',
    '+355 68 456 7890',
    'host@tiranagarden.example',
    null,
    'Rruga Sami Frasheri 31',
    'Blloku',
    'Tirana',
    41.320900,
    19.811600,
    96.00,
    'USD',
    4.7,
    104,
    null,
    'Weekly stays receive complimentary cleaning.',
    true,
    false
  )
on conflict (slug) do update
set
  title = excluded.title,
  name = excluded.name,
  description = excluded.description,
  price_per_night = excluded.price_per_night,
  location = excluded.location,
  image_url = excluded.image_url,
  category = excluded.category,
  phone = excluded.phone,
  email = excluded.email,
  website_url = excluded.website_url,
  address_line = excluded.address_line,
  district = excluded.district,
  city = excluded.city,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  price_from = excluded.price_from,
  currency = excluded.currency,
  rating = excluded.rating,
  review_count = excluded.review_count,
  default_booking_duration_minutes = excluded.default_booking_duration_minutes,
  availability_note = excluded.availability_note,
  is_active = excluded.is_active,
  is_featured = excluded.is_featured;
