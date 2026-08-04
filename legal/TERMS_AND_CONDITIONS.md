# Terms and Conditions

> This is informational, written in plain language because SenseBridge's
> users include people relying on screen readers, and is **not legal advice**.
> It must be reviewed by qualified counsel before public launch.

**Effective date:** 2026-08-01
**Previous version:** 2026-07-09
**Provider:** Kevin K. Le, an individual residing in the State of Oregon,
United States of America ("we", "us", "our", "Provider")
**Project:** SenseBridge (<https://github.com/kevinle3212/sensebridge>)
**Governing law:** State of Oregon, United States of America — see Section 22

## A note on how this document is written

Terms like these are traditionally set in block capitals, because United States
law asks that a disclaimer of warranties be "conspicuous" (Oregon Revised
Statutes 72.3160, adopting Uniform Commercial Code § 2-316). Screen readers
frequently announce block capitals letter by letter, which would make the most
important sections of this document the least usable ones — in an accessibility
product, for the very people it is built for.

So the disclaimers below are made conspicuous by **bold text, their own
headings, and plain sentences** instead of capitalisation. That is a deliberate
choice, and it is the reading we ask a court to give it: these terms are set
apart and emphasised, and no reasonable reader could miss them.

## 1. What SenseBridge is

SenseBridge is a free, open-source accessibility app that describes what a
camera sees, reads text aloud, and provides cautious environmental awareness,
primarily for blind and low-vision users.

## 2. What SenseBridge is not

**SenseBridge is not a safety device, a medical device, a mobility aid, or a
navigation system.** It does not guarantee detection of obstacles, stairs,
curbs, drop-offs, vehicles, people, or any other hazard. It does not replace a
white cane, a guide dog, a sighted guide, or orientation-and-mobility training.
Its output is a cautious, probabilistic estimate, not a guarantee — see
[`docs/SAFETY-FRAMING.md`](../docs/SAFETY-FRAMING.md) for why this framing
exists and why it is non-negotiable.

**Do not rely on SenseBridge as your only means of detecting hazards.**

**SenseBridge is not a way to reach emergency services.** It does not call,
text, or otherwise contact emergency services, and it cannot summon help. If you
are in danger, contact emergency services directly by the means available to
you.

**SenseBridge is not a medical device.** It is not intended to diagnose, treat,
cure, mitigate, or prevent any disease or condition, and it has not been
reviewed, cleared, or approved by the United States Food and Drug
Administration or by any comparable authority in any other country.

## 3. What these Terms cover

These Terms cover the SenseBridge iOS app, the SenseBridge website, and any
related documentation, services, or pre-release builds we make available
(together, "SenseBridge"). The website is a pre-launch information site: it
sells nothing, offers no account, and the presence of information about the app
does not mean the app is available to download.

These Terms govern **your use of SenseBridge as distributed by us**. They are
separate from the open-source licence that governs the source code — see
Section 8.

## 4. Acceptance and eligibility

By using SenseBridge, you agree to these Terms. If you do not agree, do not use
it. If you are using SenseBridge on behalf of an organisation, you confirm you
have authority to bind that organisation, and "you" means that organisation.

You must be at least 13 years old to use SenseBridge. If you are in the European
Economic Area, the United Kingdom, or another jurisdiction with a higher digital
age of consent, you must be at least the age that applies where you live, or
have your parent's or guardian's permission.

## 5. Cost

SenseBridge is free, with no subscription and no in-app purchase. Distributing
it via TestFlight or the App Store requires Apple's Developer Program on the
Provider's side, not yours — see
[`docs/DISTRIBUTION.md`](../docs/DISTRIBUTION.md).

**You pay us nothing, and we earn nothing from your use of SenseBridge.** This
matters legally as well as practically: the allocation of risk set out in
Sections 11 through 16 is what makes it possible to offer a free accessibility
tool at all, and you should read those sections as the price of it being free.

## 6. Accuracy of output

Outputs — descriptions, read text, awareness alerts, haptics, captions — may be
inaccurate, incomplete, delayed, or simply wrong. Software that interprets a
camera image can misread a scene, miss something entirely, or describe something
that is not there. Performance varies with lighting, motion, weather, camera
condition, device model, battery and thermal state, and the scene itself.

Treat every output as a cautious estimate, never a certainty.

## 7. Your data

SenseBridge processes camera, audio, and depth input on your device and
discards it. The single exception is optional crash and error reporting, which
is off until you switch it on and which never carries that content. What is
sent, to whom, and how to withdraw are set out in
[`legal/PRIVACY_POLICY.md`](PRIVACY_POLICY.md), and every third party involved
is listed in [`legal/SUBPROCESSORS.md`](SUBPROCESSORS.md). Those documents are
part of these Terms.

Switching crash reporting on does not create any obligation on our part to
monitor, detect, or respond to a problem you experience. See Section 10.

## 8. Open source, and how it relates to these Terms

The SenseBridge source code is released under the Apache License 2.0 (see
[`LICENSE`](../LICENSE)). You may inspect, modify, and self-host it, subject to
that licence's terms. SenseBridge also distributes third-party components under
their own licences — see
[`legal/THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

Two things follow, and they are easy to conflate:

- **If you use the app or the website we distribute,** these Terms apply to that
  use, alongside the Apache 2.0 licence.
- **If you take the source code and build, modify, or redistribute it
  yourself,** the Apache 2.0 licence governs, including its own warranty
  disclaimer (Section 7) and limitation of liability (Section 8). We are not
  responsible in any way for a build, fork, modification, or distribution that
  is not ours, and you may not represent a modified version as being SenseBridge
  or as coming from us.

## 9. Acceptable use

You agree not to use SenseBridge to:

- break any law, regulation, or third party's rights;
- record, identify, or track a person without a lawful basis and any consent
  the law where you are requires — biometric-privacy laws in several US states
  and elsewhere carry serious penalties, and they apply to you as the person
  operating the camera;
- interfere with, disrupt, overload, or attempt to gain unauthorised access to
  any system, including ours and our providers';
- remove, obscure, or alter any notice, disclaimer, or attribution; or
- present SenseBridge, or any modified version, as a safety device, a medical
  device, a mobility aid, or a navigation system.

We may stop distributing SenseBridge, or stop making any part of it available to
you, at any time and without notice. Given that SenseBridge is free and runs on
your own device, this generally means we stop publishing updates, not that
anything already installed stops working.

## 10. No monitoring, support, availability, or maintenance obligation

SenseBridge is solo-maintained and free. Nothing here commits us to monitoring
the service, responding to you at all or within any particular time, fixing any
defect, maintaining any level of availability, or continuing to develop,
publish, or distribute SenseBridge. A crash report is diagnostic data, not a
support ticket, and sending one does not mean anyone is watching.

We may change, suspend, or discontinue any part of SenseBridge at any time,
without notice and without liability.

## 11. Assumption of risk

**You use SenseBridge at your own risk, and you accept that risk knowingly.**

SenseBridge describes a physical world that can hurt you. You understand that
its output can be wrong, that acting on a wrong output can lead to injury or
worse, and that you remain solely responsible for your own movement, your own
decisions, and your own safety at every moment you use it. You agree to keep
using your primary mobility aids and techniques, and not to substitute
SenseBridge for them.

To the fullest extent permitted by law, you assume all risk arising from your
use of SenseBridge, and you release the Provider from any claim arising out of
that risk.

## 12. Disclaimer of warranties

**SenseBridge is provided "as is" and "as available", with all faults, and
without warranty of any kind.**

To the fullest extent permitted by law, we disclaim all warranties, whether
express, implied, statutory, or arising from a course of dealing or usage of
trade, including in particular:

- **merchantability** and **fitness for a particular purpose**;
- **non-infringement**;
- **accuracy, reliability, completeness, or currency** of any output;
- **quiet enjoyment**, uninterrupted or error-free operation, and freedom from
  defect, harmful code, or interruption; and
- any warranty that SenseBridge will meet your requirements, work with your
  device or assistive technology, or detect any particular thing.

No advice or information, spoken or written, obtained from us or from
SenseBridge creates any warranty not expressly stated here.

Some jurisdictions do not allow the exclusion of certain warranties. Where that
is so, the exclusions above apply to you only to the extent permitted, and
Section 17 sets out the rights you keep.

## 13. Limitation of liability

**To the fullest extent permitted by law, the Provider is not liable to you for
any damages arising out of or relating to SenseBridge.**

This covers, without limitation:

- **indirect, incidental, special, consequential, exemplary, or punitive
  damages**, of any kind;
- **personal injury, bodily harm, emotional distress, or death**, however
  caused, including any harm arising from reliance on SenseBridge's output as a
  safety guarantee — which it explicitly is not, per Section 2;
- **loss of or damage to property**;
- **lost profits, lost revenue, lost data, lost goodwill, or business
  interruption**; and
- **the cost of substitute goods, services, or aids**.

This applies whatever the legal theory — contract, warranty, tort (including
negligence), strict liability, product liability, statute, or anything else —
and it applies even if we have been advised that such damages were possible, and
even if a limited remedy in these Terms is found to have failed of its essential
purpose.

**Aggregate cap.** Where liability cannot lawfully be excluded altogether, our
total aggregate liability to you for all claims arising out of or relating to
SenseBridge is limited to the greater of (a) the total amount you have paid us
for SenseBridge, which is zero, and (b) one hundred United States dollars
(USD 100).

**This is a deliberate allocation of risk.** SenseBridge is free, open source,
and maintained by one person. We would not be able to distribute it at all if we
carried the liability that a commercial safety product carries. You and we agree
that these limits are a fundamental basis of the bargain between us, and that
they survive even where a remedy fails of its essential purpose.

Some jurisdictions do not allow the exclusion or limitation of certain damages —
notably liability for death or personal injury caused by negligence, for fraud
or fraudulent misrepresentation, or for anything else that cannot lawfully be
limited. Where that is so, the exclusions and limits above apply to you only to
the extent permitted, and Section 17 sets out the rights you keep.

## 14. Indemnity

To the fullest extent permitted by law, you agree to defend, indemnify, and hold
harmless the Provider and any contributor to SenseBridge from and against any
claim, demand, proceeding, loss, liability, damage, penalty, cost, or expense
(including reasonable legal fees) arising out of or relating to:

- your use or misuse of SenseBridge;
- your breach of these Terms or of any law;
- your infringement of any third party's rights, including privacy, publicity,
  biometric, and intellectual-property rights; or
- any content you capture, record, process, or share using SenseBridge.

We may take over the defence of any such matter at your expense, and you will
not settle anything that imposes an obligation on us without our written
agreement.

This Section does not apply to a consumer to the extent the law where you live
does not permit it.

## 15. Time limit for claims

To the fullest extent permitted by law, any claim arising out of or relating to
SenseBridge must be brought within **one (1) year** after the claim arose.
Otherwise it is permanently barred. Where the law where you live does not allow
a shortened limitation period, the shortest period that law does allow applies
instead.

## 16. Third-party services and platforms

SenseBridge reaches you through, and depends on, systems we do not control —
Apple's operating systems and App Store, our web host, and the processors listed
in [`legal/SUBPROCESSORS.md`](SUBPROCESSORS.md). Their terms and privacy
practices are theirs, not ours, and we are not responsible or liable for them,
for their availability, or for anything they do or fail to do.

**Apple-specific terms.** If you obtained the SenseBridge app through Apple's
App Store, the following apply and prevail over anything inconsistent in these
Terms:

- These Terms are between you and the Provider only, not with Apple. Apple is
  not responsible for SenseBridge or its content.
- Apple has no obligation to furnish any maintenance or support for
  SenseBridge.
- If SenseBridge fails to conform to any applicable warranty, you may notify
  Apple, and Apple will refund the purchase price to you, which is zero. To the
  maximum extent permitted by law, Apple has no other warranty obligation
  whatsoever with respect to SenseBridge.
- Apple is not responsible for addressing any claim by you or a third party
  relating to SenseBridge, including product-liability claims, any claim that
  SenseBridge fails to conform to a legal or regulatory requirement, and claims
  arising under consumer-protection, privacy, or similar legislation.
- If a third party claims SenseBridge infringes its intellectual property, the
  Provider, not Apple, is solely responsible for the investigation, defence,
  settlement, and discharge of that claim.
- You represent that you are not located in a country subject to a United States
  Government embargo or designated as a "terrorist supporting" country, and that
  you are not on any United States Government list of prohibited or restricted
  parties.
- Apple and its subsidiaries are third-party beneficiaries of these Terms and,
  upon your acceptance, have the right to enforce them against you.

## 17. Rights you keep, wherever you live

Nothing in these Terms takes away a right you have that cannot be taken away by
agreement. In particular:

- **European Economic Area and United Kingdom.** Your mandatory consumer rights,
  including rights under the EU Sale of Goods and Digital Content Directives
  ((EU) 2019/770 and (EU) 2019/771) as implemented where you live, and under the
  UK Consumer Rights Act 2015, are unaffected. So is anything under the GDPR or
  UK GDPR. Because SenseBridge is supplied free of charge, some of these regimes
  apply in a limited form; that is a matter of law, not of these Terms. If you
  are an EU consumer you may also use the European Commission's online dispute
  resolution platform, and you may bring proceedings in the courts of the
  country where you live.
- **Australia.** Our goods and services come with guarantees that cannot be
  excluded under the Australian Consumer Law. Nothing in these Terms excludes,
  restricts, or modifies those guarantees. Because SenseBridge is free, our
  liability for a failure to comply with a consumer guarantee is limited, to the
  extent the Australian Consumer Law permits, to resupplying the software or
  paying the cost of having it resupplied.
- **Canada.** Your rights under applicable provincial consumer-protection
  legislation, including Quebec's Consumer Protection Act, are unaffected, and
  the Quebec provisions on language and jurisdiction apply where they must.
- **New Zealand.** Your rights under the Consumer Guarantees Act 1993 are
  unaffected where you acquire SenseBridge as a consumer.
- **United States.** Your rights under the consumer-protection law of your state
  are unaffected to the extent that law does not permit them to be waived.
  Residents of New Jersey, and of any other state whose law limits these
  exclusions, keep whatever that law preserves.

Where a right you keep conflicts with a term above, the right wins, and only for
that term, and only for you.

## 18. Accessibility

Accessibility is the product, not a feature of it. Our conformance claims, and
just as importantly the limits of those claims, are in
[`legal/ACCESSIBILITY_STATEMENT.md`](ACCESSIBILITY_STATEMENT.md), along with how
to report a barrier.

That statement describes what we are aiming at and what we have actually
verified. It is a good-faith account, not a warranty, and Sections 12 and 13
apply to it. Telling us about a barrier is the fastest way to get it fixed, and
we would rather hear about one than not.

## 19. Artificial intelligence, and what we tell you about it

SenseBridge uses machine-learning models to interpret camera input. We consider
this the kind of system that transparency rules such as the EU Artificial
Intelligence Act (Regulation (EU) 2024/1689) are concerned with, and we would
rather over-disclose than under-disclose:

- **You are interacting with software, not a person.** Every description,
  reading, and alert is machine-generated.
- **It is probabilistic.** It has no understanding of what it is looking at, and
  it can be confidently wrong.
- **It is not used to make any decision about you.** SenseBridge does not
  profile you, score you, or evaluate you, and it makes no automated decision
  producing legal or similarly significant effects.
- **It runs on your device.** Model inference is local; see
  [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md) and
  [`docs/PRIVACY.md`](../docs/PRIVACY.md).

Nothing in this Section is a warranty about the models' accuracy — Section 12
governs that.

## 20. Feedback

If you send us an idea, a bug report, or a suggestion, you grant us a perpetual,
irrevocable, worldwide, royalty-free, non-exclusive licence to use it for any
purpose, without any obligation or payment to you. You are never obliged to send
us anything, and please do not send us anything you consider confidential.

Reporting a security issue is different, and the process for it is in
[`SECURITY.md`](../SECURITY.md).

## 21. Pre-release and experimental builds

TestFlight builds, betas, previews, and anything marked experimental are exactly
that: incomplete, unstable, and more likely than a released build to behave
unexpectedly. They are provided with even less assurance than the rest of
SenseBridge, and Sections 11 through 15 apply to them in full.

## 22. Governing law and venue

These Terms, and any dispute arising out of or relating to them or to
SenseBridge, are governed by the laws of the **State of Oregon, United States of
America**, and by applicable United States federal law, without regard to any
conflict-of-laws rule that would apply the law of another jurisdiction. The
United Nations Convention on Contracts for the International Sale of Goods and
the Uniform Computer Information Transactions Act do not apply.

The exclusive venue for any dispute is the state or federal courts located in
Multnomah County, Oregon, United States of America, and you consent to the
personal jurisdiction of those courts.

**If you are a consumer**, this Section does not deprive you of the protection
of the mandatory law of the country where you live, and it does not prevent you
from bringing proceedings in the courts of that country where the law gives you
that right. See Section 17.

## 23. Resolving a dispute

**Talk to us first.** Before starting any formal proceeding, please email
<kevinle3212@gmail.com> with a description of the problem and what you want.
Most things can be sorted out this way, and we ask for 60 days from that email
to try. This step is a condition of bringing a claim, except where the law says
otherwise or where you need urgent relief from a court.

**Small claims.** Either of us may bring an individual claim in a small-claims
court that has jurisdiction, instead of anything in this Section.

**Injunctive relief.** Either of us may seek an injunction or other equitable
relief from a court to stop the actual or threatened infringement or misuse of
intellectual property or confidential information.

**Individual claims only.** To the fullest extent permitted by law, any dispute
will be brought in your individual capacity, and not as a plaintiff or class
member in any purported class, collective, consolidated, private-attorney-
general, or representative proceeding. **You and we each waive any right to a
jury trial.** If a court finds this paragraph unenforceable as to a particular
claim or remedy, that claim or remedy is severed and proceeds in court, and the
rest of this Section still applies to everything else.

This Section does not apply to you to the extent the law where you live does not
permit it — see Section 17.

## 24. Export control and sanctions

SenseBridge is subject to United States export-control law, including the Export
Administration Regulations, and to economic-sanctions programmes administered by
the Office of Foreign Assets Control. You may not use, export, or re-export
SenseBridge in violation of those rules, and you confirm you are not located in,
under the control of, or a national or resident of any country or region subject
to a comprehensive United States embargo, and that you are not on any
restricted-party or denied-party list.

## 25. United States Government end users

SenseBridge is "commercial computer software" and "commercial computer software
documentation" as those terms are used in 48 C.F.R. § 12.212 and 48 C.F.R.
§§ 227.7202-1 through 227.7202-4. A United States Government end user acquires
only the rights set out in these Terms and in the Apache License 2.0, consistent
with those regulations.

## 26. Intellectual property

The SenseBridge name, logo, and brand are ours, and these Terms grant you no
right to use them, other than the descriptive fair use of naming the project.
The Apache License 2.0 covers the source code and expressly does not grant
trademark rights (see its Section 6). Everything else we have not expressly
granted is reserved.

## 27. Force majeure

We are not liable for any failure or delay caused by something outside our
reasonable control, including a platform or infrastructure outage, a network or
power failure, an act of a government, a change in Apple's or a host's rules,
armed conflict, an epidemic, a natural event, or a supply-chain or upstream
dependency failure.

## 28. Changes to these Terms

We may update these Terms. Changes will be noted in
[`CHANGELOG.md`](../CHANGELOG.md) and reflected here with a new effective date,
and the previous version stays available in this repository's git history.
Continuing to use SenseBridge after a change means you accept the updated
Terms. If you do not accept them, stop using SenseBridge.

## 29. General

- **Severability and savings.** If any provision is held unenforceable, it is
  modified to the minimum extent needed to make it enforceable while preserving
  its intent, or, if that is not possible, severed. Everything else stays in
  force. In particular, if any limit in Sections 12 through 15 is held
  unenforceable, the remaining limits apply to the fullest extent the law
  permits.
- **No waiver.** Not enforcing a provision is not a waiver of it.
- **Assignment.** You may not assign or transfer these Terms. We may assign them
  to a successor or in connection with a transfer of the project.
- **No agency.** These Terms create no partnership, joint venture, employment,
  fiduciary, or agency relationship, and no duty of care beyond what the law
  imposes.
- **Third-party beneficiaries.** There are none, except Apple as set out in
  Section 16 and contributors as set out in Section 14.
- **Notices.** We reach you through the app, the website, or the repository. You
  reach us at <kevinle3212@gmail.com>.
- **Entire agreement.** These Terms, together with
  [`legal/PRIVACY_POLICY.md`](PRIVACY_POLICY.md),
  [`legal/DISCLAIMER.md`](DISCLAIMER.md),
  [`legal/SUBPROCESSORS.md`](SUBPROCESSORS.md),
  [`legal/THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md),
  [`legal/ACCESSIBILITY_STATEMENT.md`](ACCESSIBILITY_STATEMENT.md), and the
  [`LICENSE`](../LICENSE), are the whole agreement between us about SenseBridge
  and replace anything said before.
- **Survival.** Sections 2, 6, 8, and 11 through 29 survive any termination.
- **Language.** These Terms are written in English. Any translation is provided
  for convenience, and the English text governs to the extent the law where you
  live allows.
- **Headings.** Headings are for navigation and do not affect interpretation.

## 30. Contact

Questions: <kevinle3212@gmail.com>
