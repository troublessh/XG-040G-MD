module("luci.controller.cputemp", package.seeall)

function index()
    entry({"admin", "status", "cputemp"}, call("action_page"), _("CPU Temperature"), 1)
end

function action_page()
    luci.http.prepare_content("text/html")
    luci.http.write([[
<!DOCTYPE html><html><head><meta charset="utf-8">
<title>CPU Temperature</title>
<style>
body{font-family:Arial,sans-serif;margin:20px;background:#f5f5f5}
.card{background:#fff;border-radius:8px;padding:20px;box-shadow:0 2px 4px rgba(0,0,0,0.1);max-width:300px}
.temp{font-size:2.5em;font-weight:bold;color:#e74c3c}
.label{color:#666;font-size:0.9em}
</style></head><body>
<div class="card">
<div class="label">CPU Temperature</div>
<div class="temp" id="t">--</div>
<div class="label" id="ts">--</div>
</div>
<script>
function u(){
  fetch('/cgi-bin/luci/admin/status/cputemp/json')
  .then(r=>r.json()).then(d=>{
    document.getElementById('t').innerHTML=d.temperature;
    document.getElementById('ts').innerHTML='Updated: '+new Date().toLocaleTimeString();
  }).catch(()=>{});
}
u();setInterval(u,5000);
</script></body></html>
]])
end
