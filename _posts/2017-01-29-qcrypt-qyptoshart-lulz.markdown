---
layout: post
title:  QyptoShart, qCrypt & post-quantum buzz-word BS
date:   2017-01-29 00:00:00
categories: [cryptography, post-quantum, qcrypt, quorum, triplesec, tripleweave, btyst]
coverimage: /img/posts/thorns.jpg
covertitle: Macro Thorn, by [Petr Kratochvil](http://www.publicdomainpictures.net/view-image.php?image=24320&picture=macro-thorn)
---

In response to an interesting concept brought to my attention, and a recent BT Young Scientist award for Post-Quantum, Geographically Sharded, "Quorum Key Technology" - also known as [qcry.pt](https://qcry.pt) or [getqcrypt.com](https://getqcrypt.com), I decided to delve into the details.

Because there's little to no information about the specifics of this, no scientific paper, no write-up which includes technical details and only sporadic pieces of source code on the young gent's GitHub account, I thought that it would be interesting to explore the idea some more, but from the perspective of a logician, technological deviant and cryptoanarchist.

The main driving forces for this investigation are two-fold, one would be the calls of obvious-bullshit and/or vapourware on [discussion](https://www.reddit.com/r/ireland/comments/5o02u3/discussion_2017_bt_young_scientist_of_the_year/?st=iyiqohp2&sh=d90b7be1) [forums](https://www.reddit.com/r/ireland/comments/5nt1co/young_scientist_terenure_college_student_16_wins/?st=iyiqpr1b&sh=9ca1d567), and secondly because in the world of cryptography we rely on open access to information, source code and research to verify the claims made; it should be fairly obvious to anybody with even a cursory understanding of cryptology that grand claims can be made, but without the ability to verify such claims there is no science, let alone the ability place trust in the conclusions of others.


## What is qCrypt

Well, it's certainly not the [International Conference on Quantum Cryptography](http://2017.qcrypt.net/), although its namesake may have been involved in the inspiration for this project. However, publicly available information I've been able to gather on this crypto is --

High-level:

 * Post-Quantum Cryptography for the Masses
 * Geographically Sharded
 * Quantum Secure
 * Quorum Key Technology 

More insights:

 * it has significant commercial potential if it performs as well as he believes it does.
 * He believes it is so secure it could never be broken into, even with the use of quantum computers.
 * He got the idea after hearing about how Boston College was forced by the courts to release historical political interviews involving former IRA members. If the data had been stored in his system it would have remained secret.
 * The system can break up the original data and store pieces of it in a variety of jurisdictions, which he calls “multi-jurisdictional quorum sharding”, which prevents the data being reassembled even under court duress.
 * He also developed a new encryption key system that is safe from attack by quantum computers, should they ever come into use.
 * He says it is as simple to use as any file transfer product but is 40 per cent faster.

Source code:

 * https://github.com/narruc/TripleWeave.js - A new encryption method known as weaving. Strings are broken up at evenly spaced intervals and encrypted seperately. 
 * https://github.com/narruc/node-gentry - implementation of the Fully Homomorphic Encryption system, as described by Craig Gentry
 * https://github.com/narruc/node-mceliece - Node.js Library for the Post-Quantum McEliece Cryptosystem
 * https://github.com/narruc/tweetnacl-js - Port of TweetNaCl cryptographic library to JavaScript


## Forethought

So, before I start, I should take some wisdom from the Internet Gods and remember that character assassination is never fun for the receiver... to keep things objective and in-context, which in this case seems to be a 16 year old with some very interesting ideas being pushed into the spotlight without necessarily being able to follow through, it may take him another 10 or 20 years to reach the level of intellect and experience associated with ether true-genius or insightful practitioner before he can start really making an impact on the world; but the award is notoriety for what looks like a promising future in the eyes of those who give and seek awards, but recognise that awards aren't necessarily the real world... in fact, some times they are very far from it, and to seek award for the sake of awards will only massage your own ego in a masturbatory fashion; instead, seek truth via science, eschew from seeking notoriety, fame or glory, and let the reward come the satisfaction of recognising how lives are improved after the results of your scientific endeavours have been consumed.

Indeed, I hope that is what is at the core ethos of what the award givers are trying to do, but unfortunately trophies, crowds and confetti sometimes get the better of us mere mortals.


## What is QyptoShart?

It is a method of distributing decryption keys for encrypted data across multiple geographically and geopolitically diverse locations in a way which protects the unencrypted data from the forces of one or even multiple legal jurisdictions.

The threat model that I've constructed and analysed hinges on four things:

 1) A legal jurisdiction may compel you to [divulge your keys](https://en.wikipedia.org/wiki/Key_disclosure_law) or [face imprisonment](https://nakedsecurity.sophos.com/2016/04/28/suspect-who-wont-decrypt-hard-drives-jailed-indefinitely/); alternatively [thermo-rectal](http://i.imgur.com/M8yDmXo.jpg) and [rubber-hose](https://en.wikipedia.org/wiki/Rubber-hose_cryptanalysis) cryptanalysis can be applied.

 2) If any one key-holder can make the other key-holders release their parts of the decryption key via automated technical measures, then there is a single point of failure.

 3) There must be no single points of failure.

 4) No part of the plaintext can be recovered unless all key-holders co-operate.

