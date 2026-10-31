// 読み上げる全ての文（id と 読み替え後のテキスト）を JSON で標準出力へ出す
const fs=require('fs'), vm=require('vm'), path=require('path');
const root=path.join(__dirname,'..');
const ctx={}; vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(root,'speech.js'),'utf8')+'\n'+fs.readFileSync(path.join(root,'questions.js'),'utf8')+'\nthis.READ=READ;this.QUIZ=QUIZ;this.toSentences=toSentences;this.clipId=clipId;',ctx);
const {QUIZ,toSentences,clipId}=ctx;
const texts=[];
for(let n=1;n<=10;n++) texts.push(`第${n}問。`);
for(const lv in QUIZ) for(const q of QUIZ[lv]){
  texts.push(q.q);
  for(const pre of ['正解です。','ざんねん。','時間切れです。']) for(const a of ['まる','ばつ']) texts.push(`${pre}答えは${a}です。`+q.e);
}
for(let sc=0;sc<=10;sc++) for(const rk of ['EVエンジニア級！','EVマスター！','EV通！','EV見習い','ここから伸びしろ！']) texts.push(`結果は10問中${sc}問正解。`+rk);
texts.push('こんにちは。この声で読み上げます。','読み上げをオンにしました。');
const seen=new Map();
for(const t of texts) for(const s of toSentences(t)){ const id=clipId(s); if(seen.has(id)&&seen.get(id)!==s) throw new Error('id collision '+id); seen.set(id,s); }
console.log(JSON.stringify([...seen].map(([id,text])=>({id,text})),null,0));
