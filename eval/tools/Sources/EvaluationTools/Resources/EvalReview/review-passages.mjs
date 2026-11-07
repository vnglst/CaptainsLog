// Word agreement is a navigation aid, never audio verification.
function words(text) {
 return [...text.normalize('NFC').toLowerCase().replaceAll('’',"'").replaceAll('‘',"'").matchAll(/[\p{L}\p{M}\p{N}]+(?:'[\p{L}\p{M}\p{N}]+)*/gu)].map(m=>m[0]);
}
export function textStatus(passage) {
 const outputs=[passage.app_transcript,passage.second_transcript].filter(text=>text!=null);
 if(!outputs.length)return 'unavailable';
 const reference=JSON.stringify(words(passage.reference));
 return outputs.some(text=>JSON.stringify(words(text))!==reference)?'different':'matching';
}
export function reviewQueue(passages) {
 return passages.filter(p=>textStatus(p)==='different');
}
