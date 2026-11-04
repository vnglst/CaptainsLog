import test from 'node:test';
import assert from 'node:assert/strict';
import { textStatus, reviewQueue, passageTitle } from '../Sources/Tools/Resources/EvalReview/review-passages.mjs';
const matching = {id:'D07', short_id:'D07', title:'Hebben / hadden gemeld', reference:'Daarna hebben we de mensen gevraagd.', app_transcript:'Daarna hebben we de mensen gevraagd!'};
const different = {...matching,id:'D04',app_transcript:'Daarna hadden we de mensen gevraagd.'};
test('matching wording does not retain a stale dispute title',()=>{
 assert.equal(textStatus(matching),'matching');
 assert.equal(passageTitle(matching),'D07 · Matching text');
 assert.deepEqual(reviewQueue([matching,different],{},true),[different]);
 assert.deepEqual(reviewQueue([matching,different],{},false),[matching,different]);
});
test('either transcript can introduce a difference; absent output remains reviewable',()=>{
 assert.equal(textStatus({...matching,second_transcript:'Different words'}),'different');
 assert.equal(textStatus({...matching,app_transcript:null}),'unavailable');
 assert.equal(textStatus({...matching,app_transcript:''}),'different');
 assert.equal(reviewQueue([{...matching,app_transcript:null}],{},true).length,1);
});
test('normalization follows WER policy without hiding names, numbers or missing words',()=>{
 assert.equal(textStatus({reference:'Één z’n Klingon-schip',app_transcript:"één Z'n klingon schip."}),'matching');
 for(const app_transcript of ['Daarna hebben we mensen gevraagd','Daarna hebben we 12 mensen gevraagd','Daarna hebben we Keiko gevraagd'])assert.equal(textStatus({...matching,app_transcript}),'different');
});
test('matching passages with reported audio issues or replacement takes remain visible',()=>{
 for(const state of [{audio_issue:true},{retakes:[{id:'take1'}]},{accepted_take_id:'take1'}])assert.deepEqual(reviewQueue([matching],{D07:state},true),[matching]);
});
test('filtering never changes passages or owner decisions',()=>{
 const passages=[matching,different],reviews={D07:{status:'matches',words:'owner wording'}};
 const before=JSON.stringify({passages,reviews});
 reviewQueue(passages,reviews,true);
 assert.equal(JSON.stringify({passages,reviews}),before);
});
