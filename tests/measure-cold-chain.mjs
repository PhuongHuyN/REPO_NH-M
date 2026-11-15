// Real SQL + actual esp32.js process. Sensor values and accelerated elapsed-time fixtures
// are simulations, never evidence of physical ESP32 testing or production availability.
import {createRequire} from 'node:module';
import {spawn} from 'node:child_process';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import crypto from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const require=createRequire(path.join(root,'app/api/package.json'));
const sql=require('mssql'),config=require('./src/config');
if(!/^FreshVend_QA/.test(config.db.database))throw Error('QA database required');
const base=process.env.API_URL||'http://127.0.0.1:32139';
const out=path.join(root,'docs/evidence/SCRUM-239/cold-chain');await mkdir(out,{recursive:true});
const pool=await sql.connect({server:config.db.server,port:config.db.port,database:config.db.database,
 user:config.db.logins.Admin.user,password:config.db.logins.Admin.password,options:{trustServerCertificate:true,encrypt:false}});
const rows=[],pause=ms=>new Promise(r=>setTimeout(r,ms));
const query=async text=>(await pool.request().query(text)).recordset;
const call=async(method,url,body,token)=>{const r=await fetch(base+url,{method,headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:body?JSON.stringify(body):undefined});const data=await r.json();if(!r.ok)throw Error(`${r.status}: ${data.message||data.error}`);return data;};
async function simulator(name,machine,flags=[],duration=2500){
 let log='';const proc=spawn(process.execPath,['app/simulator/esp32.js','--machines',String(machine),'--interval','0.2',...flags],
 {cwd:root,env:{...process.env,API_URL:base,DEVICE_API_KEY:config.deviceApiKey},windowsHide:true,stdio:['ignore','pipe','pipe']});
 proc.stdout.on('data',d=>{log+=d});proc.stderr.on('data',d=>{log+=d});
 try{await pause(duration);}finally{proc.kill();await new Promise(r=>proc.once('close',r));await writeFile(path.join(out,name+'.log'),log);}
 return log;
}
async function scenario(name,body){const r={name,startedAt:new Date().toISOString(),status:'NOT RUN'};try{const v=await body();Object.assign(r,v);r.status=v.passed?'PASS':'FAIL';}catch(e){r.status='BLOCKED';r.error=e.message;}r.completedAt=new Date().toISOString();rows.push(r);console.log(name,r.status);}
try{
 const health=await call('GET','/api/health');
 if(health.db?.mode!=='sqlserver'||health.db?.db!==config.db.database)throw Error('API must target the same real QA database');
 await scenario('KB1-normal',async()=>{
  const [before]=await query('SELECT COUNT(*) n FROM iot.Telemetry WHERE MachineId=1');
  await simulator('normal',1);
  const [after]=await query('SELECT COUNT(*) n,MIN(Temperature) lo,MAX(Temperature) hi FROM (SELECT TOP(5) Temperature FROM iot.Telemetry WHERE MachineId=1 ORDER BY ReadingId DESC) x');
  const [count]=await query('SELECT COUNT(*) n FROM iot.Telemetry WHERE MachineId=1');
  const [machine]=await query('SELECT Status FROM iot.Machines WHERE MachineId=1');
  return {passed:count.n>before.n&&after.lo>=2&&after.hi<=8&&machine.Status==='ACTIVE',before,after,machine};
 });
 await scenario('KB2-overheat',async()=>{
  await simulator('overheat',3,['--overheat','3'],4500);
  const actual=await query("SELECT m.Status,(SELECT COUNT(*) FROM iot.Alerts a WHERE a.MachineId=3 AND a.ResolvedAt IS NULL AND a.AlertType LIKE '%TEMP%') Alerts,(SELECT COUNT(*) FROM (SELECT TOP(3) Temperature FROM iot.Telemetry WHERE MachineId=3 ORDER BY ReadingId DESC) t WHERE Temperature>8) HotSamples FROM iot.Machines m WHERE MachineId=3");
  return {passed:actual[0]?.Status==='DEGRADED'&&actual[0]?.Alerts>0&&actual[0]?.HotSamples===3,actual,expected:'3 hot readings -> DEGRADED and open temperature alert'};
 });
 await scenario('KB3-door',async()=>{
  // Accelerate only the elapsed-time fixture; the simulator still sends live door-open packets.
  await query('INSERT iot.Telemetry(MachineId,RecordedAt,Temperature,DoorOpen) VALUES(2,DATEADD(MINUTE,-3,SYSUTCDATETIME()),4,1)');
  await simulator('door',2,['--door','2']);
  const actual=await query("SELECT COUNT(*) Alerts FROM iot.Alerts WHERE MachineId=2 AND AlertType='DOOR_OPEN' AND ResolvedAt IS NULL");
  return {passed:actual[0].Alerts>0,actual,expected:'DOOR_OPEN alert',acceleratedFixture:'one door-open reading timestamped 3 minutes earlier; not a 3-minute wall-clock test'};
 });
 await scenario('KB4-jam',async()=>{
  const login=await call('POST','/api/auth/login',{username:'kiosk01',password:'Kiosk@2026'});
  const [slot]=await query('SELECT TOP(1) s.SlotId FROM inventory.Slot s JOIN inventory.SlotStock ss ON ss.SlotId=s.SlotId JOIN inventory.StockBatch b ON b.BatchId=ss.BatchId WHERE s.MachineId=1 AND ss.Quantity>2 AND b.ExpiryAt>SYSUTCDATETIME() ORDER BY s.SlotId');
  if(!slot)throw Error('No live FIFO stock for jam test');
  const order=await call('POST','/api/orders',{machineId:1,items:[{columnId:slot.SlotId,qty:1}]},login.token);
  const id=order.OrderId||order.orderId;if(!id)throw Error('No OrderId returned');
  const [o]=await query(`SELECT TotalAmount FROM sales.[Order] WHERE OrderId=${Number(id)}`);
  const txn='QA239-'+id,signature=crypto.createHmac('sha256',config.paymentSecret).update(`${id}|${txn}|${o.TotalAmount}`).digest('hex');
  await call('POST','/api/payments/callback',{orderId:Number(id),method:'VIETQR',gatewayTxnId:txn,amount:o.TotalAmount,signature});
  await simulator('jam',1,['--jam','1'],6500);
  const actual=await query(`SELECT Status FROM sales.[Order] WHERE OrderId=${Number(id)}`);
  const attempts=await query(`SELECT d.Result,COUNT(*) n FROM sales.DispenseEvents d JOIN sales.OrderItem i ON i.OrderItemId=d.OrderItemId WHERE i.OrderId=${Number(id)} GROUP BY d.Result`);
  return {passed:actual[0]?.Status==='REFUNDED'&&attempts.some(x=>x.Result==='JAM'&&x.n>=3),orderId:id,actual,attempts,payment:'signed local callback; no real bank transaction'};
 });
 await scenario('KB5-offline-reconnect',async()=>{
  await query("UPDATE iot.Machines SET LastHeartbeat=DATEADD(MINUTE,-6,SYSUTCDATETIME()),Status='ACTIVE' WHERE MachineId=4");
  await simulator('offline',4,['--offline','4']);
  await query('EXEC iot.sp_CheckHeartbeat @Minutes=5');
  const offline=await query('SELECT Status FROM iot.Machines WHERE MachineId=4');
  await simulator('reconnect',4);
  const reconnect=await query('SELECT Status,LastHeartbeat FROM iot.Machines WHERE MachineId=4');
  return {passed:offline[0]?.Status==='OFFLINE'&&reconnect[0]?.Status==='ACTIVE',offline,reconnect,acceleratedFixture:'heartbeat timestamp -6 minutes and manual heartbeat job; job scheduler and 5-minute wall clock not tested'};
 });
}finally{
 await pool.close();
 await writeFile(path.join(out,'results.json'),JSON.stringify({database:config.db.database,source:'actual app/simulator/esp32.js + real SQL; simulated sensors, no physical hardware',rows},null,2));
}
if(rows.length!==5||rows.some(x=>x.status!=='PASS'))process.exitCode=2;
