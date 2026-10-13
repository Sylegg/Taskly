// Dependency-free fallback: serves the original fully interactive HTML for offline review.
import {createServer} from 'node:http';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
const file=resolve('public/reference/admin-original.html');
createServer((_req,res)=>{res.writeHead(200,{'content-type':'text/html; charset=utf-8'});res.end(readFileSync(file))}).listen(3000,'0.0.0.0',()=>console.log('TaskLy original demo: http://localhost:3000'));
