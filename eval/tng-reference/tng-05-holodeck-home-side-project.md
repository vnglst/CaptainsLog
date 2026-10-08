# TNG-05: Holodeck Home Side Project

**Language:** English
**Recording target:** ~25 min (~3,000 words at comfortable speech pace)
**Categories:** side-project, technical
**Audio filename:** `tng-05-holodeck-home-side-project.m4a`

---

## Raw Script

It's Saturday morning, kids are at a birthday party, Isabel is doing something with her sister, and I have the house to myself for probably about four hours. I've been meaning to do one of these longer rambling-type recordings about the Holodeck Home project for a while because there's a lot in my head and it hasn't had anywhere to go. So here we go.

The Holodeck Home project is a personal side project I've been building for, I want to say, about seven months now. The basic idea is a local AI assistant that's fully integrated with my home setup and runs entirely offline, on hardware I own, without anything going to any external service. And I want to explain why I care about that distinction so much because I think it shapes all the decisions I've made in how this is built.

I've been using cloud-based voice assistants for years. They're convenient. They work well most of the time. And then a while back I was reading something about how these systems train on user interaction data and I just started to feel uncomfortable about that relationship. Not paranoid uncomfortable, just, I own this data, and I haven't consciously agreed to it being part of a training corpus. And the more I sat with that the more I wanted to do something about it. And when you're an engineer that means you build something.

So Guinan actually gave me the name for this project. We were having lunch, I was describing the concept, she said it sounds like you're building your own holodeck for the home. And that clicked immediately. Holodeck Home. I went with it.

The hardware foundation is a Type-1 Isolinear Node. If you're not familiar with those, they're small single-board computers, about the size of a thick paperback book. Mine's mounted behind the TV in the living room. It's not a powerhouse but it has enough headroom to run the Holodeck Management System and the Holographic Intelligence Module simultaneously, mostly. We'll come back to the "mostly" part.

The Holodeck Management System is the home automation layer. It manages the lights, the climate control, the door sensors, the media system. I've had this running for about two years now so it's stable and I know it well. The newer piece is the Holographic Intelligence Module, which is the local AI component. This is a local language model that runs entirely on the Type-1 Isolinear Node without calling out to any cloud endpoint. There are a few different models I've experimented with and the one I'm using now is a reasonably capable seven billion parameter model that fits in the available memory and runs fast enough to feel responsive.

So the integration between the Holographic Intelligence Module and the Holodeck Management System goes through MQTT. MQTT is a lightweight message protocol that the Holodeck Management System uses natively for all its internal communication between components. What I've done is built a small bridge process that listens on an MQTT topic for intent objects and then translates those into Holodeck Management System actions. The Holographic Intelligence Module parses a voice command, produces a structured intent, publishes it to the topic, and the bridge picks it up and calls the relevant Holodeck Management System API to execute it.

That sentence makes it sound cleaner than it was to build.

Let me tell you about the frustrating evening. This was about three weeks ago. I had the MQTT bridge working in local testing. Commands were getting parsed correctly. The intents were being produced in the right format. Everything looked good on paper. And then I deployed it to the actual Type-1 Isolinear Node, and it stopped working. The bridge would start, it would connect to the MQTT broker, and then it would just go silent. No messages were being received. No errors. Nothing.

I spent, and this is not an exaggeration, the better part of a Wednesday evening trying to figure out what was wrong. I checked the MQTT broker logs. I verified the topic subscription string. I restarted things in different orders. At one point I completely wiped the bridge process and rebuilt it from the last known-good version and it still didn't work. I was typing commands into a terminal at eleven o'clock at night with Lucas asleep in the next room trying to be as quiet as a person typing with frustration can be.

The thing that finally cracked it was, I decided to print every single received message to standard out, even if I couldn't process it. Just raw logging. And I saw that messages were being received. They were just being silently dropped somewhere in the processing pipeline. Which meant the subscription was working. The problem was downstream of the subscription. I started adding logging at every step and I found it. There was a type mismatch deep in the JSON parsing. The voice command had come through with a floating-point number for a temperature setpoint and the parser was expecting an integer. Seven point five degrees became seven in the parser, which then failed a bounds check, which raised an exception, which was swallowed by a bare except clause that I had left in from debugging that I forgot to remove. The exception was being eaten. Nothing was shown. Everything looked silent.

I fixed the type handling, removed the bare except, added proper error logging. Deployed. It worked. And then I went to bed.

But here's the thing about moments like that. I genuinely love them. Not while they're happening. While they're happening I'm just a tired person staring at a terminal at eleven at night. But in retrospect, that kind of debugging feels like something is alive. Like the system is real enough to have surprising behavior. And there's a particular satisfaction in tracking a silent failure to its root cause that I don't get anywhere else.

The breakthrough moment was about a week after that. I had the full pipeline working: you say something, the microphone picks it up, the voice recognition layer processes it, the Holographic Intelligence Module parses the intent, the MQTT bridge translates it, the Holodeck Management System executes it. End to end. First real test: I said, turn the living room lights to thirty percent, and they went to thirty percent. And I just stood there for a moment. Completely ridiculous level of satisfaction for something that I could have achieved in two seconds with a phone app. But it's local. It's mine. Nothing left the house.

The Neural Gel Pack Index is the next piece I'm working on. The idea is to give the Holographic Intelligence Module persistent memory across sessions, so it can learn context over time. Right now it treats every conversation as fresh. It has no memory of what I asked yesterday or what preferences I've expressed. The Neural Gel Pack Index would store vector embeddings of past interactions and the module can query them when handling a new request to find relevant context. I have it partially implemented. The embedding side works. The retrieval side works. The part I haven't figured out yet is when to use retrieval and when not to. If you retrieve too aggressively you get context flooding where the module is trying to reconcile too much past context with the current request and the output gets weird. Too conservative and you lose the benefit. This is the unsolved part right now.

