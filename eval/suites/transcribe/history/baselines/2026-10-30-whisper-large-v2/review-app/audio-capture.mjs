// Capture starts only from the caller's Record gesture. Decoding and WAV
// normalization happen locally, after the microphone tracks have stopped.
export function encodeWav(buffer) {
 const frames=buffer.length,channels=buffer.numberOfChannels,rate=buffer.sampleRate;
 if(!frames||!channels||!Number.isFinite(rate))throw new Error('The recording is empty.');
 const bytes=new ArrayBuffer(44+frames*2),view=new DataView(bytes);
 const text=(at,s)=>{for(let i=0;i<s.length;i++)view.setUint8(at+i,s.charCodeAt(i))};
 text(0,'RIFF');view.setUint32(4,bytes.byteLength-8,true);text(8,'WAVE');text(12,'fmt ');view.setUint32(16,16,true);view.setUint16(20,1,true);view.setUint16(22,1,true);view.setUint32(24,rate,true);view.setUint32(28,rate*2,true);view.setUint16(32,2,true);view.setUint16(34,16,true);text(36,'data');view.setUint32(40,frames*2,true);
 const data=Array.from({length:channels},(_,c)=>buffer.getChannelData(c));
 for(let i=0;i<frames;i++){let sample=0;for(const channel of data)sample+=channel[i]/channels;sample=Math.max(-1,Math.min(1,sample));view.setInt16(44+i*2,sample<0?sample*32768:sample*32767,true)}
 return new Blob([bytes],{type:'audio/wav'});
}
export class AudioCapture {
 constructor({mediaDevices=globalThis.navigator?.mediaDevices,Recorder=globalThis.MediaRecorder,Decoder=globalThis.OfflineAudioContext,onComplete=()=>{},onProgress=()=>{},onError=()=>{},maxSeconds=600,deviceId=''}={}){Object.assign(this,{mediaDevices,Recorder,Decoder,onComplete,onProgress,onError,maxSeconds,deviceId});this.cancelled=false;this.stream=null;this.state='idle';this.chunks=[]}
 endTracks(){for(const track of this.stream?.getTracks()||[])track.stop();clearInterval(this.timer);clearTimeout(this.limit)}
 async start(){
  if(!this.mediaDevices?.getUserMedia||!this.Recorder||!this.Decoder)throw new Error('Microphone recording is unavailable in this browser.');
  this.state='requesting';
  try{
   this.stream=await this.mediaDevices.getUserMedia({audio:{channelCount:1,...(this.deviceId?{deviceId:{exact:this.deviceId}}:{})},video:false});
   if(this.cancelled)throw new DOMException('Recording cancelled','AbortError');
   const mime=['audio/webm;codecs=opus','audio/mp4','audio/ogg;codecs=opus'].find(x=>this.Recorder.isTypeSupported(x));
   this.recorder=new this.Recorder(this.stream,mime?{mimeType:mime}:{});
   this.recorder.ondataavailable=e=>{if(e.data.size)this.chunks.push(e.data)};
   this.done=new Promise((resolve,reject)=>{this.resolve=resolve;this.reject=reject});this.done.catch(()=>{});
   this.recorder.onerror=e=>{const error=e.error||new Error('The recording device stopped unexpectedly.');this.endTracks();this.state='failed';this.reject(error);this.onError(error)};
   this.recorder.onstop=()=>this.finish();this.recorder.start();this.state='recording';this.started=performance.now();
   this.timer=setInterval(()=>this.onProgress((performance.now()-this.started)/1000),250);
   this.limit=setTimeout(()=>this.stop().catch(()=>{}),this.maxSeconds*1000);
  }catch(error){this.endTracks();this.state='failed';throw error}
 }
 async finish(){
  this.endTracks();
  if(this.cancelled){this.state='cancelled';this.resolve?.(null);return}
  if(this.state==='failed')return;
  this.state='finishing';
  try{
   const raw=new Blob(this.chunks,{type:this.recorder.mimeType||this.chunks[0]?.type});
   if(!raw.size)throw new Error('The recording is empty. Try recording again.');
   const decoder=new this.Decoder(1,1,16000),buffer=await decoder.decodeAudioData(await raw.arrayBuffer());
   if(this.cancelled){this.state='cancelled';this.resolve(null);return}
   const result={blob:encodeWav(buffer),duration_seconds:buffer.length/buffer.sampleRate};
   this.state='stopped';this.resolve(result);this.onComplete(result);
  }catch(error){this.state='failed';this.reject(error);this.onError(error)}
 }
 stop(){if(this.state==='recording'){this.state='stopping';this.recorder.stop();this.endTracks()}return this.done||Promise.reject(new Error('No recording is active.'))}
 cancel(){this.cancelled=true;this.endTracks();if(this.recorder?.state==='recording')this.recorder.stop();this.state='cancelled'}
}