In some senses QyptoShart allows you to put encrypted data into an escrow, and by securely destroying the original data *and* the final decryption key you are essentially handing over control of the decryption to an algorithm, and putting trust in multiple third parties in different juristictions to release the final decryption key when certain conditions are met. Ultimately, the protection you gain is through trusting that the third parties won't release their part of the key unless legally necessary, and that by creating a system where multiple parties are involved you gain immunity from any single jurisdiction.

There are, of course, many other aspects which have are part of the threat model, but they are all fairly standard considerations when designing the logic of how a cryptosystem must be used and may be detailed below or upon request.


### The QyptoShart System

To perform key escrow it must be possible to know the final key at the time of encryption, to split the key into multiple pieces without allowing any one holder to know the final key it must be possible to combine the keys to arrive at the final key.

To accomplish this each party involved has an asynchronous key pair, the public component is knowable by anybody without compromising the overall integrity. There must also be a way of deriving a shared key between two of the parties which can be determined without any communication. In this case I'm choosing Curve25519; although, as with any other algorithm used in this system, others can be used instead if they have equivalent properties.

Then the originator of data computes individual shared keys between themselves and all other parties, the 'final key' is computed by combining the individual shared keys with XOR operations, producing a composite key. This composite, or final key, is known only to the originator until all of the parties involved collude with each other or release their shared keys.

This means that no parties are ever required to divulge their private keys, only the shared keys between two parties, and that if the private key of any one party does become known to an adversary then as long as other parties are involved it is not possible to determine the final key.

Using fairly standard notation, where:

 * `KEYPAIR-CREATE()` - Create a Curve25519 public/secret key pair.
 * `S(Ap, Bp)` = Curve25519 shared secret computation between two public keys.
 * `XOR(A, B, C...)` = XOR operation combining two or shared secrets represent ed as byte-arrays of the same length.

The algorithm to compute the encryption key between Alice and three Bobs would be:

	Ap, As = KEYPAIR-CREATE()
	H = S(Ap, B1p)
	I = S(Ap, B2p)
	J = S(Ap, B3p)
	KEY = XOR(H, I, J)

However, in this case, if the Secret component of Alice's key is known an adversary can compute the composite key used to encrypt the data, obviously this is bad because of the single point of failure. If the secret component of Alice's key pair is destroyed, along with the original data, then it's only possible to come to the conclusion that Alice did if all three of the Bobs collude with each other.

For this system to work the data originator must destroy both the original data and the secret component of their key pair after encrypting the data, this act puts responsibility of decryption into the hands of the other parties involved, and while it means that the originator cannot possibly decrypt their data even if they wanted to, it does provide them with guarantees that act like a key escrow...

From my perspective, this is the most obvious system which guarantees the logical properties needed as long as the right pieces of information are destroyed securely.


### Problems with QyptoShart

As with RAID-0, if one segment is destroyed the whole becomes corrupt, so if one key-holder becomes unable to recover their keys then all data that they are involved with becomes unrecoverable, given the type of information that one may wish to protect with this type of system it is perfectly reasonable to expect a valid attack to be a denial or omission, to prevent the release of some information only one third-party key-holder would have to be taken out of action.