The other thing I'm working on is wake word detection. Right now the system is always listening, which means the voice recognition layer is always running. That's fine functionally but it's not ideal for power consumption and it creates an ambient processing load on the Type-1 Isolinear Node that affects responsiveness for other things. What I want is a lightweight always-on wake word detector that listens for a specific phrase, let's say holodeck, and then activates the full pipeline only when it hears that word. This keeps the system responsive without the background load. I've been looking at a couple of open source wake word models and I think I have a path forward, I just haven't had the time to wire it up yet.

There's also a philosophical piece here that I keep coming back to. I've been thinking about what it means to actually own something. I own a lot of technology in my house. I own the router, I own the laptops, I own the smart lights. But most of them phone home to a manufacturer's cloud at some point. The light bulbs check in with the manufacturer to get firmware updates. The router connects to a dashboard service to show me traffic statistics. And I've just accepted this for years because it's convenient and it mostly works and the alternative requires effort. What Holodeck Home is making me realize is that the alternative doesn't actually require that much effort once you commit to it. The effort is front-loaded and then it works. And when it works it's yours in a way that nothing else in the house is.

Guinan asked me once, when I was describing all this, whether I was building it for the thing or for the feeling. And I had to think about that. I think it's both. The thing is useful. The feeling is important. And maybe the feeling is the more important part. There's something about being able to say, that system in my house, I understand how every part of it works, I wrote every part of it, nothing about it is opaque to me — that feels genuinely different from using something I didn't build and couldn't explain.

Anyway. Four hours is up in about fifteen minutes. What I want to do this afternoon when everyone gets back is write up the Neural Gel Pack Index retrieval threshold problem as a proper technical note so I can come back to it with fresh eyes next weekend. That's the goal for today.

Good morning. Happy with where this project is.

---

## Polished Version

A long Saturday-morning update on the Holodeck Home side project, seven months in.

**Why this project.** The motivating insight came from reading about how cloud voice assistants train on user interaction data — an uncomfortable realization that data I hadn't consciously agreed to share was leaving the house. The goal became a fully offline, locally-run AI home assistant. Guinan coined the name "Holodeck Home" over lunch when I described the concept.

**Hardware and software stack.** A Type-1 Isolinear Node (small single-board computer, mounted behind the living room TV) runs the full stack. The Holodeck Management System — handling lights, climate control, door sensors, and media — has been running for two years and is stable. The Holographic Intelligence Module is a local language model (seven billion parameters, runs fully in the node's memory) that processes natural language intent without any cloud calls. The two systems communicate via MQTT: the module produces structured intent objects, a bridge process subscribes on an MQTT topic, and the bridge translates intents into Holodeck Management System API calls.

**The debugging evening.** Three weeks ago, deploying the MQTT bridge to the actual node produced silence — no messages received, no errors. After a long Wednesday evening, raw logging revealed messages were arriving but being silently dropped. The root cause: a type mismatch in JSON parsing where floating-point temperature values were expected as integers. The bounds-check exception was swallowed by a bare `except` clause left in from a debugging session. Fix: proper type handling, explicit error logging, removal of the bare except. The system then worked. The experience was frustrating while happening and satisfying in retrospect — tracking a silent failure to its root cause has a particular quality.

**The breakthrough.** One week later, the full end-to-end pipeline worked: voice → recognition → Holographic Intelligence Module → MQTT bridge → Holodeck Management System execution. First live test: "Turn the living room lights to thirty percent." They went to thirty percent. Nothing left the house.

**Current work.** Two open problems:

1. *Neural Gel Pack Index (persistent memory):* Vector embeddings of past interactions let the module retrieve relevant context across sessions. Embedding and retrieval work; the unsolved piece is the retrieval threshold — too aggressive causes context flooding, too conservative loses the benefit.

2. *Wake word detection:* Always-on voice recognition creates background processing load on the node. A lightweight wake word detector (trigger word: "holodeck") would activate the full pipeline on demand. Open-source models are being evaluated; not yet wired up.

**The philosophical piece.** Most consumer technology phones home — light bulbs, routers, smart devices. Holodeck Home makes the alternative real: front-load the effort, then own the result completely. Guinan asked whether I was building it for the thing or the feeling. The answer is both; the feeling may be the more important part. There's something genuinely different about a system in your house where you understand every component, wrote every part, and nothing is opaque.

**Next step today:** Write up the Neural Gel Pack Index retrieval threshold problem as a technical note for next weekend.

---

## Expected YAML Frontmatter

```yaml
---
date: "2025-04-12"
recording_time: "12:00"
language: English
categories:
  - side-project
  - technical
tags:
  - home-automation
  - local-ai
  - pattern-buffers
  - privacy
  - holodeck-home
  - mqtt
persons:
  - Guinan
  - Isabel
projects:
  - Holodeck Home
companies: []
entities:
  - Type-1 Isolinear Node
  - Holodeck Management System
  - Holographic Intelligence Module
  - Neural Gel Pack Index
  - MQTT
summary: "A detailed update on the Holodeck Home side project: a fully local, offline AI home assistant running on a Type-1 Isolinear Node. Covers the architecture (Holographic Intelligence Module + Holodeck Management System via MQTT), a memorable MQTT debugging session that traced a silent failure to a swallowed exception, the first end-to-end voice command success, and current work on Neural Gel Pack Index persistent memory and wake word detection."
---
```

## Expected Filename

```
2025-04-12-holodeck-home-local-ai-mqtt-breakthrough.md
```
