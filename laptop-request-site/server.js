const http = require("http");
const fs = require("fs");
const path = require("path");

const mimeTypes = { ".html": "text/html", ".css": "text/css", ".js": "text/javascript", ".png": "image/png", ".jpg": "image/jpeg", ".svg": "image/svg+xml" };

const recommendations = [
  { title: "Take a walking meeting", summary: "Move one recurring catch-up outdoors or around the office.", category: "Move" },
  { title: "Protect a ten-minute pause", summary: "Block a short break between meetings to reset your attention.", category: "Recharge" },
  { title: "Join a community activity", summary: "Choose one social or volunteer event happening this month.", category: "Connect" }
];

const server = http.createServer((req, res) => {
  if (req.url === "/api/recommendations") {
    res.writeHead(200, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    res.end(JSON.stringify(recommendations));
    return;
  }

  let filePath = req.url === "/" ? "/wellbeing.html" : req.url;
  filePath = path.join(__dirname, filePath);
  const ext = path.extname(filePath);
  fs.readFile(filePath, (err, data) => {
    if (err) { res.writeHead(404); res.end("Not found"); return; }
    res.writeHead(200, { "Content-Type": mimeTypes[ext] || "text/plain" });
    res.end(data);
  });
});

server.listen(process.env.PORT || 8080, () => console.log("Zava Wellbeing running"));
