import test from 'node:test';
import assert from 'node:assert/strict';
import {reviewLocation} from '../Sources/EvaluationTools/Resources/EvalReview/review-session.mjs';
const recordings=[{id:'book',passages:[{id:'E04'}]}];
test('a plain URL resumes the saved recording and passage',()=>assert.equal(reviewLocation(new URLSearchParams(),{recording:'book',passage:'E04'},recordings).toString(),'recording=book&passage=E04'));
test('an explicit overview or passage overrides the last location',()=>{
 assert.equal(reviewLocation(new URLSearchParams('view=overview'),{recording:'book',passage:'E04'},recordings).toString(),'view=overview');
 assert.equal(reviewLocation(new URLSearchParams('recording=book&passage=full'),{view:'overview'},recordings).get('passage'),'full');
});
test('removed recordings and stale passages do not silently select another task',()=>{
 for(const saved of [{recording:'removed',passage:'E04'},{recording:'book',passage:'removed'}])assert.equal(reviewLocation(new URLSearchParams(),saved,recordings).toString(),'view=overview');
});
