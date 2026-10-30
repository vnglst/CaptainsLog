import test from 'node:test';
import assert from 'node:assert/strict';
import {AudioCapture,encodeWav} from '../Sources/Tools/Resources/EvalReview/audio-capture.mjs';
const buffer={length:3200,sampleRate:16000,numberOfChannels:1,getChannelData:()=>new Float32Array(3200).fill(0.25)};
class FakeRecorder {
 static isTypeSupported(){return true}
 constructor(stream){this.stream=stream;this.state='inactive';this.mimeType='audio/webm'}
 start(){this.state='recording'}
 stop(){this.state='inactive';queueMicrotask(()=>{this.ondataavailable({data:new Blob(['synthetic encoded audio'])});this.onstop()})}
}
class Decoder {async decodeAudioData(){return buffer}}
function setup(extra={}){let stopped=0,requested=0,completed=0;const stream={getTracks:()=>[{stop:()=>stopped++}]};const capture=new AudioCapture({mediaDevices:{getUserMedia:async()=>{requested++;return stream}},Recorder:FakeRecorder,Decoder,onComplete:()=>completed++,...extra});return {capture,get stopped(){return stopped},get requested(){return requested},get completed(){return completed}}}
test('WAV uses mono PCM and actual sample duration',async()=>{const bytes=await encodeWav(buffer).arrayBuffer(),view=new DataView(bytes);assert.equal(new TextDecoder().decode(bytes.slice(0,4)),'RIFF');assert.equal(view.getUint16(22,true),1);assert.equal(view.getUint32(24,true),16000);assert.equal(view.getUint16(34,true),16);assert.equal(view.getUint32(40,true),6400);assert.equal(view.getInt16(44,true),8191)});
test('no microphone request until explicit start; stop releases tracks before decoding',async()=>{let job;class CheckDecoder{async decodeAudioData(){assert.ok(job.stopped>0);return buffer}}job=setup({Decoder:CheckDecoder});assert.equal(job.requested,0);await job.capture.start();assert.equal(job.requested,1);const result=await job.capture.stop();assert.equal(result.duration_seconds,0.2);assert.equal(result.blob.type,'audio/wav');assert.equal(job.completed,1);assert.equal(await job.capture.stop(),result);assert.equal(job.completed,1)});
test('permission denial does not start recording',async()=>{const job=setup({mediaDevices:{getUserMedia:async()=>{throw new DOMException('Denied','NotAllowedError')}}});await assert.rejects(job.capture.start(),{name:'NotAllowedError'});assert.equal(job.completed,0);assert.equal(job.capture.state,'failed')});
test('cancel while permission is pending releases a late stream',async()=>{let grant;const promise=new Promise(resolve=>{grant=resolve});let stopped=0;const job=setup({mediaDevices:{getUserMedia:()=>promise}});const start=job.capture.start();job.capture.cancel();grant({getTracks:()=>[{stop:()=>stopped++}]});await assert.rejects(start,{name:'AbortError'});assert.ok(stopped>0);assert.equal(job.completed,0)});
test('decoder failure always releases the microphone',async()=>{class Broken{async decodeAudioData(){throw new Error('Decode failed')}}const job=setup({Decoder:Broken});await job.capture.start();await assert.rejects(job.capture.stop(),/Decode failed/);assert.ok(job.stopped>0);assert.equal(job.completed,0)});
test('recorder setup failure always releases the microphone',async()=>{class Broken extends FakeRecorder{constructor(){throw new Error('Recorder failed')}}const job=setup({Recorder:Broken});await assert.rejects(job.capture.start(),/Recorder failed/);assert.ok(job.stopped>0)});

test('selected device is requested exactly; default keeps browser routing',async()=>{for(const deviceId of ['','usb-mic']){let constraints;const stream={getTracks:()=>[{stop(){}}]};const job=setup({deviceId,mediaDevices:{getUserMedia:async input=>{constraints=input;return stream}}});await job.capture.start();assert.deepEqual(constraints,{audio:{channelCount:1,...(deviceId?{deviceId:{exact:deviceId}}:{})},video:false});await job.capture.stop()}});
test('disconnected selected device fails without silently using another microphone',async()=>{let requests=0;const job=setup({deviceId:'removed',mediaDevices:{getUserMedia:async()=>{requests++;throw new DOMException('Unavailable','OverconstrainedError')}}});await assert.rejects(job.capture.start(),{name:'OverconstrainedError'});assert.equal(requests,1);assert.equal(job.completed,0)});
