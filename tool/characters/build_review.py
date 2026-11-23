#!/usr/bin/env python3
"""Offline-compatible reviewer for all 550 Futbol Card character assets.

Builds a local, self-contained browser review interface using the repository's
original files. No face recognition, scraping, account details or API keys.
The reviewer visually verifies all positions; ambiguous images remain pending.

Run at repository root:
    python3 tool/characters/build_review.py
Then open tool/characters/review.html in a browser.
Review decisions can be exported as CSV and pasted over position_audit.csv.
"""
import csv
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / 'assets/v21/characters'
AUDIT = ROOT / 'tool/characters/position_audit.csv'
OUT = ROOT / 'tool/characters/review.html'
ROLES = ('GK', 'DEF', 'MID', 'FWD')

def main():
    if not ASSETS.is_dir():
        raise SystemExit(f'Assets directory missing: {ASSETS}')
    with AUDIT.open(encoding='utf-8-sig', newline='') as f:
        rows = list(csv.DictReader(f))
    if len(rows) != 550:
        raise SystemExit(f'Expected 550 rows, found {len(rows)}')
    filenames = [f'c{i:03d}.webp' for i in range(1, 551)]
    if [r['filename'] for r in rows] != filenames:
        raise SystemExit('Audit must have exact c001.webp…c550.webp ordering')
    missing = [n for n in filenames if not (ASSETS / n).is_file()]
    if missing:
        raise SystemExit(f'Missing {len(missing)} assets: {missing[:5]}')
    seeds = [
        {'id':r['filename'][1:4], 'file':r['filename'],
         'role':r['position'], 'status':r['review_status']}
        for r in rows
    ]
    page = r"""<!DOCTYPE html><html lang="tr"><meta charset="utf-8">
<title>Futbol Card Arena · 550 Karakter Mevki Denetimi</title>
<style>
:root{color-scheme:dark;font:15px system-ui;background:#100d21;color:#fff}
*{box-sizing:border-box}body{margin:0}header{position:sticky;top:0;background:#16112cf5;padding:16px 24px;z-index:3;border-bottom:1px solid #503b7e}
h1{font-size:21px;margin:0 0 10px}.controls{display:flex;flex-wrap:wrap;gap:10px;align-items:center}
select,input,button{background:#322450;border:1px solid #705c9c;border-radius:8px;color:white;padding:9px 11px;font:inherit}
button{cursor:pointer}button:hover{background:#6546a9}
main{padding:20px;display:grid;grid-template-columns:repeat(auto-fill,minmax(155px,1fr));gap:14px}
figure{margin:0;padding:8px;background:#241938;border-radius:12px;border:2px solid transparent}
figure.selected{border-color:#e8b84f}img{display:block;aspect-ratio:1;object-fit:contain;width:100%;background:#110e1f;border-radius:8px}
figcaption{display:flex;justify-content:space-between;margin:7px 0;font-weight:600}
.role{display:grid;grid-template-columns:repeat(4,1fr);gap:3px}
.role button{padding:7px 0;font-size:12px}button.active{background:#ba8628;color:#100b18;font-weight:800}
.badge{font-size:11px;color:#d6c3f4}.pending{color:#f9b66c}
.notice{font-size:13px;color:#c4b3dc;line-height:1.4;margin-top:8px}
</style>
<header>
<h1>Futbol Card Arena · 550 Karakter Mevki Denetimi</h1>
<div class="controls">
<label>Göster <select id="filter"><option value="all">Tümü</option><option value="pending">Onay bekleyenler</option><option value="reviewed">Onaylı</option><option value="GK">Kaleci</option><option value="DEF">Defans</option><option value="MID">Orta saha</option><option value="FWD">Forvet</option></select></label>
<label>Git <input id="jump" type="number" min="1" max="550" placeholder="Karakter #"></label>
<button id="export">CSV Dışa Aktar</button>
<button id="reset">CSV'den başlangıç durumuna dön</button>
<strong id="count"></strong>
</div><div class="notice">Her kartı görsel olarak doğrula. Bir mevki kanıtlanamıyorsa «?» olarak bırak. 1/2/3/4 ile Kaleci/Defans/Orta saha/Forvet, 0 ile belirsiz; sağ/sol oklarıyla gezin. Seçimler yalnız bu açık sekmede saklanır; çalışmayı korumak için CSV indir.</div>
</header><main id="cards"></main>
<script>
const original = __SEEDS__;
let data=original.map(x=>({...x}));let selected=0;
const root=document.getElementById('cards');
function update(id,role) {const x=data.find(v=>v.id===id); x.role=role;x.status=role?'reviewed':'pending';render()}
function render(){
const fil=document.getElementById('filter').value;root.textContent='';
for(const x of data){
if(fil!=='all' && fil!==x.status && fil!==x.role)continue;
const fig=document.createElement('figure');fig.id='card-'+x.id;
if(Number(x.id)===selected)fig.className='selected';
const img=document.createElement('img');img.loading='lazy';img.src='../../assets/v21/characters/'+x.file;img.alt=x.file;
fig.append(img);const cap=document.createElement('figcaption');
cap.innerHTML='<span>'+x.file+'</span><span class="'+(x.status==='pending'?'pending':'badge')+'">'+(x.status==='pending'?'Onaysız':x.role)+'</span>';fig.append(cap);
const row=document.createElement('div');row.className='role';
for(const [val,label] of [['GK','GK'],['DEF','DEF'],['MID','MID'],['FWD','FWD']]){const b=document.createElement('button');b.textContent=label;if(x.role===val)b.className='active';b.onclick=()=>{selected=Number(x.id);update(x.id,val)};row.append(b)}
fig.append(row);
const un=document.createElement('button');un.textContent='? Belirsiz';un.style.width='100%';un.style.marginTop='4px';un.onclick=()=>{selected=Number(x.id);update(x.id,'')};fig.append(un);
fig.onclick=(ev)=>{if(ev.target.tagName==='BUTTON')return; selected=Number(x.id);render()};
root.append(fig);
}document.getElementById('count').textContent=data.filter(x=>x.status==='reviewed').length+'/550 onaylı';
}
function focusTo(n){n=Math.max(1,Math.min(550,n));selected=n;document.getElementById('filter').value='all';render();document.getElementById('card-'+String(n).padStart(3,'0'))?.scrollIntoView({block:'center'})}
document.getElementById('filter').onchange=render;
document.getElementById('jump').onchange=e=>focusTo(+e.target.value);
document.onkeydown=e=>{if(e.target.tagName==='INPUT')return;
if(e.key==='ArrowRight')focusTo((selected||0)+1);
else if(e.key==='ArrowLeft')focusTo((selected||2)-1);
else if('01234'.includes(e.key)&&e.key.length===1){if(selected)update(String(selected).padStart(3,'0'),({0:'',1:'GK',2:'DEF',3:'MID',4:'FWD'})[e.key])}}
document.getElementById('reset').onclick=()=>{if(confirm('Bu sekmedeki onaylar sıfırlansın mı?')){data=original.map(x=>({...x}));render()}};
document.getElementById('export').onclick=()=>{
const lines=['filename,position,review_status,review_note',...data.map(x=>[x.file,x.role,x.status,x.status==='reviewed'?'Visually verified in review tool':'Pending visual verification'].join(','))];const blob=new Blob([lines.join('\n')+'\n'],{type:'text/csv;charset=utf-8'});
const link=document.createElement('a');link.href=URL.createObjectURL(blob);link.download='position_audit.csv';link.click();URL.revokeObjectURL(link.href)};
render();
</script></html>""".replace('__SEEDS__', json.dumps(seeds, ensure_ascii=False))
    OUT.write_text(page, encoding='utf-8')
    print('Wrote', OUT, 'with', len(rows), 'source illustrations.')

if __name__ == '__main__':
    main()
