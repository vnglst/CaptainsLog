import { AudioCapture } from './audio-capture.mjs';
import { textStatus, reviewQueue } from './review-passages.mjs';
import { reviewLocation } from './review-session.mjs';
'use strict';
const $=id=>document.getElementById(id);
let locationQueue=Promise.resolve(),lastLocation=null;
let lifecycle={},data,reviews={},recording,selected=null,full=false,saveTimer=null,saveQueue=Promise.resolve(),dirty=new Set();
let capture=null,draft=null,draftURL=null,capturePhase='idle',captureGeneration=0,uploading=false,building=false,consolidations=[];
let previewWindow=null;
const precise=s=>{const ticks=Math.round(s*100);return `${String(Math.floor(ticks/6000)).padStart(2,'0')}:${((ticks%6000)/100).toFixed(2).padStart(5,'0')}`};
const parseTime=value=>{const parts=value.trim().split(':');return parts.length===2&&/^\d+$/.test(parts[0])&&/^\d{1,2}(?:\.\d+)?$/.test(parts[1])&&Number(parts[1])<60?Number(parts[0])*60+Number(parts[1]):parts.length===1&&/^\d+(?:\.\d+)?$/.test(parts[0])?Number(parts[0]):NaN};
const originalPosition=()=>full?el.audio.currentTime:current().start_seconds+el.audio.currentTime-bounds().start;
const audioBusy=()=>capturePhase!=='idle'||draft!==null||uploading;
const labels={pending:'Not checked',matches:'Reference confirmed',corrected:'Correction supplied',uncertain:'Needs another listen',misaligned:'Audio and text don’t line up'};
const el={audio:$('audio'),words:$('words'),notes:$('notes')};
const fmt=s=>`${String(Math.floor(s/60)).padStart(2,'0')}:${String(Math.floor(s%60)).padStart(2,'0')}`;
const current=()=>queue().find(p=>p.id===selected);
const bounds=()=>full?{start:0,end:recording.duration}:{start:current().clip_start??0,end:current().clip_end??current().end_seconds-current().start_seconds};
function updateTransport(){if(!recording)return;const b=bounds(),length=b.end-b.start,position=Math.max(0,Math.min(length,el.audio.currentTime-b.start));$('clipSeek').max=length;$('clipSeek').value=position;$('clipTime').textContent=fmt(position)+' / '+fmt(length)+' · Original '+precise(originalPosition());$('playPause').textContent=el.audio.paused?'Play':'Pause'}
function positionAudio(){previewWindow=null;try{el.audio.currentTime=bounds().start}catch{}updateTransport()}
function passageContext(id){for(const r of data.recordings){const p=r.passages.find(p=>p.id===id);if(p)return p.context}return null}

