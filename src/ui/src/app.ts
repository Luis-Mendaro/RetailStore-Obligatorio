import express from 'express';
import path from 'path';
import { createProxyMiddleware } from 'http-proxy-middleware';

const app = express();

const CATALOG_URL  = process.env.RETAIL_UI_ENDPOINTS_CATALOG  || 'http://catalog:8080';
const CARTS_URL    = process.env.RETAIL_UI_ENDPOINTS_CARTS    || 'http://carts:8080';
const CHECKOUT_URL = process.env.RETAIL_UI_ENDPOINTS_CHECKOUT || 'http://checkout:8080';
const ORDERS_URL   = process.env.RETAIL_UI_ENDPOINTS_ORDERS   || 'http://orders:8080';

// Express strips the mount path before the proxy sees it.
// pathRewrite re-adds the service prefix, stripping trailing slash on bare paths.
const rewrite = (prefix: string) => (p: string) => prefix + (p === '/' ? '' : p);

app.use('/api/catalog',  createProxyMiddleware({ target: CATALOG_URL,  changeOrigin: true, pathRewrite: rewrite('/catalog') }));
app.use('/api/carts',    createProxyMiddleware({ target: CARTS_URL,    changeOrigin: true, pathRewrite: rewrite('/carts') }));
app.use('/api/checkout', createProxyMiddleware({ target: CHECKOUT_URL, changeOrigin: true, pathRewrite: rewrite('/checkout') }));
app.use('/api/orders',   createProxyMiddleware({ target: ORDERS_URL,   changeOrigin: true, pathRewrite: rewrite('/orders') }));

app.use(express.static(path.join(__dirname, '../public')));

app.get('/health', (_req, res) => res.send('OK'));

const port = parseInt(process.env.PORT || '8080', 10);
app.listen(port, () => console.log(`UI listening on :${port}`));
