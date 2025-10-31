// frontend/server.js
const path = require("path");
const express = require("express");
const { createProxyMiddleware } = require("http-proxy-middleware");

const app = express();

// do NOT hardcode here – pick from env
const BACKEND = process.env.BACKEND_URL;
if (!BACKEND) {
  console.error(
    "ERROR: BACKEND_URL is not set. Start this server with BACKEND_URL=http://... node server.js"
  );
  process.exit(1);
}

// 1) proxy /api → backend ALB
app.use(
  "/api",
  createProxyMiddleware({
    target: BACKEND,
    changeOrigin: true,
    pathRewrite: { "^/api": "" },
  })
);

// 2) serve React build
const buildPath = "/opt/app/frontend/build";
app.use(express.static(buildPath));

// 3) SPA fallback
app.get("*", (req, res) => {
  res.sendFile(path.join(buildPath, "index.html"));
});

const port = 3000;
app.listen(port, () => {
  console.log(`frontend+proxy listening on ${port}, backend = ${BACKEND}`);
});
