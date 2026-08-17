-- Catálogo inicial importado da loja Born From Seed.
-- Estoque é uma estimativa inicial: ajuste-o pelo painel ao conferir as peças físicas.
with catalog(name, slug, category, base_price, stock) as (
  values
    ('Básica Feminina - Virtuosa - Off', 'basica-feminina-virtuosa-off', 'Básicas', 74.90, 10),
    ('Básica Jesus Cristo é Rei - Marrom', 'basica-jesus-cristo-e-rei-marrom', 'Básicas', 74.90, 10),
    ('Oversized A Fé Move Montanhas - Off', 'oversized-a-fe-move-montanhas-off', 'Oversized', 109.90, 10),
    ('Oversized O Senhor dos Sábados - Off', 'oversized-o-senhor-dos-sabados-off', 'Oversized', 109.90, 10),
    ('Oversized O Senhor dos Sábados - Preta', 'oversized-o-senhor-dos-sabados-preta', 'Oversized', 109.90, 10),
    ('Oversized Jardim Fechado - Preta', 'oversized-jardim-fechado-preta', 'Oversized', 109.90, 10),
    ('Oversized Filha Preciosa - Mármore', 'oversized-filha-preciosa-marmore', 'Oversized', 109.90, 10),
    ('Oversized College - Verde Militar', 'oversized-college-verde-militar', 'Oversized', 95.00, 10),
    ('Oversized College - Marrom', 'oversized-college-marrom', 'Oversized', 95.00, 10),
    ('Oversized Tudo que Há de Bom em Mim - Off', 'oversized-tudo-que-ha-de-bom-em-mim-off', 'Oversized', 109.90, 10),
    ('Oversized Tudo que Há de Bom em Mim - Preto', 'oversized-tudo-que-ha-de-bom-em-mim-preto', 'Oversized', 109.90, 10),
    ('Oversized Santa Provisão de Deus - Preto', 'oversized-santa-provisao-de-deus-preto', 'Oversized', 109.90, 10),
    ('Oversized Hope For África - Verde Militar', 'oversized-hope-for-africa-verde-militar', 'Hope For África', 109.90, 10),
    ('Oversized Hope For África - Marrom', 'oversized-hope-for-africa-marrom', 'Hope For África', 109.90, 10),
    ('Oversized Hope For África - Off', 'oversized-hope-for-africa-off', 'Hope For África', 110.00, 10),
    ('Básica Jesus Cristo é Rei - Off', 'basica-jesus-cristo-e-rei-off', 'Básicas', 74.90, 0),
    ('Oversized Saturday - Cinza', 'oversized-saturday-cinza', 'Oversized', 109.90, 0),
    ('Oversized Pão da Vida - Off', 'oversized-pao-da-vida-off', 'Oversized', 109.90, 0),
    ('Oversized Jesus Cristo - Off', 'oversized-jesus-cristo-off', 'Oversized', 109.90, 0),
    ('Básica Amor Perfeito - Off', 'basica-amor-perfeito-off', 'Básicas', 74.90, 0),
    ('Básica Amor Perfeito - Off (edição 2)', 'basica-amor-perfeito-off-edicao-2', 'Básicas', 74.90, 0)
), inserted as (
  insert into public.products (name, slug, category, base_price, description, published)
  select name, slug, category, base_price,
    'Peça Born From Seed. Parte do lucro apoia a Casa da Criança em Moçambique.', true
  from catalog
  on conflict (slug) do update set name = excluded.name, category = excluded.category, base_price = excluded.base_price, published = true
  returning id, slug, base_price
)
insert into public.product_variants (product_id, sku, color, size, price, stock)
select p.id, 'BFS-' || upper(replace(c.slug, '-', '_')), null, 'Único', p.base_price, c.stock
from inserted p join catalog c using (slug)
where not exists (select 1 from public.product_variants v where v.product_id = p.id);
