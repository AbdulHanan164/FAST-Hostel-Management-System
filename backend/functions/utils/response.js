/**
 * Uniform response helpers for HTTP Cloud Functions.
 */
function ok(res, data = {}) {
  return res.status(200).json({ success: true, ...data });
}

function created(res, data = {}) {
  return res.status(201).json({ success: true, ...data });
}

function badRequest(res, message = 'Bad request') {
  return res.status(400).json({ success: false, message });
}

function unauthorized(res, message = 'Unauthorized') {
  return res.status(401).json({ success: false, message });
}

function notFound(res, message = 'Not found') {
  return res.status(404).json({ success: false, message });
}

function serverError(res, err) {
  console.error('[ServerError]', err);
  return res.status(500).json({ success: false, message: 'Internal server error' });
}

module.exports = { ok, created, badRequest, unauthorized, notFound, serverError };
