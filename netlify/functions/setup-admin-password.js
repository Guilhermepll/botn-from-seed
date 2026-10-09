const crypto = require('crypto');

const SUPABASE_URL = 'https://pexzlzjyuibntinnrrpk.supabase.co';
const ADMIN_EMAIL = 'guiessencial2@gmail.com';
const ADMIN_ID = '3f69e0d3-157f-47e2-9ce2-f6865ec25af6';

const json = (statusCode, body) => ({ statusCode, headers: { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }, body: JSON.stringify(body) });
const secureEqual = (a, b) => {
  const left = Buffer.from(a || '');
  const right = Buffer.from(b || '');
  return left.length === right.length && crypto.timingSafeEqual(left, right);
};

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return json(405, { error: 'Método não permitido.' });
  const configuredSecret = process.env.ADMIN_SETUP_SECRET;
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!configuredSecret || !serviceKey) return json(503, { error: 'A configuração segura do administrador não está disponível.' });

  try {
    const { email, password, setupSecret } = JSON.parse(event.body || '{}');
    if (String(email || '').trim().toLowerCase() !== ADMIN_EMAIL) return json(403, { error: 'Conta não autorizada para esta configuração.' });
    if (typeof password !== 'string' || password.length < 8) return json(400, { error: 'A senha precisa ter pelo menos 8 caracteres.' });
    if (!secureEqual(setupSecret, configuredSecret)) return json(401, { error: 'Segredo de configuração inválido.' });

    const response = await fetch(`${SUPABASE_URL}/auth/v1/admin/users/${ADMIN_ID}`, {
      method: 'PUT',
      headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ password, email_confirm: true })
    });
    if (!response.ok) {
      const detail = await response.json().catch(() => ({}));
      throw new Error(detail.msg || detail.message || 'Não foi possível definir a senha.');
    }
    return json(200, { ok: true, message: 'Senha definida com sucesso.' });
  } catch (error) {
    return json(400, { error: error.message || 'Não foi possível concluir a configuração.' });
  }
};