The problem of data loss isn't anything new, a common solution to this is the Parity Archive system commonly seen on Usenet which allows for a whole set to be recovered from multiple sources as long as N% of pieces from any individual source can be retrieved. A similar scheme could be used to protect against a single party failing to disclose their part of the composite key by deriving an encryption key for every permutation of N-1 key-holders and publishing encrypted segments separately.

Another, more general problem, is that QyptoShart only specifies a way of deriving a composite key and then encrypting data, it doesn't cover distribution, or recovery, or key release mechanisms, generally it's completely agnostic until a protocol or implementation decides on specific ways to alleviate those concerns.


## Post-Quantum, herpen derpen derp

Something which came to light while investigating the various repos on young Mr Curran's GitHub account are that it's possible he's decided to use fairly novel and buzzword compliant cryptographic primitives. The two alternatives which are presumably used instead of or in conjunction with Curve25519 are:

 * Craig Gentry's Fully Homomorphic Encryption system
 * McEliece cryptosystem

The problem is that I can only infer how these two systems could be used based on their properties without the code which combines them or some form of specification that defines how they are used together, but because how things fit together in the context of cryptographic properties, unless there's a wildly novel and innovative method involved then it's usually just a case of connecting the logical dots and jigsaw pieces.

Presumably instead of `curve25519-xsalsa20-poly1305` to encrypt and authenticate the contents of a box, the asymmetric and supposedly quantum resistent McEliece cryptosystem is used to prevent the plaintext from being recovered from the ciphertext. One of the problems here is that I'm comparing a symmetric encryption and verification system with an asymmetric encryption algorithm. Another problem is that the public key sizes are multiple orders of magnitude higher than anything which is realistically usable, for example it's feasible for McEleice public keys to be in the range of half a megabyte to provide just 80 bits of security, where a comparable cryptosystem from DJB can provide ~126 bits of security with a significantly smaller key.

Given that sufficiently capable quantum computers don't really exist yet, should we make a massive trade-off in complexity to protect against the unknown, versus using an alternative that is more widely critiqued, has known limits and provides a comparatively higher level of security in the foreseeable future?

At this point, I'm going to ignore that Mr Curran published the compiled result of [another persons](https://github.com/cyph/mceliece.js) asm.js / Emscriptem wrapper of a [Hybrid Mcliece](https://www.rocq.inria.fr/secret/CBCrypto/index.php?pg=hymes) cryptosystem written in C without properly and fully attributing the original 2 projects... While I routinely espouse deviation from copyright law in the name of a [common albeit slightly retarded good](https://github.com/HarryR/cmd.exe), I rarely, if ever, condone the lack of attribution and credit to original sources, especially so if the original is essentially taken verbatim.


### Fully Homomorphic, derpen herpen merp

Anyway, what can fully homomorphic encryption add to the mix? Well, honestly I'm not sure how it could be used in this situation, especially so within the threat model that I've described above. One interesting thing I did come across is that while Mr Curran's reference implementation of Gent's FHE system does look like it implements the core primitives faithfully, it doesn't follow on to implement any of Gent's work on bootstrapping or auto-refreshing of properties, let alone the higher level benefits you get from that like being able to both multiply and add values together without having to have a third party intervene to re-encrypt the value. I must admit though, my understanding of Gent's FHE system is somewhat limited and, as always, is open to insight.

The gist of it, in this context, as I understand it, could be that instead of distributing block of encrypted data where to decrypt the data you must obtain the whole key, as described by my QyptoShart algorithm above, the original data is divided into N components of random values which sum to M, then they are encrypted using a FHE system so that when added together they can be decrypted by the key holder.

I have two problems with this, and perhaps the most contentious issue I have, is that it relies on a decryption key being known to a single person, so while the parties which store the data can combine it in any way they want it can't be decrypted, but decryption is still a single point of failure, which is the modus operandi necessari to overcome the threats in the model described above.

But that's just one possible options, but given my understanding of the underlying reasons which would necessitate fully homomorphic encryption, versus a partially homomorphic encryption algorithm like the Paillier system, it seems like it's been added in unnecessarily for buzzword compliance.