const review=id=>reviews[id]||{status:'pending',words:'',notes:''};
function saveMessage(text,error=false){$('saveState').textContent=text;$('saveState').classList.toggle('error',error)}
function tokens(text){return [...text.matchAll(/[\p{L}\p{M}\p{N}]+(?:['’][\p{L}\p{M}\p{N}]+)*/gu)].map(m=>({word:m[0].normalize('NFC').toLocaleLowerCase('en').replaceAll('’',"'"),start:m.index,end:m.index+m[0].length}))}
function reading(node,text,reference){
 node.replaceChildren();
 if(!text){const span=document.createElement('span');span.className='placeholder';span.textContent=text==null?'No saved transcript for this case.':'No words aligned in this passage.';node.append(span);return}
 if(!reference||text.length>18000){node.textContent=text;return}
 const a=tokens(reference),b=tokens(text);if(a.length*b.length>2500000){node.textContent=text;return}
 const width=b.length+1,trace=new Uint8Array((a.length+1)*width);let prev=Array.from({length:width},(_,i)=>i);
 for(let j=1;j<width;j++)trace[j]=3;
 for(let i=1;i<=a.length;i++){const row=new Uint32Array(width);row[0]=i;trace[i*width]=2;for(let j=1;j<width;j++){const d=prev[j-1]+(a[i-1].word===b[j-1].word?0:1),del=prev[j]+1,ins=row[j-1]+1;row[j]=Math.min(d,del,ins);trace[i*width+j]=row[j]===d?1:row[j]===del?2:3}prev=row}
 const changed=new Set();let i=a.length,j=b.length;while(i||j){const d=trace[i*width+j];if(d===1){i--;j--;if(a[i].word!==b[j].word)changed.add(j)}else if(d===2)i--;else{j--;changed.add(j)}}
 let pos=0;for(let k=0;k<b.length;k++){const t=b[k];node.append(document.createTextNode(text.slice(pos,t.start)));if(changed.has(k)){const mark=document.createElement('mark');mark.textContent=text.slice(t.start,t.end);node.append(mark)}else node.append(document.createTextNode(text.slice(t.start,t.end)));pos=t.end}node.append(document.createTextNode(text.slice(pos)));
}
function rememberLocation(location){const key=JSON.stringify(location);if(key===lastLocation)return;lastLocation=key;locationQueue=locationQueue.catch(()=>{}).then(async()=>{const response=await fetch('/api/location',{method:'POST',headers:{'Content-Type':'application/json'},body:key,keepalive:true});if(!response.ok)throw new Error('Location not saved')}).catch(()=>{if(lastLocation===key)lastLocation=null})}
function queue(){return reviewQueue(recording.passages)}
function renderRail(){
 const replaced=new Set([...(lifecycle[recording.id]?.replaced_passages||[]),...(lifecycle[recording.id]?.carried_passages||[])]);const done=recording.passages.filter(p=>replaced.has(p.id)||['matches','corrected'].includes(review(p.id).status)&&!review(p.id).audio_issue).length;
 $('progress').textContent=`${done} of ${recording.passages.length} passages verified`;$('progressBar').style.width=`${recording.passages.length?done/recording.passages.length*100:0}%`;
 const nav=$('passages');nav.replaceChildren();let count=0;
 for(const p of queue()){const r=review(p.id);if($('onlyPending').checked&&(replaced.has(p.id)||['matches','corrected'].includes(r.status)&&!r.audio_issue))continue;count++;const button=document.createElement('button');button.className='passage';button.setAttribute('aria-current',String(!full&&p.id===selected));const status=document.createElement('span');status.className='p-status'+(replaced.has(p.id)?' done':r.audio_issue?' issue':['matches','corrected'].includes(r.status)?' done':'');status.textContent=replaced.has(p.id)?'✓':r.audio_issue?'!':r.status==='matches'?'✓':r.status==='corrected'?'✓':r.status==='misaligned'?'!':r.status==='uncertain'?'?':'○';const body=document.createElement('span');body.textContent=p.title;const time=document.createElement('span');time.className='p-time';time.textContent=`${fmt(p.start_seconds)}–${fmt(p.end_seconds)}`;body.append(time);button.append(status,body);button.addEventListener('click',()=>navigateTo(p.id));nav.append(button)}
 if(!count){const p=document.createElement('p');p.className='empty';p.textContent=queue().length?'All passages checked. Turn off Unreviewed only to revisit them.':'No text differences found. You can still listen to the full recording.';nav.append(p)}
}
function updateDecision(){if(full)return;const r=review(selected);for(const b of document.querySelectorAll('[data-decision]'))b.setAttribute('aria-pressed',String(b.dataset.decision===r.status));$('reviewStatus').textContent=r.audio_issue?'Original audio needs correction':labels[r.status];$('formHelp').classList.remove('error');$('formHelp').textContent=r.status==='misaligned'?'Flagged for an alignment fix. No explanation needed; you can save and move on.':'Choose a decision after listening. Text edits are saved automatically.'}
function render(){
 const p=full?null:current();if(!full&&!p){selected=queue()[0]?.id;if(!selected)full=true;return render()}
 const main=$('main'),context=$('originalContextBody');
 $('originalContext').hidden=!full;
 if(full){main.insertBefore($('consolidation'),$('originalContext'));for(const node of [document.querySelector('.listening'),$('question'),$('comparison'),$('comparisonNote')])context.append(node)}
 else{for(const node of [document.querySelector('.listening'),$('question'),$('audioRepair'),$('comparison'),$('comparisonNote')])main.insertBefore(node,$('reviewForm'))}
 document.querySelector('.nav-buttons').hidden=full;
 $('overview').hidden=true;$('workspace').hidden=false;$('reviewBreadcrumb').textContent=recording.title;
 $('recording').value=recording.id;$('recordingMeta').textContent=`${recording.language} • ${fmt(recording.duration)} • ${recording.passages.length} review passages`;
 $('passageTitle').textContent=full?recording.title:p.title;$('passageTime').textContent=full?'Full recording':`${p.short_id||'Passage'} • ${fmt(p.start_seconds)}–${fmt(p.end_seconds)}`;
 $('originalTime').textContent=full?`${fmt(recording.duration)} total`:`From ${fmt(p.start_seconds)} in the original recording`;
 $('audioTitle').textContent=full?'Listen with the full transcript':'Listen to this passage';
 el.audio.pause();const source=full?recording.audio:p.audio;if(el.audio.getAttribute('src')!==source){el.audio.src=source;el.audio.load()}else positionAudio();
 el.audio.loop=false;el.audio.playbackRate=Number($('speed').value);updateTransport();
 $('question').textContent=full?'Use the full recording for context, or choose a passage to check its wording.':p.check;
 const ref=full?recording.reference:p.reference;
 reading($('reference'),ref,full?recording.app_transcript:p.app_transcript);reading($('appTranscript'),full?recording.app_transcript:p.app_transcript,ref);reading($('secondTranscript'),full?recording.second_transcript:p.second_transcript,ref);
 $('appLabel').textContent=recording.app_label||'Saved evaluation transcript';$('comparisonLabel').textContent=recording.comparison_label||'Comparison run';const hasComparison=recording.second_transcript!=null;$('comparisonColumn').hidden=!hasComparison;$('comparison').classList.toggle('two-columns',!hasComparison);
 $('comparisonNote').textContent=full?'Colored words differ from the current reference. These are model outputs, not verified speech.':'Colored words differ from the reference excerpt. Text alignment and clip boundaries are approximate; listen for the actual wording.';
 $('reviewForm').hidden=full;$('fullNotice').hidden=!full;
 if(!full){const r=review(selected);el.words.value=r.words;el.notes.value=r.notes;updateDecision()}
 const list=queue(),index=list.findIndex(x=>x.id===selected);$('previous').disabled=!full&&index<=0;$('next').disabled=!full&&(index<0||index>=list.length-1);
 renderRail();renderRepair();renderConsolidations();applyLifecycle();rememberLocation({recording:recording.id,passage:full?'full':selected});history.replaceState(null,'',`#recording=${encodeURIComponent(recording.id)}&passage=${full?'full':encodeURIComponent(selected)}`);
}
async function persist(id){
 const value={id,...review(id),context:passageContext(id)};if(value.status==='corrected'&&!value.words.trim()){saveMessage('Add the corrected wording before saving',true);throw new Error('Missing corrected words')}
 saveMessage('Saving…');
 const task=async()=>{const response=await fetch('/api/state',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(value)});if(!response.ok){const error=await response.json();throw new Error(error.error||'Save failed')}const saved=await response.json();if(['status','words','notes','audio_issue','accepted_take_id'].every(k=>review(id)[k]===value[k])){reviews[id]={...saved,retakes:mergeTakes(saved.retakes,review(id).retakes)};dirty.delete(id)}saveMessage(dirty.size?'Saving…':'Saved on this Mac');await refreshLifecycle();};
 saveQueue=saveQueue.catch(()=>{}).then(task);try{await saveQueue}catch(error){saveMessage(error.message,true);throw error}
}
async function flush(){clearTimeout(saveTimer);for(const id of [...dirty])await persist(id);await saveQueue.catch(()=>{})}
function changed(){if(full)return;reviews[selected]={...review(selected),words:el.words.value,notes:el.notes.value};dirty.add(selected);const id=selected;clearTimeout(saveTimer);saveTimer=setTimeout(()=>persist(id).catch(()=>{}),650)}
async function navigateTo(id,showFull=false){if(audioBusy()){$('captureStatus').textContent='Save or discard this take before changing passages.';return}try{await flush()}catch{return}selected=id||selected;if(!queue().some(p=>p.id===selected))selected=queue()[0]?.id;full=showFull||!selected;history.pushState(null,'',`#recording=${encodeURIComponent(recording.id)}&passage=${full?'full':encodeURIComponent(selected)}`);render()}
async function step(direction){const list=queue(),i=list.findIndex(p=>p.id===selected);if(full){if(list.length)await navigateTo(list[0].id);return}const p=list[i+direction];if(p)await navigateTo(p.id)}
$('recording').addEventListener('change',async event=>{const id=event.target.value;if(audioBusy()){$('recording').value=recording.id;$('captureStatus').textContent='Save or discard this take before changing recordings.';return}try{await flush()}catch{$('recording').value=recording.id;return}recording=data.recordings.find(r=>r.id===id);selected=queue()[0]?.id;full=!selected;history.pushState(null,'',`#recording=${encodeURIComponent(recording.id)}&passage=${encodeURIComponent(selected)}`);render()});
$('onlyPending').addEventListener('change',renderRail);$('fullRecording').addEventListener('click',()=>navigateTo(selected,true));$('previous').addEventListener('click',()=>step(-1));$('next').addEventListener('click',()=>step(1));
$('back3').addEventListener('click',()=>{previewWindow=null;el.audio.currentTime=Math.max(bounds().start,el.audio.currentTime-3)});$('replay').addEventListener('click',()=>{previewWindow=null;el.audio.currentTime=bounds().start;el.audio.play().catch(()=>{})});$('speed').addEventListener('change',()=>{el.audio.playbackRate=Number($('speed').value)});
for(const b of document.querySelectorAll('[data-decision]'))b.addEventListener('click',()=>{reviews[selected]={...review(selected),status:b.dataset.decision,words:el.words.value,notes:el.notes.value};dirty.add(selected);updateDecision();renderRail();if(b.dataset.decision==='corrected'&&!el.words.value.trim()){el.words.focus();$('formHelp').textContent='Write the corrected phrase, then save it.';return}persist(selected).catch(()=>{})});
$('playPause').addEventListener('click',()=>{if(el.audio.paused){previewWindow=null;if(el.audio.currentTime>=bounds().end-.05)el.audio.currentTime=bounds().start;el.audio.play().catch(()=>{})}else el.audio.pause()});
$('clipSeek').addEventListener('input',()=>{previewWindow=null;el.audio.currentTime=bounds().start+Number($('clipSeek').value);updateTransport()});
el.audio.addEventListener('loadedmetadata',positionAudio);el.audio.addEventListener('play',()=>{pauseOtherAudio(el.audio);updateTransport()});el.audio.addEventListener('pause',updateTransport);
el.audio.addEventListener('timeupdate',()=>{const b=previewWindow||bounds();if(el.audio.currentTime>=b.end-.03){if($('loop').checked&&!el.audio.paused){el.audio.currentTime=b.start;el.audio.play().catch(()=>{})}else el.audio.pause()}updateTransport()});
el.words.addEventListener('input',changed);el.notes.addEventListener('input',changed);
$('saveNext').addEventListener('click',async()=>{if(review(selected).status==='pending'&&!review(selected).audio_issue){$('formHelp').textContent='Choose a decision after listening.';$('formHelp').classList.add('error');return}try{await flush()}catch{return}if(queue().at(-1)?.id===selected){await showOverview();return}await step(1)});
$('export').addEventListener('click',async()=>{try{await flush()}catch{return}const savedState=await(await fetch('/api/state')).json();const result={version:1,archived_reviews:savedState.archived_reviews||{},consolidations:savedState.consolidations||[],exported_at:new Date().toISOString(),recordings:data.recordings.map(r=>({id:r.id,name:r.name,reference_sha256:r.reference_sha256,audio_sha256:r.audio_sha256,passages:r.passages.map(p=>({id:p.id,start_seconds:p.start_seconds,end_seconds:p.end_seconds,reference:p.reference,...review(p.id)}))}))};const url=URL.createObjectURL(new Blob([JSON.stringify(result,null,2)+'\n'],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download='captainslog-transcription-review.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)});
window.addEventListener('beforeunload',event=>{if(dirty.size||audioBusy()){event.preventDefault();event.returnValue=''}});
(async()=>{try{const results=await Promise.all([fetch('recordings.json',{cache:'no-store'}),fetch('/api/state',{cache:'no-store'})]);for(const r of results)if(!r.ok)throw new Error('Could not load the local review');data=await results[0].json();const state=await results[1].json();reviews=state.reviews||{};consolidations=state.consolidations||[];await refreshLifecycle();for(const r of data.recordings){const option=document.createElement('option');option.value=r.id;option.textContent=r.title;$('recording').append(option)}let hash=new URLSearchParams(location.hash.slice(1)),savedLocation=null;if(!hash.has('recording')&&!hash.has('view')){try{const response=await fetch('/api/location',{cache:'no-store'});if(response.ok)savedLocation=(await response.json()).location}catch{}}hash=reviewLocation(hash,savedLocation,data.recordings);recording=data.recordings.find(r=>r.id===hash.get('recording'))||data.recordings[0];full=hash.get('passage')==='full';selected=recording.passages.some(p=>p.id===hash.get('passage'))?hash.get('passage'):recording.passages[0]?.id;if(!queue().some(p=>p.id===selected))selected=queue()[0]?.id;if(!selected)full=true;if(hash.get('recording'))render();else await showOverview(false);saveMessage('Saved on this Mac')}catch(error){saveMessage(error.message,true);$('passageTitle').textContent='Could not open the review';$('question').textContent='Keep the local server running and reload this page.'}})();

function mergeTakes(a=[],b=[]){const result=new Map();for(const take of [...b,...a]){const prior=result.get(take.id);if(!prior||(take.range_revision||0)>=(prior.range_revision||0))result.set(take.id,take)}return [...result.values()]}
function pauseOtherAudio(active){if(active!==el.audio)el.audio.pause();for(const player of document.querySelectorAll('.retake-player'))if(player!==active)player.pause()}
function addAudio(parent,url){const player=document.createElement('audio');player.controls=true;player.preload='metadata';player.className='retake-player';player.src=url;player.addEventListener('play',()=>pauseOtherAudio(player));parent.append(player);return player}
function renderRepair(){
 $('audioRepair').hidden=full;if(full)return;
 const p=current(),r=review(selected);$('audioIssue').checked=!!r.audio_issue;$('retakeTools').hidden=!r.audio_issue&&!(r.retakes||[]).length;
 $('replaceStart').min=p.start_seconds;$('replaceStart').max=p.end_seconds;$('replaceEnd').min=p.start_seconds;$('replaceEnd').max=p.end_seconds;
 if(!audioBusy()){$('replaceStart').value=precise(p.start_seconds);$('replaceEnd').value=precise(p.end_seconds);$('rangeStatus').textContent=''}
 const takes=$('savedTakes');takes.replaceChildren();
 for(const [i,take] of (r.retakes||[]).entries()){
  const row=document.createElement('div');row.className='saved-take';const title=document.createElement('strong');title.textContent=`Take ${i+1} · ${fmt(take.duration_seconds)} · replaces ${fmt(take.replace_start_seconds)}–${fmt(take.replace_end_seconds)}`;row.append(title);addAudio(row,take.audio);
  const chosen=r.accepted_take_id===take.id;row.classList.toggle('selected-take',chosen);
  const selection=document.createElement('div');selection.className='take-selection';
  const state=document.createElement('span');state.className=chosen?'selection-status selected':'selection-status';state.textContent=chosen?'✓ Selected for corrected recording':'Not selected';selection.append(state);
  const choice=document.createElement('button');choice.className=chosen?'':'primary';choice.textContent=chosen?'Remove selection':`Use take ${i+1}`;choice.disabled=audioBusy();choice.addEventListener('click',async()=>{const id=selected;choice.disabled=true;reviews[id]={...review(id),accepted_take_id:chosen?null:take.id};dirty.add(id);try{await persist(id);if(selected===id&&!full)renderRepair();renderConsolidations()}catch{choice.disabled=false}});selection.append(choice);row.append(selection);

  const range=document.createElement('div');range.className='retake-range';const inputs=[];for(const [name,value] of [['From',take.replace_start_seconds],['To',take.replace_end_seconds]]){const label=document.createElement('label');label.textContent=name+' ';const input=document.createElement('input');input.type='number';input.step='0.01';input.value=value;input.min=p.start_seconds;input.max=p.end_seconds;input.setAttribute('aria-label',`${name} seconds for take ${i+1}`);label.append(input);range.append(label);inputs.push(input)}const update=document.createElement('button');update.textContent='Update range';update.addEventListener('click',async()=>{const id=selected;try{await flush();const response=await fetch('/api/state',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id,...review(id),context:passageContext(id),retake_ranges:{[take.id]:{start:Number(inputs[0].value),end:Number(inputs[1].value)}}})});const saved=await response.json();if(!response.ok)throw new Error(saved.error);const local=review(id),pending=dirty.has(id);reviews[id]={...saved,retakes:mergeTakes(saved.retakes,local.retakes),...(pending?{words:local.words,notes:local.notes,status:local.status}:{})};if(selected===id&&!full){renderRepair();$('captureStatus').textContent='Replacement range saved.'}}catch(error){$('captureStatus').textContent=error.message}});range.append(update);row.append(range);
  const link=document.createElement('a');link.href=take.audio;link.download=`${recording.name}-take-${i+1}.wav`;link.textContent='Download take';row.append(link);takes.append(row);
 }
 updateCaptureControls();
}
function updateCaptureControls(){
 const list=queue(),index=list.findIndex(p=>p.id===selected);
 const active=capturePhase!=='idle';$('captureControls').classList.toggle('capturing',active);document.body.classList.toggle('capture-active',active);$('recordRetake').disabled=active||!!draft||uploading;$('stopRetake').hidden=!active;$('stopRetake').disabled=capturePhase==='finishing';$('stopRetake').textContent=capturePhase==='requesting'?'Cancel request':'Stop recording';$('saveRetake').disabled=uploading;$('discardRetake').disabled=uploading;$('audioIssue').disabled=audioBusy();$('draftTake').hidden=!draft;
 for(const button of document.querySelectorAll('#passages button,#previous,#next,#fullRecording,#openExports,#nextCorrection,.take-selection button'))button.disabled=audioBusy()||button.id==='previous'&&!full&&index<=0||button.id==='next'&&!full&&(index<0||index>=list.length-1);
 $('microphone').disabled=audioBusy();$('refreshMicrophones').disabled=audioBusy();$('recording').disabled=audioBusy();$('buildCorrected').disabled=building||audioBusy()||!recording.passages.some(p=>review(p.id).accepted_take_id);
}
function clearDraft(){if(draftURL)URL.revokeObjectURL(draftURL);draft=null;draftURL=null;$('draftAudio').removeAttribute('src');$('draftAudio').load();updateCaptureControls()}
function validateRange(){const start=parseTime($('replaceStart').value),end=parseTime($('replaceEnd').value),p=current();if(!Number.isFinite(start)||!Number.isFinite(end)||start<p.start_seconds||end>p.end_seconds||start>=end)throw new Error('Choose a start/end range inside this passage.');return {start,end}}

for(const [button,field] of [['markStart','replaceStart'],['markEnd','replaceEnd']])$(button).addEventListener('click',()=>{el.audio.pause();$(field).value=precise(Math.max(current().start_seconds,Math.min(current().end_seconds,originalPosition())));previewWindow=null;try{const r=validateRange();$('rangeStatus').textContent=`Selected ${precise(r.start)}–${precise(r.end)} · ${(r.end-r.start).toFixed(2)} seconds`}catch(error){$('rangeStatus').textContent=error.message}});
$('resetRange').addEventListener('click',()=>{previewWindow=null;$('replaceStart').value=precise(current().start_seconds);$('replaceEnd').value=precise(current().end_seconds);$('rangeStatus').textContent='Whole passage selected.'});
$('previewRange').addEventListener('click',()=>{try{const r=validateRange(),b=bounds();previewWindow={start:b.start+r.start-current().start_seconds,end:b.start+r.end-current().start_seconds};el.audio.currentTime=previewWindow.start;$('rangeStatus').textContent=`Playing ${precise(r.start)}–${precise(r.end)}`;el.audio.play().catch(error=>{$('rangeStatus').textContent=error.message})}catch(error){$('rangeStatus').textContent=error.message}});

$('audioIssue').addEventListener('change',()=>{reviews[selected]={...review(selected),audio_issue:$('audioIssue').checked};dirty.add(selected);updateDecision();renderRail();renderRepair();persist(selected).catch(()=>{})});
$('recordRetake').addEventListener('click',async()=>{
 const generation=++captureGeneration;try{
  validateRange();pauseOtherAudio(null);capturePhase='requesting';$('captureStatus').textContent='Waiting for microphone permission…';updateCaptureControls();
  capture=new AudioCapture({deviceId:$('microphone').value,onProgress:seconds=>{if(generation===captureGeneration)$('captureStatus').textContent=`Recording ${fmt(seconds)} (ten minutes maximum)`},onComplete:result=>{
   if(generation!==captureGeneration||!result)return;capturePhase='idle';draft=result;draftURL=URL.createObjectURL(result.blob);$('draftAudio').src=draftURL;$('downloadDraft').href=draftURL;$('captureStatus').textContent='Listen to this take, then save or discard it.';updateCaptureControls();
  },onError:error=>{if(generation===captureGeneration){capturePhase='idle';$('captureStatus').textContent=error.message;updateCaptureControls()}}});
  await capture.start();if(generation===captureGeneration){capturePhase='recording';refreshMicrophones();$('captureStatus').textContent='Recording 00:00';updateCaptureControls()}
 }catch(error){if(generation===captureGeneration){capturePhase='idle';$('captureStatus').textContent=error.name==='OverconstrainedError'||error.name==='NotFoundError'?'The selected microphone is unavailable. Choose another recording device.':error.name==='NotAllowedError'?'Microphone access was denied. Allow it in the browser, then try again.':error.message;updateCaptureControls()}}
});
$('stopRetake').addEventListener('click',async()=>{if(capturePhase==='requesting'){captureGeneration++;capture?.cancel();capturePhase='idle';$('captureStatus').textContent='Recording cancelled.';updateCaptureControls();return}capturePhase='finishing';$('captureStatus').textContent='Preparing recording…';updateCaptureControls();try{await capture.stop()}catch{}});
$('discardRetake').addEventListener('click',()=>{captureGeneration++;capture?.cancel();clearDraft();$('captureStatus').textContent='Unsaved take discarded.'});
$('draftAudio').addEventListener('play',()=>pauseOtherAudio($('draftAudio')));
const base64=blob=>new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(String(reader.result).split(',')[1]);reader.onerror=()=>reject(new Error('Could not read the recording.'));reader.readAsDataURL(blob)});
$('saveRetake').addEventListener('click',async()=>{
 const id=selected;try{const range=validateRange();await flush();uploading=true;$('captureStatus').textContent='Saving replacement…';updateCaptureControls();
  const response=await fetch('/api/retakes',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id,context:passageContext(id),replace_start_seconds:range.start,replace_end_seconds:range.end,audio_base64:await base64(draft.blob)})});const saved=await response.json();if(!response.ok)throw new Error(saved.error||'Could not save replacement');
  const local=review(id),pending=dirty.has(id);reviews[id]={...saved,retakes:mergeTakes(saved.retakes,local.retakes),...(pending?{words:local.words,notes:local.notes,status:local.status}:{})};uploading=false;clearDraft();$('captureStatus').textContent='Replacement saved. Preview it and select it below to include it.';renderRepair();updateDecision();renderRail();renderConsolidations();
 }catch(error){uploading=false;$('captureStatus').textContent=error.message;updateCaptureControls()}
});
function renderConsolidations(){
 $('consolidation').hidden=!full;$('nextAction').hidden=full||!recording.passages.some(p=>(review(p.id).retakes||[]).length);
 const pendingTakes=recording.passages.filter(p=>(review(p.id).retakes||[]).length&&!review(p.id).accepted_take_id);
 const selectedTakes=recording.passages.filter(p=>review(p.id).accepted_take_id);
 $('nextActionTitle').textContent=pendingTakes.length?`${pendingTakes.length} recorded correction${pendingTakes.length===1?' needs':'s need'} a selection`:selectedTakes.length?'Ready to build your corrected recording':'Review the recording';
 $('nextActionHelp').textContent=pendingTakes.length?'Listen to the saved takes, then click Use take. Only selected takes are included.':selectedTakes.length?`${selectedTakes.length} passage correction(s) selected. Build one recording with these replacements.`:'Listen to each passage. If you record a replacement, select the take you want to use.';
 $('nextCorrection').textContent=pendingTakes.length?'Choose recorded correction':full?'Go to passages':'Review selections & build';
 $('nextCorrection').disabled=audioBusy();
 const overview=$('selectionOverview');overview.replaceChildren();
 for(const p of recording.passages.filter(p=>(review(p.id).retakes||[]).length)){
  const line=document.createElement('div');line.className='selection-overview-row';const text=document.createElement('span');const r=review(p.id),index=(r.retakes||[]).findIndex(t=>t.id===r.accepted_take_id);text.textContent=`${p.short_id} · ${p.title} — ${index>=0?'Take '+(index+1)+' selected':'No take selected; original audio will be kept'}`;
  const button=document.createElement('button');button.textContent=index>=0?'Change take':'Choose take';button.className=index>=0?'':'primary';button.disabled=audioBusy();button.addEventListener('click',()=>navigateTo(p.id));line.append(text,button);overview.append(line);
 }

 const selections=recording.passages.filter(p=>review(p.id).accepted_take_id);
 $('selectedCount').textContent=`(${selections.length})`;
 const exports=consolidations.filter(x=>x.recording_id===recording.id).slice().reverse(),latest=exports[0];
 const matches=item=>Object.keys(item.selections||{}).length===selections.length&&selections.every(p=>item.selections[p.id]===review(p.id).accepted_take_id);
 if(latest&&matches(latest)&&!pendingTakes.length){$('nextActionTitle').textContent='Your corrected recording is ready';$('nextActionHelp').textContent='Listen to the combined recording and check the result.';$('nextCorrection').textContent='Listen to corrected recording'}
 $('consolidationSummary').textContent=latest&&matches(latest)?'Your selected replacements are combined. Listen below to check the result.':latest?'Your selections have changed. Build again to include them.':`${selections.length} replacement(s) selected. Build one recording to listen to the result.`;
 $('buildCorrected').textContent=building?'Building…':latest&&matches(latest)?'Rebuild recording':'Build corrected recording';
 $('buildCorrected').disabled=building||audioBusy()||!selections.length;const list=$('consolidatedExports');list.replaceChildren();
 function exportRow(item,isLatest){
  const row=document.createElement('div');row.className='export-result';const title=document.createElement('h3');title.textContent=isLatest?'Latest corrected recording':'Earlier export';row.append(title);
  const info=document.createElement('p');info.className='muted';info.textContent=`${Object.keys(item.selections||{}).length} replacements · ${new Date(item.created_at).toLocaleString()}${isLatest&&!matches(item)?' · Selections changed since this export':''}`;row.append(info);addAudio(row,item.audio);
  const links=document.createElement('div');links.className='export-links';
  const download=document.createElement('a');download.href=item.audio;download.download=`${recording.name}-corrected.m4a`;download.textContent='Download corrected audio';links.append(download);
  const technical=document.createElement('details');const summary=document.createElement('summary');summary.textContent='Export details';technical.append(summary);const map=document.createElement('a');map.href=item.edit_map;map.download=`${recording.name}-edit-map.json`;map.textContent='Download timing edit map';technical.append(map);links.append(technical);row.append(links);return row;
 }
 if(latest)list.append(exportRow(latest,true));
 if(exports.length>1){const history=document.createElement('details');history.className='export-history';const summary=document.createElement('summary');summary.textContent=`Earlier exports (${exports.length-1})`;history.append(summary);for(const item of exports.slice(1))history.append(exportRow(item,false));list.append(history)}

}
$('buildCorrected').addEventListener('click',async()=>{const target=recording;try{await flush();building=true;$('buildCorrected').disabled=true;$('consolidationStatus').textContent='Building corrected recording…';
 const selections=Object.fromEntries(target.passages.filter(p=>review(p.id).accepted_take_id).map(p=>[p.id,review(p.id).accepted_take_id]));
 const response=await fetch('/api/consolidate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({recording_id:target.id,selections})});const result=await response.json();if(!response.ok)throw new Error(result.error||'Could not combine recordings');consolidations.push(result);building=false;await refreshLifecycle();renderConsolidations();applyLifecycle();$('consolidationStatus').textContent='Corrected M4A and edit map saved. Original fixture unchanged.';
 }catch(error){building=false;$('consolidationStatus').textContent=error.message;renderConsolidations()}});

// Device discovery never opens a microphone; permission is requested only by a gesture.
let preferredMicrophone='';try{preferredMicrophone=localStorage.getItem('review-microphone')||''}catch{}
async function refreshMicrophones(){
 const select=$('microphone'),status=$('microphoneStatus');
 if(!navigator.mediaDevices?.enumerateDevices){status.textContent='Device selection is unavailable in this browser.';return}
 try{
  const devices=(await navigator.mediaDevices.enumerateDevices()).filter(d=>d.kind==='audioinput');
  select.replaceChildren(new Option('System default microphone',''));
  for(const [i,device] of devices.entries()){if(!device.deviceId)continue;select.append(new Option(device.label||`Microphone ${i+1}`,device.deviceId))}
  if(preferredMicrophone&&!devices.some(d=>d.deviceId===preferredMicrophone)){select.append(new Option('Selected microphone unavailable — choose another',preferredMicrophone));status.textContent='Your selected microphone is unavailable. Choose another device before recording.'}
  else status.textContent=devices.some(d=>d.label)?'Choose the microphone to use for replacement recordings.':'Click Enable / refresh microphones to allow access and reveal device names.';
  select.value=preferredMicrophone;
 }catch(error){status.textContent='Could not list microphones: '+error.message}
}
$('microphone').addEventListener('change',()=>{preferredMicrophone=$('microphone').value;try{localStorage.setItem('review-microphone',preferredMicrophone)}catch{}$('microphoneStatus').textContent='Selected device will be used for the next recording.'});
$('refreshMicrophones').addEventListener('click',async()=>{
 $('refreshMicrophones').disabled=true;let stream;
 try{stream=await navigator.mediaDevices.getUserMedia({audio:true,video:false});await refreshMicrophones()}
 catch(error){$('microphoneStatus').textContent=error.name==='OverconstrainedError'||error.name==='NotFoundError'?'The selected microphone is unavailable. Choose another recording device.':error.name==='NotAllowedError'?'Microphone access was denied. Allow access in the browser, then try again.':error.message}
 finally{for(const track of stream?.getTracks()||[])track.stop();$('refreshMicrophones').disabled=audioBusy()}
});
navigator.mediaDevices?.addEventListener?.('devicechange',refreshMicrophones);
refreshMicrophones();

$('openExports').addEventListener('click',()=>navigateTo(selected,true));

$('nextCorrection').addEventListener('click',async()=>{const state=lifecycle[recording.id];if(state?.carried_passages?.includes(selected)){await showOverview();return}if(state?.complete){if(state.followup){try{await flush()}catch{return}const target=state.followup;const passage=target.passages?.[selected]||target.next_passage;location.href=`${target.url}/#recording=${encodeURIComponent(target.recording_id)}&passage=${encodeURIComponent(passage)}`}else await showOverview();return}const p=recording.passages.find(p=>(review(p.id).retakes||[]).length&&!review(p.id).accepted_take_id);if(p)navigateTo(p.id);else if(full)navigateTo(recording.passages[0]?.id);else navigateTo(selected,true)});

async function showOverview(push=true){
 if(audioBusy()){$('captureStatus').textContent='Save or discard this take before leaving the review.';return}
 try{await flush()}catch{return}
 pauseOtherAudio(null);$('workspace').hidden=true;$('overview').hidden=false;
 if(push)history.pushState(null,'','#view=overview');
 const cards=$('reviewCards');cards.replaceChildren();$('overviewStatus').textContent='Loading reviews…';
 try{
  const response=await fetch('/api/reviews',{cache:'no-store'});if(!response.ok)throw new Error('Could not load review overview.');const result=await response.json();
  result.reviews.sort((a,b)=>a.title.localeCompare(b.title));
  for(const item of result.reviews){
   const card=document.createElement('article');card.className='review-card';const title=document.createElement('h2');title.textContent=item.title;card.append(title);
   const progress=document.createElement('p');progress.textContent=item.total===0?'No text differences · audio not verified':item.complete?`Complete · ${item.verified} verified${item.replaced_passages?.length?' · '+item.replaced_passages.length+' replaced':''}${item.carried_passages?.length?' · '+item.carried_passages.length+' carried forward':''}`:`${item.resolved??item.verified} of ${item.total} passages resolved`;progress.className='muted';card.append(progress);
   card.classList.toggle('review-complete',!!item.complete);const actions=document.createElement('div');actions.className='overview-actions';
   for(const [text,passage,primary] of (item.total===0?[['Open recording','full',false]]:item.complete?[['Open review','full',false]]:[[item.verified?'Continue review':'Start review',item.next_passage,true],['Recording & exports','full',false]])){
    const target=item;const targetPassage=passage;const link=document.createElement('a');link.className=primary?'button-link primary':'button-link';link.textContent=text;link.href=`${target.url}/#recording=${encodeURIComponent(target.recording_id)}&passage=${encodeURIComponent(targetPassage)}`;
    if(item.current&&target===item)link.addEventListener('click',async event=>{event.preventDefault();recording=data.recordings.find(r=>r.id===item.recording_id);await navigateTo(passage==='full'?recording.passages[0]?.id:passage,passage==='full')});actions.append(link);
   }card.append(actions);cards.append(card);
  }rememberLocation({view:'overview'});$('overviewStatus').textContent=result.reviews.length?'':'No reviews are available.';
 }catch(error){$('overviewStatus').textContent=error.message}
}
$('overviewButton').addEventListener('click',()=>showOverview());$('backOverview').addEventListener('click',()=>showOverview());
window.addEventListener('popstate',async()=>{if(!data)return;const hash=new URLSearchParams(location.hash.slice(1));if(!hash.get('recording')){await showOverview(false);return}if(audioBusy()){history.forward();return}try{await flush()}catch{return}recording=data.recordings.find(r=>r.id===hash.get('recording'))||recording;selected=recording.passages.some(p=>p.id===hash.get('passage'))?hash.get('passage'):recording.passages[0]?.id;full=hash.get('passage')==='full';if(!queue().some(p=>p.id===selected))selected=queue()[0]?.id;if(!selected)full=true;render()});

$('home').addEventListener('click',()=>showOverview());

async function refreshLifecycle(){try{const response=await fetch('/api/reviews',{cache:'no-store'});if(!response.ok)return;const result=await response.json();lifecycle=Object.fromEntries(result.reviews.filter(x=>x.current).map(x=>[x.recording_id,x]));if(recording){renderRail();applyLifecycle()}}catch{}}
function applyLifecycle(){
 const state=lifecycle[recording?.id];if(!state)return;
 const replaced=!full&&(state.replaced_passages||[]).includes(selected);const carried=!full&&(state.carried_passages||[]).includes(selected);
 if(state.complete)$('progress').textContent=`Review complete · ${state.verified} verified${state.replaced_passages.length?' · '+state.replaced_passages.length+' replaced':''}${state.carried_passages?.length?' · '+state.carried_passages.length+' carried forward':''}`;
 if(replaced){$('reviewForm').hidden=true;$('nextAction').hidden=false;$('nextActionTitle').textContent='Passage resolved with replacement audio';$('nextActionHelp').textContent='This original passage is finished. Its selected take is included in the corrected recording.';$('nextCorrection').textContent=state.followup?'Review corrected passage':'Open corrected recording'}
 else if(carried){$('reviewForm').hidden=true;$('nextAction').hidden=false;$('nextActionTitle').textContent='Already verified in the previous review';$('nextActionHelp').textContent='Your wording correction is applied and this audio passage is unchanged. No repeat check is needed.';$('nextCorrection').textContent='Back to overview'}
 else if(state.complete&&!full){$('nextAction').hidden=false;$('nextActionTitle').textContent='Review complete';$('nextActionHelp').textContent='Every passage has been verified or resolved with exported replacement audio.';$('nextCorrection').textContent=state.followup?'Open follow-up review':'Back to overview'}
 $('saveNext').textContent=!full&&selected===queue().at(-1)?.id?'Save & return to overview':'Save & next passage';
}
