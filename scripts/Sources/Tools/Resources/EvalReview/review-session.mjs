// Explicit links win; a deleted or changed passage returns to the overview.
export function reviewLocation(hash, saved, recordings) {
 const explicit=hash.has('recording')||hash.get('view')==='overview';
 const chosen=explicit?hash:new URLSearchParams(saved||{});
 if(chosen.get('view')==='overview')return new URLSearchParams('view=overview');
 const recording=recordings.find(r=>r.id===chosen.get('recording'));
 const passage=chosen.get('passage');
 if(recording&&(!passage||passage==='full'||recording.passages.some(p=>p.id===passage)))return chosen;
 return new URLSearchParams('view=overview');
}
