-- Estrutura para pedidos confirmados pelo Mercado Pago.
alter table public.orders add column if not exists mercadopago_payment_id text unique;
alter table public.orders add column if not exists external_reference text unique;
alter table public.order_items add column if not exists product_id uuid references public.products(id) on delete set null;

create or replace function public.process_mercadopago_payment(order_uuid uuid, payment_id text)
returns void language plpgsql security definer set search_path = public as $$
declare
  order_record public.orders;
  line record;
  target_variant uuid;
begin
  select * into order_record from public.orders where id = order_uuid for update;
  if not found then raise exception 'Pedido não encontrado'; end if;
  if order_record.payment_status = 'approved' then return; end if;

  for line in
    select product_id, sum(quantity)::integer as quantity
    from public.order_items where order_id = order_uuid group by product_id
  loop
    select id into target_variant from public.product_variants
    where product_id = line.product_id and stock >= line.quantity
    order by stock desc limit 1 for update;
    if target_variant is null then raise exception 'Estoque insuficiente'; end if;
    update public.product_variants set stock = stock - line.quantity where id = target_variant;
  end loop;

  update public.orders set status = 'paid', payment_status = 'approved', mercadopago_payment_id = payment_id
  where id = order_uuid;
end;
$$;

revoke all on function public.process_mercadopago_payment(uuid, text) from public, anon, authenticated;
grant execute on function public.process_mercadopago_payment(uuid, text) to service_role;
