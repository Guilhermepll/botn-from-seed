const SUPABASE_URL = 'https://pexzlzjyuibntinnrrpk.supabase.co';
const SUPABASE_KEY = 'sb_publishable_N29hsSDybvmc126lh_vaUQ_PH-AbA64';
const serviceHeaders = () => ({ apikey: process.env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json', Prefer: 'return=representation' });

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return { statusCode: 405, body: JSON.stringify({ error: 'Método não permitido.' }) };
  if (!process.env.MERCADO_PAGO_ACCESS_TOKEN || !process.env.SUPABASE_SERVICE_ROLE_KEY) return { statusCode: 503, body: JSON.stringify({ error: 'Pagamento ainda não foi configurado.' }) };

  try {
    const { items } = JSON.parse(event.body || '{}');
    if (!Array.isArray(items) || !items.length || items.some(item => !item.productId || !Number.isInteger(item.quantity) || item.quantity < 1)) {
      return { statusCode: 400, body: JSON.stringify({ error: 'Sacola inválida.' }) };
    }

    const ids = [...new Set(items.map(item => item.productId))];
    const filter = ids.map(encodeURIComponent).join(',');
    const catalogResponse = await fetch(`${SUPABASE_URL}/rest/v1/products?id=in.(${filter})&published=eq.true&select=id,name,base_price,product_variants(stock)`, {
      headers: serviceHeaders()
    });
    const catalog = await catalogResponse.json();
    if (!catalogResponse.ok || catalog.length !== ids.length) throw new Error('Não foi possível validar os produtos da sacola.');

    const byId = new Map(catalog.map(product => [product.id, product]));
    const checkoutItems = items.map(item => {
      const product = byId.get(item.productId);
      const available = (product.product_variants || []).reduce((total, variant) => total + variant.stock, 0);
      if (available < item.quantity) throw new Error(`${product.name} não possui estoque suficiente.`);
      return { productId: product.id, title: product.name, quantity: item.quantity, currency_id: 'BRL', unit_price: Number(product.base_price) };
    });
    const subtotal = checkoutItems.reduce((total, item) => total + item.unit_price * item.quantity, 0);
    const orderResponse = await fetch(`${SUPABASE_URL}/rest/v1/orders`, { method: 'POST', headers: serviceHeaders(), body: JSON.stringify({ payment_method: 'mercadopago', subtotal, total: subtotal }) });
    const [order] = await orderResponse.json();
    if (!orderResponse.ok || !order?.id) throw new Error('Não foi possível criar o pedido.');
    const itemResponse = await fetch(`${SUPABASE_URL}/rest/v1/order_items`, { method: 'POST', headers: serviceHeaders(), body: JSON.stringify(checkoutItems.map(item => ({ order_id: order.id, product_id: item.productId, product_name: item.title, quantity: item.quantity, unit_price: item.unit_price }))) });
    if (!itemResponse.ok) throw new Error('Não foi possível registrar os itens do pedido.');
    const origin = `${event.headers['x-forwarded-proto'] || 'https'}://${event.headers.host}`;
    const paymentResponse = await fetch('https://api.mercadopago.com/checkout/preferences', {
      method: 'POST',
      headers: { Authorization: `Bearer ${process.env.MERCADO_PAGO_ACCESS_TOKEN}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ items: checkoutItems.map(({ productId, ...item }) => item), external_reference: order.id, notification_url: `${origin}/.netlify/functions/mercadopago-webhook`, back_urls: { success: `${origin}/?payment=success`, failure: `${origin}/?payment=failure`, pending: `${origin}/?payment=pending` }, auto_return: 'approved' })
    });
    const preference = await paymentResponse.json();
    if (!paymentResponse.ok || !preference.init_point) throw new Error(preference.message || 'O Mercado Pago recusou criar o pagamento.');
    return { statusCode: 200, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ initPoint: preference.init_point }) };
  } catch (error) {
    return { statusCode: 400, body: JSON.stringify({ error: error.message || 'Não foi possível iniciar o pagamento.' }) };
  }
};
