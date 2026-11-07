import test from 'node:test';
import assert from 'node:assert/strict';
import { textStatus, reviewQueue } from '../Sources/EvaluationTools/Resources/EvalReview/review-passages.mjs';
const matching = {id:'D07', short_id:'D07', title:'Hebben / hadden gemeld', reference:'Daarna hebben we de mensen gevraagd.', app_transcript:'Daarna hebben we de mensen gevraagd!'};
const different = {...matching,id:'D04',app_transcript:'Daarna hadden we de mensen gevraagd.'};
test('only passages with actual text differences enter review',()=>{
 assert.equal(textStatus(matching),'matching');
 assert.deepEqual(reviewQueue([matching,different]),[different]);
 assert.deepEqual(reviewQueue([matching]),[]);
});
test('either transcript can introduce a difference; unavailable output is not an error item',()=>{
 assert.equal(textStatus({...matching,second_transcript:'Different words'}),'different');
 assert.equal(textStatus({...matching,app_transcript:null}),'unavailable');
 assert.equal(textStatus({...matching,app_transcript:''}),'different');
 assert.equal(reviewQueue([{...matching,app_transcript:null}]).length,0);
});
test('normalization follows WER policy without hiding names, numbers or missing words',()=>{
 assert.equal(textStatus({reference:'Één z’n Klingon-schip',app_transcript:"één Z'n klingon schip."}),'matching');
 for(const app_transcript of ['Daarna hebben we mensen gevraagd','Daarna hebben we 12 mensen gevraagd','Daarna hebben we Keiko gevraagd'])assert.equal(textStatus({...matching,app_transcript}),'different');
});
test('matching text cannot enter the error queue through repair metadata',()=>{
 for(const state of [{audio_issue:true},{retakes:[{id:'take1'}]},{accepted_take_id:'take1'}])assert.deepEqual(reviewQueue([matching],{D07:state},true),[]);
});
test('filtering never changes passages or owner decisions',()=>{
 const passages=[matching,different],reviews={D07:{status:'matches',words:'owner wording'}};
 const before=JSON.stringify({passages,reviews});
 reviewQueue(passages,reviews,true);
 assert.equal(JSON.stringify({passages,reviews}),before);
});