## On Geographically Distributed Key Escrow

How do you choose the different jurisdictions? If what you're trying to prevent is an external actor coercing the hands of somebody in a specific jurisdiction, then your choice of jurisdictions is much more important than whichever cryptosystem is used.

Which countries police forces collaborate with each other? If you look at the dividing forces that make it harder for one jurisdiction to coerce another into compliance the immediate factors that come to mind are:

 * History of co-operation between different legal forces
 * International jurisdiction of legal agencies
 * Being able to determine which jurisdiction something falls within
 * Ability to find a person to coerce, regardless of jurisdiction

In an ideal world it would be impossible to determine which jurisdiction the key holder is in, and even if that could be determined they would not be liable to coersion of any kind, but if they were it would be incredibly difficult for international cooperation to force all parts of the final key to be divulged because there is no legal justification for one jurisdictions to compel action in anothers due to the keyholders actions not being illegal and there being no basis or legal precident for compliance.

Does anonymity help? Absolutely yes, it frees you from the immediate reach of law enforcement agencies, but even more so does the integrity of the human who runs the service; the shining example of this would be Ladar Levison, the owner and operator of Lavabit, who successfully escaped one gag order which meant he would have to breach the integrity of all users of his service, although he did comply with other less wide-ranging search warrants before then.

Given that QyptoShart allows for one key-holder to be compromised, if implemented with protections from one party denying the release of the final key, the next question becomes which jurisdictions should be chosen?

Honestly, I don't know the best answer, but some words of wisdom which could help solve this problem is whoever isn't an enemy to the enemy of your enemies probably isn't your friend either.

Perhaps:

 * Server in non-russian ex-soviet country, owned by a European, run by latin american national
 * Server in Western European country, obscured via Tor, run by an American national, owned by a south-american
 * Server in United States, run by a Eastern european national via Tor, owned by a Russian national
 * Server in APAC country, run by Russian national, administered by an Attack Helicopter via Tor from Mars...

etc. etc. etc.

A really important thing here is the mix of jurisdictions and the protocols surrounding how supporting services are deployed. If a server is physically located in the United States, but the encryption keys for the HDD are held by an Eastern European national, and the server is only ever accessed via Tor... this creates a nightmarish and multi-layered situation for any authorities trying to investigate.

This isn't something which can be accomplished by a 16 year old, on their own, in their parents bedroom, it requires multiple levels of international trust, anonymity and a sincere distrust of everybody involved. If any one person runs the whole system, it creates yet another single point of failure and coersion, so while commercial aspirations may be had - to be truly secure any notions of money making first have to be thrown away as a gesture to the community at large.


## On TripleWeave.js

Apparently [TripleWeave](https://github.com/narruc/TripleWeave.js/blob/master/src/tripleweave.js) is "A new encryption method known as weaving. Strings are broken up at evenly spaced intervals and encrypted seperately.", it's based on TripleSec - a simple and paranoid symmetric encryption library which encrypts data with multiple algorithms so that a breach of any one cipher will not expose the underlying secret.

Ok, cool, good library from reputable folks, but at this point we're not attacking the encryption algorithms, having a well implemented library like TripleSec only ensures the security of the layers below it, what I'm most interested in are the layers above it and how easily they can be exploited, either by the lack of imagination of an amateur cryptographer, or due the the malevolent insight of a novice professional...

So, what is Triple Weave? The core of the 'weaving mechanism', as I see it, is:

```javascript
	weaveString: function (string, weaves) {
		var results = [];
		for (i = 0; i < weaves; i++) {
			var this_weave = [];
			for (chars = i; chars < string.length; chars = chars + weaves) {
				this_weave.push(string.charAt(chars));
			}
			results.push(this_weave);
		}

		return results;
	},
```

Where `string` is the plaintext, and `weaves` is the number of parts that the plaintext will be split into. So it makes interleaved strips of characters, for example with 3 'weaves' the first 'weave' will be the 1st, 4th, 7th etc. 

One problem is that each 'weave' will be encrypted with the same encryption key as everything else, maybe I'm missing something here, but it's not giving me confidence in the system.
