const http = require('http');
const server = http.createServer((req, res) => {
  if (req.url === '/health') { res.writeHead(200); return res.end('ok'); }
  if (req.url === '/orders') { res.setHeader('content-type', 'application/json'); return res.end(JSON.stringify([{ id: 1, item: 'eggs' }])); }
  res.writeHead(404); res.end();
});
if (require.main === module) server.listen(process.env.PORT || 3000);
module.exports = server;
