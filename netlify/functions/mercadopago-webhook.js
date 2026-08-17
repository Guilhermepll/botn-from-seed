const crypto = require('crypto');
const SUPABASE_URL = 'https://pexzlzjyuibntinnrrpk.supabase.co';
const serviceHeaders = () => ({ apikey: process.env.SUPABASE_SERVICE_ROLE_KEY, Authorization: `Bearer ${process.env.SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' });

function signatureIsValid(event, paymentId) {
  const signature = event.headers['x-signature'];
  const requestId = event.headers['x-request-id'];
  if (!signature || !requestId || !process.env.MERCADO_PAGO_WEBHOOK_SECRET) return false;
  const values = Object.fromEntries(signature.split(',').map(part => part.trim().split('=')));
  const manifest = `id:${String(paymentId).toLowerCase()};request-id:${requestId};ts:${values.ts};`;
  const expected = crypto.createHmac('sha256', process.env.MERCADO_PAGO_WEBHOOK_SECRET).update(manifest).digest('hex');
  return values.v1 && crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(values.v1));
}

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return { statusCode: 405, body: 'Método não permitido' };
  try {
    const body = JSON.parse(event.body || '{}');
    const paymentId = body?.data?.id || event.queryStringParameters?.['data.id'];
    if (!paymentId || !signatureIsValid(event, paymentId)) return { statusCode: 401, body: 'Assinatura inválida' };
    const paymentResponse = await fetch(`https://api.mercadopago.com/v1/payments/${paymentId}`, { headers: { Authorization: `Bearer ${process.env.MERCADO_PAGO_ACCESS_TOKEN}` } });
    const payment = await paymentResponse.json();
    if (!paymentResponse.ok || payment.status !== 'approved' || !payment.external_reference) return { statusCode: 200, body: 'Ignorado' };
    const processResponse = await fetch(`${SUPABASE_URL}/rest/v1/rpc/process_mercadopago_payment`, { method: 'POST', headers: serviceHeaders(), body: JSON.stringify({ order_uuid: payment.external_reference, payment_id: String(payment.id) }) });
    if (!processResponse.ok) throw new Error('Não foi possível confirmar o pedido.');
    return { statusCode: 200, body: 'OK' };
  } catch (error) { return { statusCode: 500, body: error.message || 'Erro interno' }; }
};
