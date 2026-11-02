// classify() の確認：作ったポーズ（肩幅を 1 とした座標。+x がその人の左）で ○（左手を上げる）/ ×（右手を上げる）/ なし が合うか、ゆらぎに強いかを見る。
// 使い方: node tests/pose_test.js   （index.html から classify を取り出して動かす）
const fs=require('fs'); const src=fs.readFileSync(process.argv[2]||require('path').join(__dirname,'..','index.html'),'utf8');
const a=src.indexOf('function classify(lm, asp){'), b=src.indexOf('/* ============ 状態');
eval(src.slice(a,b).replace('function classify(','global.classify=function(').replace('function classifyInfo(','global.classifyInfo=function('));
const asp=16/9, S=0.13, cx=0.5*asp, cy=0.45;
function make(p, mir=1){ // p: {le,lw,re,rw,lt,rt,nose} in body units, person-left = +x
  const lm=Array.from({length:33},()=>({x:.5,y:.9,visibility:0.1}));
  const put=(i,[bx,by],v=0.95)=>{ lm[i]={x:(cx+bx*S*mir)/asp, y:cy+by*S, visibility:v}; };
  put(11,[0.5,0]); put(12,[-0.5,0]); put(0,p.nose||[0,-0.6],p.noseV??0.95);
  put(13,p.le,p.leV??p.eV??.9); put(14,p.re,p.reV??p.eV??.9); put(15,p.lw,p.lwV??p.wV??.9); put(16,p.rw,p.rwV??p.wV??.9);
  if(p.lt){ put(19,p.lt,.8); put(17,p.lt,.8); } if(p.rt){ put(20,p.rt,.8); put(18,p.rt,.8); }
  return lm; }
const sym=(e,w,t)=>({le:e,re:[-e[0],e[1]],lw:w,rw:[-w[0],w[1]],...(t?{lt:t,rt:[-t[0],t[1]]}:{})});
const cases=[
 ['neutral',null,sym([0.6,0.9],[0.6,1.8])],
 ['O left arm straight up','O',{le:[0.6,-0.9],lw:[0.6,-1.8],re:[-0.6,0.9],rw:[-0.6,1.8]}],
 ['O left arm bent up','O',{le:[1.0,-0.2],lw:[0.8,-1.0],re:[-0.6,0.9],rw:[-0.6,1.8]}],
 ['O left hand only to head height','O',{le:[0.9,-0.3],lw:[0.7,-0.65],re:[-0.6,0.9],rw:[-0.6,1.8]}],
 ['O left wrist off screen','O',{le:[0.6,-0.9],lw:[0.6,-1.8],re:[-0.6,0.9],rw:[-0.6,1.8],lwV:0.1}],
 ['O right arm out of frame','O',{le:[0.6,-0.9],lw:[0.6,-1.8],re:[-0.6,0.9],rw:[-0.6,1.8],reV:0.1,rwV:0.1}],
 ['X right arm straight up','X',{le:[0.6,0.9],lw:[0.6,1.8],re:[-0.6,-0.9],rw:[-0.6,-1.8]}],
 ['X right arm bent up','X',{le:[0.6,0.9],lw:[0.6,1.8],re:[-1.0,-0.2],rw:[-0.8,-1.0]}],
 ['X right hand over head','X',{le:[0.6,0.9],lw:[0.6,1.8],re:[-0.7,-0.8],rw:[-0.1,-1.7]}],
 ['both arms up',null,sym([0.8,-0.8],[0.8,-1.7])],
 ['O-shape both hands',null,sym([0.9,-0.9],[0.15,-1.6])],
 ['X cross in front',null,{le:[0.7,0.6],lw:[-0.6,-0.1],re:[-0.7,0.6],rw:[0.6,-0.05]}],
 ['hands on hips',null,sym([1.0,0.8],[0.6,1.45])],
 ['left hand at shoulder (not high enough)',null,{le:[0.8,0.5],lw:[0.6,-0.2],re:[-0.6,0.9],rw:[-0.6,1.8]}],
 ['T-pose',null,sym([1.2,0],[1.9,0])],
 ['hands front open',null,sym([0.7,0.7],[0.7,0.1])],
];
let fail=0;
for(const [name,exp,p] of cases) for(const mir of [1,-1]){
  const got=classifyInfo(make(p,mir),asp); const ok=got.label===exp; if(!ok) fail++;
  console.log((ok?'ok  ':'FAIL')+' '+name+(mir<0?' (mirror)':'')+' -> '+got.label+'  '+got.why);
}
// jitter robustness
let rnd=1; const r=()=>{rnd=(rnd*16807)%2147483647; return rnd/2147483647-0.5;};
for(const [name,exp,p] of cases){ let hit=0; const N=400;
  for(let k=0;k<N;k++){ const q={}; for(const key in p){ q[key]=Array.isArray(p[key])?[p[key][0]+r()*0.2,p[key][1]+r()*0.2]:p[key]; }
    if(classify(make(q),asp)===exp) hit++; }
  console.log(`jitter ${name}: ${(hit/N*100).toFixed(0)}%`); }
if(fail){ console.log(fail+" FAILED"); process.exitCode=1; } else console.log("ALL OK");
